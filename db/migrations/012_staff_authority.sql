-- Separate operator authority. No live identities or grants are seeded.
CREATE TABLE staff_principals (
  id uuid PRIMARY KEY,
  issuer text NOT NULL CHECK(length(issuer) BETWEEN 1 AND 300),
  audience text NOT NULL CHECK(length(audience) BETWEEN 1 AND 200),
  tenant text NOT NULL DEFAULT '' CHECK(length(tenant)<=128),
  provider_subject text NOT NULL CHECK(length(provider_subject) BETWEEN 1 AND 128),
  subject_digest text NOT NULL UNIQUE CHECK(subject_digest ~ '^[a-f0-9]{64}$'),
  linked_user_id uuid REFERENCES users,
  disabled boolean NOT NULL DEFAULT false,
  authority_version bigint NOT NULL DEFAULT 1 CHECK(authority_version>0),
  revoked_before bigint NOT NULL DEFAULT 0 CHECK(revoked_before>=0),
  last_auth_time bigint CHECK(last_auth_time>=0),
  last_issued_at bigint CHECK(last_issued_at>=0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE staff_permission_grants (
  id uuid PRIMARY KEY,
  principal_id uuid NOT NULL REFERENCES staff_principals,
  permission text NOT NULL CHECK(permission IN ('listener.review.read','listener.review.evidence.read','listener.review.decide')),
  reason_code text NOT NULL CHECK(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  CHECK(revoked_at IS NULL OR revoked_at>=granted_at)
);
CREATE UNIQUE INDEX staff_permission_active ON staff_permission_grants(principal_id,permission) WHERE revoked_at IS NULL;
CREATE TABLE staff_sessions (
  id uuid PRIMARY KEY,
  principal_id uuid NOT NULL REFERENCES staff_principals,
  token_hash text NOT NULL UNIQUE CHECK(token_hash ~ '^[a-f0-9]{64}$'),
  proof_hash text NOT NULL UNIQUE CHECK(proof_hash ~ '^[a-f0-9]{64}$'),
  authority_version bigint NOT NULL CHECK(authority_version>0),
  authentication_methods text[] NOT NULL CHECK(cardinality(authentication_methods)>0 AND cardinality(authentication_methods)<=8),
  auth_time bigint NOT NULL CHECK(auth_time>=0),
  policy_version text NOT NULL CHECK(length(policy_version) BETWEEN 1 AND 80),
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  CHECK(expires_at>created_at),
  CHECK(revoked_at IS NULL OR revoked_at>=created_at)
);
CREATE INDEX staff_sessions_owner ON staff_sessions(principal_id);
CREATE TABLE staff_auth_challenges (
  cookie_hash text PRIMARY KEY CHECK(cookie_hash ~ '^[a-f0-9]{64}$'),
  csrf_hash text NOT NULL CHECK(csrf_hash ~ '^[a-f0-9]{64}$'),
  client_digest text NOT NULL CHECK(client_digest ~ '^[a-f0-9]{64}$'),
  origin text NOT NULL,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  CHECK(expires_at>created_at),
  CHECK(consumed_at IS NULL OR consumed_at>=created_at)
);
CREATE INDEX staff_challenges_created ON staff_auth_challenges(created_at);
CREATE TABLE staff_audit_events (
  id uuid PRIMARY KEY,
  principal_id uuid REFERENCES staff_principals,
  session_id uuid REFERENCES staff_sessions,
  action text NOT NULL CHECK(action IN ('authority.changed','session.created','session.revoked','permission.used')),
  permission text CHECK(permission IN ('listener.review.read','listener.review.evidence.read','listener.review.decide')),
  reason_code text NOT NULL CHECK(reason_code ~ '^[a-z][a-z0-9_]{0,63}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER staff_audit_immutable BEFORE UPDATE OR DELETE ON staff_audit_events
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();

CREATE FUNCTION guard_staff_principal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF ROW(NEW.id,NEW.issuer,NEW.audience,NEW.tenant,NEW.provider_subject,NEW.subject_digest,NEW.linked_user_id,NEW.created_at)
    IS DISTINCT FROM ROW(OLD.id,OLD.issuer,OLD.audience,OLD.tenant,OLD.provider_subject,OLD.subject_digest,OLD.linked_user_id,OLD.created_at)
    OR NEW.authority_version<OLD.authority_version OR NEW.revoked_before<OLD.revoked_before
    OR COALESCE(NEW.last_auth_time,-1)<COALESCE(OLD.last_auth_time,-1)
    OR COALESCE(NEW.last_issued_at,-1)<COALESCE(OLD.last_issued_at,-1) THEN
    RAISE EXCEPTION 'Staff authority cannot regress or change identity' USING ERRCODE='23514';
  END IF;
  IF NEW.disabled IS DISTINCT FROM OLD.disabled THEN
    NEW.authority_version:=GREATEST(NEW.authority_version,OLD.authority_version+1);
    NEW.revoked_before:=GREATEST(NEW.revoked_before,COALESCE(OLD.last_auth_time,0));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER staff_principal_guard BEFORE UPDATE ON staff_principals FOR EACH ROW EXECUTE FUNCTION guard_staff_principal();
CREATE FUNCTION staff_authority_changed() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.authority_version<>OLD.authority_version OR NEW.revoked_before<>OLD.revoked_before THEN
    UPDATE staff_sessions SET revoked_at=GREATEST(created_at,clock_timestamp()) WHERE principal_id=NEW.id AND revoked_at IS NULL;
    INSERT INTO staff_audit_events(id,principal_id,action,reason_code) VALUES(gen_random_uuid(),NEW.id,'authority.changed','authority_changed');
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER staff_authority_changed AFTER UPDATE ON staff_principals FOR EACH ROW EXECUTE FUNCTION staff_authority_changed();
CREATE FUNCTION guard_staff_grant() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Staff grants retain revocation history' USING ERRCODE='23514'; END IF;
  IF TG_OP='UPDATE' THEN
    IF ROW(NEW.id,NEW.principal_id,NEW.permission,NEW.reason_code,NEW.granted_at)
      IS DISTINCT FROM ROW(OLD.id,OLD.principal_id,OLD.permission,OLD.reason_code,OLD.granted_at)
      OR OLD.revoked_at IS NOT NULL OR NEW.revoked_at IS NULL THEN
      RAISE EXCEPTION 'Staff grants may only be revoked once' USING ERRCODE='23514';
    END IF;
  END IF;
  PERFORM id FROM staff_principals WHERE id=NEW.principal_id FOR NO KEY UPDATE;
  UPDATE staff_principals SET authority_version=authority_version+1,
    revoked_before=GREATEST(revoked_before,COALESCE(last_auth_time,0)) WHERE id=NEW.principal_id;
  RETURN NEW;
END $$;
CREATE TRIGGER staff_grant_guard BEFORE INSERT OR UPDATE OR DELETE ON staff_permission_grants FOR EACH ROW EXECUTE FUNCTION guard_staff_grant();
