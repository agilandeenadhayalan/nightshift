-- FA-009. Only digests and opaque provider references are durable; never OTPs or phones.
CREATE TABLE otp_identity_namespaces (
  issuer text PRIMARY KEY CHECK (length(issuer) BETWEEN 1 AND 256),
  digest_key_check text NOT NULL CHECK (digest_key_check ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE otp_rate_limits (
  issuer text NOT NULL REFERENCES otp_identity_namespaces,
  scope text NOT NULL CHECK (scope IN ('request_ip','verify_ip','send_phone','send_device','send_ip','send_global')),
  subject_digest text NOT NULL CHECK (subject_digest ~ '^[0-9a-f]{64}$'),
  window_start timestamptz NOT NULL,
  attempts integer NOT NULL CHECK (attempts > 0),
  PRIMARY KEY (issuer, scope, subject_digest, window_start)
);
CREATE INDEX otp_rate_limits_expiry ON otp_rate_limits(window_start);

CREATE TABLE otp_challenges (
  id uuid PRIMARY KEY,
  issuer text NOT NULL REFERENCES otp_identity_namespaces,
  purpose text NOT NULL DEFAULT 'signin' CHECK (purpose = 'signin'),
  consent_version text NOT NULL CHECK (length(consent_version) BETWEEN 1 AND 100),
  phone_digest text NOT NULL CHECK (phone_digest ~ '^[0-9a-f]{64}$'),
  device_digest text NOT NULL CHECK (device_digest ~ '^[0-9a-f]{64}$'),
  ip_digest text NOT NULL CHECK (ip_digest ~ '^[0-9a-f]{64}$'),
  request_key_digest text NOT NULL CHECK (request_key_digest ~ '^[0-9a-f]{64}$'),
  request_fingerprint text NOT NULL CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'sending' CHECK (state IN
    ('sending','sent','verifying','consumed','expired','locked','send_unknown','verify_unknown','superseded')),
  provider_reference text CHECK (length(provider_reference) BETWEEN 1 AND 256 AND provider_reference ~ '^[A-Za-z0-9._:-]+$'),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
  user_id uuid REFERENCES users,
  verified_at timestamptz,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  retry_at timestamptz NOT NULL,
  UNIQUE(issuer, device_digest, request_key_digest),
  CHECK (expires_at > created_at AND expires_at <= created_at + interval '5 minutes'),
  CHECK (retry_at > created_at AND retry_at <= expires_at),
  CHECK (state NOT IN ('sent','verifying','consumed','locked','verify_unknown') OR provider_reference IS NOT NULL),
  CHECK ((state = 'consumed') = (user_id IS NOT NULL AND verified_at IS NOT NULL)),
  CHECK (state = 'consumed' OR (user_id IS NULL AND verified_at IS NULL)),
  CHECK (verified_at IS NULL OR (verified_at >= created_at AND verified_at < expires_at)),
  CHECK (state <> 'locked' OR attempts = 5)
);
CREATE UNIQUE INDEX otp_one_active_phone ON otp_challenges(issuer, phone_digest)
  WHERE state IN ('sending','sent','verifying','send_unknown','verify_unknown');
CREATE INDEX otp_phone_recent ON otp_challenges(issuer, phone_digest, created_at DESC);

CREATE FUNCTION guard_otp_challenge() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE column_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.state <> 'sending' OR NEW.attempts <> 0 OR NEW.provider_reference IS NOT NULL THEN
      RAISE EXCEPTION 'Invalid initial OTP challenge state' USING ERRCODE = '23514';
    END IF;
  ELSE
    FOREACH column_name IN ARRAY ARRAY['id','issuer','purpose','consent_version','phone_digest','device_digest',
      'ip_digest','request_key_digest','request_fingerprint','created_at','expires_at','retry_at'] LOOP
      IF to_jsonb(NEW)->column_name IS DISTINCT FROM to_jsonb(OLD)->column_name THEN
        RAISE EXCEPTION 'Immutable OTP challenge field' USING ERRCODE = '23514';
      END IF;
    END LOOP;
    IF OLD.provider_reference IS NOT NULL AND NEW.provider_reference IS DISTINCT FROM OLD.provider_reference THEN
      RAISE EXCEPTION 'Immutable OTP provider reference' USING ERRCODE = '23514';
    END IF;
    IF NEW.attempts <> OLD.attempts AND NOT (OLD.state = 'sent' AND NEW.state = 'verifying' AND NEW.attempts = OLD.attempts + 1) THEN
      RAISE EXCEPTION 'Invalid OTP attempt transition' USING ERRCODE = '23514';
    END IF;
    IF NEW.state <> OLD.state AND NOT COALESCE((
      '{"sending":["sent","send_unknown","expired"],"sent":["verifying","superseded","expired"],
        "verifying":["sent","consumed","locked","expired","verify_unknown"],
        "send_unknown":["expired"],"verify_unknown":["expired"]}'::jsonb->OLD.state) ? NEW.state, false) THEN
      RAISE EXCEPTION 'Invalid OTP state transition' USING ERRCODE = '23514';
    END IF;
    IF OLD.state = 'consumed' AND (NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.verified_at IS DISTINCT FROM OLD.verified_at) THEN
      RAISE EXCEPTION 'Immutable consumed OTP proof' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER otp_challenge_guard BEFORE INSERT OR UPDATE ON otp_challenges
  FOR EACH ROW EXECUTE FUNCTION guard_otp_challenge();
