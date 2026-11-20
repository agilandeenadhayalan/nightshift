-- Phone sessions carry only token hashes. The provider is checked on every use.
ALTER TABLE users ADD COLUMN identity_revoked_before bigint CHECK (identity_revoked_before >= 0);
ALTER TABLE users ADD COLUMN identity_last_issued_at bigint CHECK (identity_last_issued_at >= 0);
ALTER TABLE users ADD COLUMN identity_last_auth_time bigint CHECK (identity_last_auth_time >= 0);
CREATE TABLE devices (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  device_id text NOT NULL CHECK (length(device_id) BETWEEN 1 AND 128),
  active boolean NOT NULL DEFAULT true,
  last_identity_issued_at bigint NOT NULL CHECK (last_identity_issued_at >= 0),
  last_token_hash text NOT NULL CHECK (last_token_hash ~ '^[0-9a-f]{64}$'),
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, device_id),
  UNIQUE(id, user_id),
  CHECK (NOT active OR revoked_at IS NULL)
);
CREATE UNIQUE INDEX devices_one_active ON devices(user_id) WHERE active;
ALTER TABLE auth_sessions ADD COLUMN auth_kind text NOT NULL DEFAULT 'development'
  CHECK (auth_kind IN ('development','firebase'));
ALTER TABLE auth_sessions ADD COLUMN device_record_id uuid;
ALTER TABLE auth_sessions ADD COLUMN identity_issued_at bigint;
ALTER TABLE auth_sessions ADD CONSTRAINT auth_session_device_owner
  FOREIGN KEY(device_record_id,user_id) REFERENCES devices(id,user_id);
ALTER TABLE auth_sessions ADD CONSTRAINT auth_session_identity_metadata CHECK (
  (auth_kind='development' AND device_record_id IS NULL AND identity_issued_at IS NULL)
  OR (auth_kind='firebase' AND device_record_id IS NOT NULL AND identity_issued_at IS NOT NULL AND identity_issued_at >= 0));

-- Private owner profile: public display names are never populated from this
-- unreviewed submission. Built-in avatars require no uploaded private media.
CREATE TABLE age_declarations (
  user_id uuid PRIMARY KEY REFERENCES users,
  date_of_birth date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,date_of_birth)
);
CREATE TRIGGER age_declarations_immutable BEFORE UPDATE ON age_declarations FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE profiles (
  user_id uuid PRIMARY KEY REFERENCES users,
  date_of_birth date NOT NULL,
  submitted_display_name text NOT NULL CHECK (length(submitted_display_name) BETWEEN 2 AND 40),
  avatar_code text NOT NULL CHECK (avatar_code IN ('moon','star','leaf','wave')),
  interface_language text NOT NULL CHECK (interface_language IN ('ta','en')),
  moderation_state text NOT NULL DEFAULT 'pending' CHECK (moderation_state IN ('pending','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(user_id,date_of_birth) REFERENCES age_declarations(user_id,date_of_birth)
);
CREATE FUNCTION guard_profile_birth_date() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth THEN
    RAISE EXCEPTION 'Date of birth is immutable' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER profiles_birth_date_immutable BEFORE UPDATE ON profiles FOR EACH ROW
  EXECUTE FUNCTION guard_profile_birth_date();

CREATE TABLE consents (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  purpose text NOT NULL CHECK (length(purpose) BETWEEN 1 AND 80),
  notice_version text NOT NULL CHECK (length(notice_version) BETWEEN 1 AND 100),
  granted boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,purpose,notice_version,granted)
);
CREATE TRIGGER consents_immutable BEFORE UPDATE OR DELETE ON consents FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_event_mutation();
