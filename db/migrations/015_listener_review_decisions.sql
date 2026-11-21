-- No policy, staff identity, conflict, decision or entitlement is seeded.
CREATE TABLE listener_review_policy_versions (
  version text PRIMARY KEY CHECK(length(version) BETWEEN 1 AND 80),
  digest text NOT NULL UNIQUE CHECK(digest ~ '^[a-f0-9]{64}$'),
  definition jsonb NOT NULL CHECK(jsonb_typeof(definition)='object'),
  approval_reference text NOT NULL CHECK(length(approval_reference) BETWEEN 1 AND 160),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER listener_review_policy_immutable BEFORE UPDATE OR DELETE ON listener_review_policy_versions
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE staff_review_conflicts (
  principal_id uuid NOT NULL REFERENCES staff_principals,
  user_id uuid NOT NULL REFERENCES users,
  reason_code text NOT NULL CHECK(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  source_reference text NOT NULL CHECK(length(source_reference) BETWEEN 1 AND 160),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(principal_id,user_id)
);
CREATE FUNCTION lock_staff_review_conflict() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM id FROM staff_principals WHERE id=NEW.principal_id FOR NO KEY UPDATE;
  RETURN NEW;
END $$;
CREATE TRIGGER staff_review_conflict_lock BEFORE INSERT ON staff_review_conflicts
  FOR EACH ROW EXECUTE FUNCTION lock_staff_review_conflict();
CREATE TRIGGER staff_review_conflict_immutable BEFORE UPDATE OR DELETE ON staff_review_conflicts
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE listener_review_decisions (
  id uuid PRIMARY KEY,
  application_id uuid NOT NULL,
  user_id uuid NOT NULL,
  principal_id uuid NOT NULL REFERENCES staff_principals,
  session_id uuid NOT NULL REFERENCES staff_sessions,
  policy_version text NOT NULL REFERENCES listener_review_policy_versions,
  policy_digest text NOT NULL CHECK(policy_digest ~ '^[a-f0-9]{64}$'),
  material_version text NOT NULL CHECK(material_version ~ '^[a-f0-9]{64}$'),
  outcome text NOT NULL CHECK(outcome IN ('approved','rejected','needs_information')),
  checks jsonb NOT NULL CHECK(jsonb_typeof(checks)='array' AND jsonb_array_length(checks) BETWEEN 1 AND 20),
  reason_code text NOT NULL CHECK(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
  request_fingerprint text NOT NULL CHECK(request_fingerprint ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL,
  FOREIGN KEY(application_id,user_id) REFERENCES listener_applications(id,user_id),
  UNIQUE(principal_id,request_hash),
  UNIQUE(application_id,material_version),
  UNIQUE(id,application_id,user_id)
);
ALTER TABLE listener_applications ADD COLUMN current_review_decision_id uuid;
ALTER TABLE listener_applications ADD CONSTRAINT listener_current_decision_owner
  FOREIGN KEY(current_review_decision_id,id,user_id) REFERENCES listener_review_decisions(id,application_id,user_id);
CREATE FUNCTION guard_current_listener_review() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.state IN ('draft','submitted','withdrawn') THEN NEW.current_review_decision_id:=NULL; END IF;
  IF NEW.current_review_decision_id IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM listener_review_decisions d WHERE d.id=NEW.current_review_decision_id
      AND d.application_id=NEW.id AND d.user_id=NEW.user_id AND d.outcome=NEW.state) THEN
    RAISE EXCEPTION 'Current review must match the application outcome' USING ERRCODE='23514';
  END IF;
  IF TG_OP='UPDATE' AND OLD.state IN ('approved','rejected')
    AND OLD.current_review_decision_id IS NOT NULL
    AND NEW.current_review_decision_id IS DISTINCT FROM OLD.current_review_decision_id THEN
    RAISE EXCEPTION 'Terminal review linkage is immutable' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER listener_current_decision_guard BEFORE INSERT OR UPDATE ON listener_applications
  FOR EACH ROW EXECUTE FUNCTION guard_current_listener_review();
CREATE TRIGGER listener_review_decision_immutable BEFORE UPDATE OR DELETE ON listener_review_decisions
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE INDEX listener_review_decision_owner ON listener_review_decisions(user_id,created_at,id);
CREATE TABLE listener_review_outbox (
  id uuid PRIMARY KEY,
  decision_id uuid NOT NULL UNIQUE REFERENCES listener_review_decisions,
  created_at timestamptz NOT NULL
);
CREATE TRIGGER listener_review_outbox_immutable BEFORE UPDATE OR DELETE ON listener_review_outbox
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE listener_review_effects (
  event_id uuid NOT NULL REFERENCES listener_review_outbox,
  consumer text NOT NULL CHECK(consumer IN ('entitlement','notification')),
  state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','applied','withheld','suppressed')),
  reason_code text CHECK(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  completed_at timestamptz,
  PRIMARY KEY(event_id,consumer),
  CHECK((state='pending')=(completed_at IS NULL))
);
CREATE FUNCTION guard_listener_review_effect() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Review effects are durable' USING ERRCODE='23514'; END IF;
  IF ROW(NEW.event_id,NEW.consumer) IS DISTINCT FROM ROW(OLD.event_id,OLD.consumer)
    OR OLD.state<>'pending' OR NEW.state='pending' THEN
    RAISE EXCEPTION 'Review effects can complete only once' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER listener_review_effect_guard BEFORE UPDATE OR DELETE ON listener_review_effects
  FOR EACH ROW EXECUTE FUNCTION guard_listener_review_effect();
CREATE TABLE listener_review_entitlements (
  decision_id uuid PRIMARY KEY REFERENCES listener_review_decisions,
  event_id uuid NOT NULL UNIQUE REFERENCES listener_review_outbox,
  user_id uuid NOT NULL REFERENCES users,
  created_at timestamptz NOT NULL
);
CREATE TRIGGER listener_review_entitlement_immutable BEFORE UPDATE OR DELETE ON listener_review_entitlements
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE listener_review_notifications (
  id uuid PRIMARY KEY,
  event_id uuid NOT NULL UNIQUE REFERENCES listener_review_outbox,
  decision_id uuid NOT NULL UNIQUE REFERENCES listener_review_decisions,
  user_id uuid NOT NULL REFERENCES users,
  created_at timestamptz NOT NULL
);
CREATE INDEX listener_review_notification_owner ON listener_review_notifications(user_id,created_at,id);
CREATE FUNCTION erase_restricted_review_notifications() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.suspended OR NOT NEW.adult_confirmed THEN
    DELETE FROM listener_review_notifications WHERE user_id=NEW.id;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER erase_restricted_review_notifications AFTER UPDATE OF suspended,adult_confirmed ON users
  FOR EACH ROW EXECUTE FUNCTION erase_restricted_review_notifications();
