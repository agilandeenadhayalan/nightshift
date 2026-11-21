CREATE TABLE matching_requests (
  id uuid PRIMARY KEY,
  sequence bigserial NOT NULL UNIQUE,
  customer_id uuid NOT NULL REFERENCES users,
  state text NOT NULL CHECK(state IN ('searching','ringing','matched','cancelled','exhausted','expired','failed')),
  version integer NOT NULL DEFAULT 1 CHECK(version>=1),
  language text NOT NULL CHECK(language IN ('ta','en')),
  media_type text NOT NULL DEFAULT 'audio' CHECK(media_type='audio'),
  quote_id text NOT NULL REFERENCES rate_versions,
  consent_version text NOT NULL CHECK(consent_version='matching-search-v1'),
  source_kind text NOT NULL CHECK(source_kind IN ('development','firebase')),
  source_session_hash text,
  source_device_id uuid,
  source_identity_id uuid REFERENCES auth_identities,
  source_auth_time bigint,
  request_key_hash text NOT NULL CHECK(request_key_hash ~ '^[a-f0-9]{64}$'),
  request_fingerprint text NOT NULL CHECK(request_fingerprint ~ '^[a-f0-9]{64}$'),
  selection_seed bytea NOT NULL CHECK(octet_length(selection_seed)=32),
  attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 3),
  current_call_id uuid REFERENCES call_sessions,
  scan_after_time timestamptz,
  scan_after_id uuid,
  terminal_reason text CHECK(terminal_reason IN ('no_supply','all_declined','attempts_exhausted','wait_budget_elapsed','customer_cancelled','source_session_ended','account_restricted','safety_blocked','insufficient_balance','quote_unavailable')),
  created_at timestamptz NOT NULL,
  deadline_at timestamptz NOT NULL,
  ended_at timestamptz,
  updated_at timestamptz NOT NULL,
  last_processed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(customer_id,request_key_hash),
  UNIQUE(id,customer_id),
  CHECK(deadline_at=created_at+interval '90 seconds'),
  CHECK((state IN ('searching','ringing'))=(ended_at IS NULL)),
  CHECK(state NOT IN ('ringing','matched') OR current_call_id IS NOT NULL),
  CHECK((scan_after_time IS NULL)=(scan_after_id IS NULL)),
  CHECK((source_kind='development' AND source_session_hash IS NOT NULL AND source_device_id IS NULL AND source_identity_id IS NULL AND source_auth_time IS NULL)
    OR (source_kind='firebase' AND source_session_hash IS NULL AND source_device_id IS NOT NULL AND source_identity_id IS NOT NULL AND source_auth_time IS NOT NULL AND source_auth_time>=0))
);
CREATE UNIQUE INDEX matching_one_active_customer ON matching_requests(customer_id) WHERE state IN ('searching','ringing');
CREATE INDEX matching_pending ON matching_requests(last_processed_at,sequence) WHERE state IN ('searching','ringing');
CREATE INDEX matching_owner_history ON matching_requests(customer_id,sequence DESC);
CREATE TABLE matching_attempts (
  request_id uuid NOT NULL REFERENCES matching_requests,
  ordinal integer NOT NULL CHECK(ordinal BETWEEN 1 AND 3),
  listener_id uuid NOT NULL REFERENCES users,
  call_id uuid NOT NULL UNIQUE REFERENCES call_sessions,
  selection_reasons text[] NOT NULL CHECK(selection_reasons=ARRAY['language_match','currently_available','fair_rotation']::text[]),
  created_at timestamptz NOT NULL,
  PRIMARY KEY(request_id,ordinal),
  UNIQUE(request_id,listener_id)
);
CREATE INDEX matching_listener_offers ON matching_attempts(listener_id,created_at DESC);
CREATE TABLE matching_listener_fairness (
  listener_id uuid PRIMARY KEY REFERENCES users,
  last_offered_at timestamptz NOT NULL
);
CREATE INDEX matching_fairness_order ON matching_listener_fairness(last_offered_at,listener_id);
CREATE TABLE matching_commands (
  request_id uuid NOT NULL REFERENCES matching_requests,
  customer_id uuid NOT NULL REFERENCES users,
  key_hash text NOT NULL CHECK(key_hash ~ '^[a-f0-9]{64}$'),
  fingerprint text NOT NULL CHECK(fingerprint ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL,
  PRIMARY KEY(request_id,key_hash),
  FOREIGN KEY(request_id,customer_id) REFERENCES matching_requests(id,customer_id)
);
CREATE TRIGGER matching_attempts_immutable BEFORE UPDATE OR DELETE ON matching_attempts
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TRIGGER matching_commands_immutable BEFORE UPDATE OR DELETE ON matching_commands
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE FUNCTION guard_matching_transition() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF ROW(NEW.customer_id,NEW.language,NEW.media_type,NEW.quote_id,NEW.consent_version,NEW.source_kind,
      NEW.source_session_hash,NEW.source_device_id,NEW.source_identity_id,NEW.source_auth_time,NEW.request_key_hash,NEW.request_fingerprint,NEW.selection_seed,NEW.created_at,NEW.deadline_at)
    IS DISTINCT FROM ROW(OLD.customer_id,OLD.language,OLD.media_type,OLD.quote_id,OLD.consent_version,OLD.source_kind,
      OLD.source_session_hash,OLD.source_device_id,OLD.source_identity_id,OLD.source_auth_time,OLD.request_key_hash,OLD.request_fingerprint,OLD.selection_seed,OLD.created_at,OLD.deadline_at)
    OR NEW.version<OLD.version OR NEW.attempt_count<OLD.attempt_count
    OR (OLD.state NOT IN ('searching','ringing') AND NEW IS DISTINCT FROM OLD) THEN
    RAISE EXCEPTION 'Matching history cannot regress' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER matching_transition BEFORE UPDATE ON matching_requests
  FOR EACH ROW EXECUTE FUNCTION guard_matching_transition();
