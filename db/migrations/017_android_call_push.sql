-- Private invitation delivery. This schema does not enable a provider or media.
CREATE TABLE push_target_claims (
  target_digest text PRIMARY KEY CHECK(target_digest ~ '^[0-9a-f]{64}$'),
  user_id uuid NOT NULL REFERENCES users,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE push_registrations (
  id uuid PRIMARY KEY,user_id uuid NOT NULL UNIQUE REFERENCES users,
  device_record_id uuid NOT NULL,identity_id uuid NOT NULL REFERENCES auth_identities,auth_time bigint NOT NULL CHECK(auth_time>=0),
  project_id text NOT NULL,target_kind text NOT NULL DEFAULT 'fcm_token' CHECK(target_kind='fcm_token'),
  version integer NOT NULL CHECK(version>=1),binding_id uuid NOT NULL UNIQUE,
  state text NOT NULL CHECK(state IN ('prepared','active','revoked','expired')),
  target_digest text NOT NULL REFERENCES push_target_claims,ciphertext bytea,
  expires_at timestamptz,created_at timestamptz NOT NULL,updated_at timestamptz NOT NULL,
  CHECK((state IN ('prepared','active'))=(ciphertext IS NOT NULL)),
  CHECK(state NOT IN ('prepared','active') OR expires_at IS NOT NULL)
);
CREATE INDEX push_registration_expiry ON push_registrations(expires_at) WHERE state IN ('prepared','active');
CREATE TABLE push_commands (
  user_id uuid NOT NULL REFERENCES users,operation text NOT NULL CHECK(operation IN ('prepare','activate','revoke')),
  key_hash text NOT NULL CHECK(key_hash ~ '^[0-9a-f]{64}$'),fingerprint text NOT NULL CHECK(fingerprint ~ '^[0-9a-f]{64}$'),
  registration_version integer NOT NULL CHECK(registration_version>=1),created_at timestamptz NOT NULL,
  PRIMARY KEY(user_id,operation,key_hash)
);
CREATE TABLE push_delivery_jobs (
  id uuid PRIMARY KEY,event_id uuid NOT NULL REFERENCES call_events,call_id uuid NOT NULL REFERENCES call_sessions,
  recipient_id uuid NOT NULL REFERENCES users,registration_id uuid NOT NULL,registration_version integer NOT NULL CHECK(registration_version>=1),
  binding_id uuid NOT NULL,kind text NOT NULL CHECK(kind IN ('call.invitation','call.terminal')),event_version integer NOT NULL CHECK(event_version>=1),
  expires_at timestamptz NOT NULL,state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','leased','retry','accepted','suppressed','failed','unknown')),
  attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 2),next_attempt_at timestamptz NOT NULL,
  lease_owner uuid,lease_until timestamptz,result_code text,provider_message_id text,
  created_at timestamptz NOT NULL,last_attempt_at timestamptz,
  UNIQUE(event_id,registration_id,registration_version),
  CHECK((state='leased')=(lease_owner IS NOT NULL AND lease_until IS NOT NULL))
);
CREATE INDEX push_delivery_pending ON push_delivery_jobs(next_attempt_at,created_at) WHERE state IN ('pending','retry','unknown','leased');
CREATE INDEX push_delivery_owner ON push_delivery_jobs(recipient_id);
CREATE TABLE push_send_budgets (
  call_id uuid NOT NULL REFERENCES call_sessions,kind text NOT NULL CHECK(kind IN ('call.invitation','call.terminal')),
  admitted integer NOT NULL DEFAULT 0 CHECK(admitted BETWEEN 0 AND 2),not_before timestamptz,PRIMARY KEY(call_id,kind)
);
CREATE TABLE push_delivery_attempts (
  id uuid PRIMARY KEY,job_id uuid NOT NULL REFERENCES push_delivery_jobs,call_id uuid NOT NULL REFERENCES call_sessions,
  kind text NOT NULL CHECK(kind IN ('call.invitation','call.terminal')),ordinal integer NOT NULL CHECK(ordinal BETWEEN 1 AND 2),
  registration_version integer NOT NULL,started_at timestamptz NOT NULL,finished_at timestamptz,outcome text,
  UNIQUE(call_id,kind,ordinal)
);
-- Owner mutations already hold the same user lock as registration. Device rows
-- are intentionally not referenced: account deletion can remove private devices.
CREATE FUNCTION invalidate_push_authority() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE push_registrations p SET state='revoked',ciphertext=NULL,expires_at=NULL,updated_at=clock_timestamp()
    WHERE p.user_id=NEW.id AND p.state IN ('prepared','active') AND (
      NEW.suspended OR NOT NEW.adult_confirmed OR NEW.identity_last_auth_time IS DISTINCT FROM p.auth_time
      OR (NEW.identity_revoked_before IS NOT NULL AND NEW.identity_revoked_before>=p.auth_time)
      OR NOT EXISTS(SELECT 1 FROM devices d WHERE d.id=p.device_record_id AND d.user_id=NEW.id AND d.active AND d.revoked_at IS NULL)
      OR (p.state='active' AND (NOT NEW.listener_approved OR NEW.mode<>'listener' OR NOT NEW.desired_online)));
  RETURN NEW;
END;
$$;
CREATE TRIGGER push_owner_authority AFTER UPDATE ON users FOR EACH ROW EXECUTE FUNCTION invalidate_push_authority();
CREATE FUNCTION erase_deleted_device_push() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE push_registrations SET state='revoked',ciphertext=NULL,expires_at=NULL,updated_at=clock_timestamp()
    WHERE device_record_id=OLD.id AND state IN ('prepared','active');
  RETURN OLD;
END;
$$;
CREATE TRIGGER push_device_delete BEFORE DELETE ON devices FOR EACH ROW EXECUTE FUNCTION erase_deleted_device_push();
