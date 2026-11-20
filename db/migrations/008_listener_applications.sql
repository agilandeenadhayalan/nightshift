ALTER TABLE listener_applications ADD COLUMN bio text NOT NULL DEFAULT '' CHECK (length(bio)<=1000);
ALTER TABLE listener_applications ADD COLUMN topics text[] NOT NULL DEFAULT '{}'
  CHECK (topics <@ ARRAY['everyday','work','study','hobbies','language-practice']::text[] AND cardinality(topics)<=5);
ALTER TABLE listener_applications ADD COLUMN languages text[] NOT NULL DEFAULT '{}'
  CHECK (languages <@ ARRAY['ta','en']::text[] AND cardinality(languages)<=2);
ALTER TABLE listener_applications ADD COLUMN voice_sample_consent boolean NOT NULL DEFAULT false;
ALTER TABLE listener_applications ADD COLUMN consent_version text CHECK (consent_version='listener-review-v1');
ALTER TABLE listener_applications ADD COLUMN voice_sample_upload_id uuid;
ALTER TABLE listener_applications ADD CONSTRAINT listener_review_consent_version
  CHECK (NOT voice_sample_consent OR consent_version IS NOT NULL);

CREATE TABLE listener_review_uploads (
  id uuid PRIMARY KEY,
  application_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES users,
  state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','ready','deleted')),
  token_hash text,
  request_key_digest text,
  request_fingerprint text,
  content_type text,
  byte_length integer,
  sha256 text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL,
  stored_at timestamptz,
  purged_at timestamptz,
  cleanup_attempted_at timestamptz,
  UNIQUE(application_id,request_key_digest),
  UNIQUE(id,application_id,user_id),
  FOREIGN KEY(application_id,user_id) REFERENCES listener_applications(id,user_id),
  CHECK(expires_at>created_at AND expires_at<=created_at+interval '5 minutes'),
  CHECK((state='ready')=(stored_at IS NOT NULL)),
  CHECK(purged_at IS NULL OR state='deleted'),
  CHECK((state IN ('pending','ready') AND token_hash IS NOT NULL AND token_hash ~ '^[0-9a-f]{64}$'
    AND request_key_digest IS NOT NULL AND request_key_digest ~ '^[0-9a-f]{64}$'
    AND request_fingerprint IS NOT NULL AND request_fingerprint ~ '^[0-9a-f]{64}$'
    AND content_type IS NOT NULL AND content_type='audio/wav'
    AND byte_length IS NOT NULL AND byte_length BETWEEN 44 AND 2097152
    AND sha256 IS NOT NULL AND sha256 ~ '^[0-9a-f]{64}$')
    OR (state='deleted' AND token_hash IS NULL AND request_key_digest IS NULL AND request_fingerprint IS NULL
      AND content_type IS NULL AND byte_length IS NULL AND sha256 IS NULL AND stored_at IS NULL))
);
CREATE INDEX listener_review_uploads_owner ON listener_review_uploads(user_id,created_at);
CREATE INDEX listener_review_uploads_cleanup ON listener_review_uploads(cleanup_attempted_at,created_at,id)
  WHERE state='pending' OR (state='deleted' AND purged_at IS NULL);
ALTER TABLE listener_applications ADD CONSTRAINT listener_sample_ownership
  FOREIGN KEY(voice_sample_upload_id,id,user_id) REFERENCES listener_review_uploads(id,application_id,user_id);

CREATE TABLE listener_application_consents (
  id uuid PRIMARY KEY,
  application_id uuid NOT NULL,
  user_id uuid NOT NULL,
  notice_version text NOT NULL CHECK(notice_version='listener-review-v1'),
  granted boolean NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(application_id,user_id) REFERENCES listener_applications(id,user_id)
);
CREATE TRIGGER listener_application_consents_immutable BEFORE UPDATE OR DELETE ON listener_application_consents
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
