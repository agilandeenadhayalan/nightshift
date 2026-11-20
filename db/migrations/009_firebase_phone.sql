-- Firebase Phone Auth maps provider UIDs to existing opaque app accounts.
-- No phone, Firebase UID, ID token or SMS code is stored in these tables.
CREATE UNIQUE INDEX phone_identity_canonical ON auth_identities(issuer,subject_digest)
  WHERE provider IN ('phone:msg91','phone:firebase');
ALTER TABLE auth_identities ADD CONSTRAINT auth_identity_owner_issuer UNIQUE(id,user_id,issuer);
CREATE TABLE firebase_phone_bindings (
  issuer text NOT NULL,
  uid_digest text NOT NULL CHECK(uid_digest ~ '^[0-9a-f]{64}$'),
  user_id uuid NOT NULL,
  phone_identity_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(issuer,uid_digest),
  FOREIGN KEY(phone_identity_id,user_id,issuer) REFERENCES auth_identities(id,user_id,issuer)
);
CREATE TRIGGER firebase_phone_binding_immutable BEFORE UPDATE OR DELETE ON firebase_phone_bindings
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
CREATE TABLE firebase_phone_admissions (
  id uuid PRIMARY KEY,
  issuer text NOT NULL REFERENCES otp_identity_namespaces,
  phone_digest text NOT NULL CHECK(phone_digest ~ '^[0-9a-f]{64}$'),
  device_digest text NOT NULL CHECK(device_digest ~ '^[0-9a-f]{64}$'),
  request_key_digest text NOT NULL CHECK(request_key_digest ~ '^[0-9a-f]{64}$'),
  request_fingerprint text NOT NULL CHECK(request_fingerprint ~ '^[0-9a-f]{64}$'),
  consent_version text NOT NULL CHECK(length(consent_version) BETWEEN 1 AND 100),
  state text NOT NULL DEFAULT 'issued' CHECK(state IN ('issued','consumed','expired','superseded')),
  token_hash text CHECK(token_hash ~ '^[0-9a-f]{64}$'),
  user_id uuid REFERENCES users,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  retry_at timestamptz NOT NULL,
  UNIQUE(issuer,device_digest,request_key_digest),
  CHECK(expires_at>created_at AND expires_at<=created_at+interval '5 minutes'),
  CHECK(retry_at>created_at AND retry_at<=expires_at),
  CHECK((state='consumed')=(token_hash IS NOT NULL AND user_id IS NOT NULL AND consumed_at IS NOT NULL)),
  CHECK(state='consumed' OR (token_hash IS NULL AND user_id IS NULL AND consumed_at IS NULL))
);
CREATE INDEX firebase_admission_phone ON firebase_phone_admissions(issuer,phone_digest,created_at DESC);
CREATE TRIGGER firebase_admission_guard BEFORE INSERT OR UPDATE ON firebase_phone_admissions
  FOR EACH ROW EXECUTE FUNCTION guard_foundation_record('issued',
    '{"issued":["consumed","expired","superseded"]}',
    'id,issuer,phone_digest,device_digest,request_key_digest,request_fingerprint,consent_version,created_at,expires_at,retry_at',
    'token_hash,user_id,consumed_at');
