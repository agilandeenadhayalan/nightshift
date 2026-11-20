-- FA-016 foundation. No retention duration or legal approval is implied.
-- Existing requested rows have no capability and require manual policy review.
-- One-off onboarding/deletion submissions stay idempotent; reversible purposes
-- must allow true -> false -> true events under their command's owner lock.
ALTER TABLE consents DROP CONSTRAINT consents_user_id_purpose_notice_version_granted_key;
CREATE UNIQUE INDEX consents_one_off_notice ON consents(user_id,purpose,notice_version,granted)
  WHERE purpose IN ('adult-service-onboarding','account_deletion');
ALTER TABLE deletion_requests ADD COLUMN notice_version text;
ALTER TABLE deletion_requests ADD COLUMN receipt_token_hash text UNIQUE;
ALTER TABLE deletion_requests ADD COLUMN request_fingerprint text;
ALTER TABLE deletion_requests ADD COLUMN personal_data_deleted_at timestamptz;
ALTER TABLE deletion_requests ADD COLUMN restriction_review_required boolean NOT NULL DEFAULT false;
ALTER TABLE deletion_requests ADD COLUMN private_material_cleanup_pending boolean NOT NULL DEFAULT false;
ALTER TABLE deletion_requests ADD COLUMN retention_holds text[] NOT NULL DEFAULT '{}';
ALTER TABLE deletion_requests ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE deletion_requests ADD CONSTRAINT deletion_request_status CHECK (status IN ('requested','pending_hold','review_required'));
ALTER TABLE deletion_requests ADD CONSTRAINT deletion_request_capability CHECK (
  (notice_version IS NULL AND receipt_token_hash IS NULL AND request_fingerprint IS NULL)
  OR (notice_version IS NOT NULL AND length(notice_version) BETWEEN 1 AND 100
    AND receipt_token_hash IS NOT NULL AND receipt_token_hash ~ '^[0-9a-f]{64}$'
    AND request_fingerprint IS NOT NULL AND request_fingerprint ~ '^[0-9a-f]{64}$'));

-- A future authorized casework workflow may create/release these holds. There
-- is deliberately no customer or staff HTTP mutation endpoint in this slice.
-- Only the named field may be copied: no DOB, contact data or entire profile.
CREATE TABLE account_profile_evidence_holds (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  report_id uuid REFERENCES reports,
  support_ticket_id uuid REFERENCES support_tickets,
  scope text NOT NULL DEFAULT 'submitted_display_name' CHECK (scope = 'submitted_display_name'),
  retained_display_name text CHECK (length(retained_display_name) BETWEEN 2 AND 40),
  created_at timestamptz NOT NULL DEFAULT now(),
  released_at timestamptz,
  CHECK (num_nonnulls(report_id,support_ticket_id) = 1),
  CHECK (released_at IS NULL OR released_at >= created_at)
);
CREATE INDEX account_profile_evidence_owner ON account_profile_evidence_holds(user_id);
CREATE FUNCTION guard_account_profile_evidence() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM id FROM users WHERE id=NEW.user_id FOR NO KEY UPDATE;
    IF NEW.retained_display_name IS NOT NULL OR NEW.released_at IS NOT NULL THEN
      RAISE EXCEPTION 'Evidence hold must start empty and active' USING ERRCODE='23514';
    END IF;
    IF EXISTS (SELECT 1 FROM deletion_requests WHERE user_id=NEW.user_id) THEN
      RAISE EXCEPTION 'Cannot add profile evidence after deletion starts' USING ERRCODE='23514';
    END IF;
    IF NOT (
      EXISTS (SELECT 1 FROM reports r JOIN call_sessions c ON c.id=r.call_id
        WHERE r.id=NEW.report_id AND NEW.user_id IN (r.actor_id,c.customer_id,c.listener_id))
      OR EXISTS (SELECT 1 FROM support_tickets s LEFT JOIN call_sessions c ON c.id=s.call_id
        WHERE s.id=NEW.support_ticket_id AND NEW.user_id IN (s.actor_id,c.customer_id,c.listener_id))
    ) THEN
      RAISE EXCEPTION 'Evidence case does not concern account' USING ERRCODE='23514';
    END IF;
  ELSE
    IF (NEW.id,NEW.user_id,NEW.report_id,NEW.support_ticket_id,NEW.scope,NEW.created_at)
      IS DISTINCT FROM (OLD.id,OLD.user_id,OLD.report_id,OLD.support_ticket_id,OLD.scope,OLD.created_at) THEN
      RAISE EXCEPTION 'Evidence hold ownership and scope are immutable' USING ERRCODE='23514';
    END IF;
    IF OLD.released_at IS NOT NULL AND NEW.released_at IS DISTINCT FROM OLD.released_at THEN
      RAISE EXCEPTION 'Evidence release is immutable' USING ERRCODE='23514';
    END IF;
    IF NEW.retained_display_name IS NOT NULL AND
      (NEW.released_at IS NOT NULL OR (OLD.retained_display_name IS NOT NULL
       AND NEW.retained_display_name IS DISTINCT FROM OLD.retained_display_name)) THEN
      RAISE EXCEPTION 'Cannot replace or restore released evidence' USING ERRCODE='23514';
    END IF;
    IF OLD.retained_display_name IS NOT NULL AND NEW.retained_display_name IS NULL
      AND NEW.released_at IS NULL AND NOT EXISTS (
        SELECT 1 FROM deletion_requests WHERE user_id=NEW.user_id AND restriction_review_required) THEN
      RAISE EXCEPTION 'Release the scoped evidence hold before erasure' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER account_profile_evidence_guard BEFORE INSERT OR UPDATE ON account_profile_evidence_holds
  FOR EACH ROW EXECUTE FUNCTION guard_account_profile_evidence();
CREATE TRIGGER account_profile_evidence_no_delete BEFORE DELETE ON account_profile_evidence_holds
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();

CREATE TABLE account_deletion_events (
  id uuid PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES deletion_requests,
  kind text NOT NULL CHECK (kind IN ('requested','personal_data_deleted','holds_changed')),
  holds text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER account_deletion_events_immutable BEFORE UPDATE OR DELETE ON account_deletion_events
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();

CREATE FUNCTION guard_account_deletion_request() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.id,NEW.user_id,NEW.created_at,NEW.notice_version,NEW.receipt_token_hash,NEW.request_fingerprint,NEW.restriction_review_required)
    IS DISTINCT FROM (OLD.id,OLD.user_id,OLD.created_at,OLD.notice_version,OLD.receipt_token_hash,OLD.request_fingerprint,OLD.restriction_review_required) THEN
    RAISE EXCEPTION 'Deletion request identity and notice are immutable' USING ERRCODE='23514';
  END IF;
  IF OLD.personal_data_deleted_at IS NOT NULL AND NEW.personal_data_deleted_at IS DISTINCT FROM OLD.personal_data_deleted_at THEN
    RAISE EXCEPTION 'Recorded erasure timestamp is immutable' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER account_deletion_request_guard BEFORE UPDATE ON deletion_requests
  FOR EACH ROW EXECUTE FUNCTION guard_account_deletion_request();
CREATE TRIGGER account_deletion_request_no_delete BEFORE DELETE ON deletion_requests
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
