-- Private test video extends the same reservation and settlement lifecycle.
-- Existing audio rows, durable event payloads and journal records are preserved.
ALTER TABLE call_sessions
  ADD COLUMN media_type text NOT NULL DEFAULT 'audio' CHECK (media_type IN ('audio','video')),
  ADD COLUMN customer_video_consent_at timestamptz,
  ADD COLUMN listener_video_consent_at timestamptz;

ALTER TABLE call_sessions ADD CONSTRAINT call_video_consent
  CHECK (
    (media_type = 'audio' AND customer_video_consent_at IS NULL AND listener_video_consent_at IS NULL)
    OR (media_type = 'video' AND customer_video_consent_at IS NOT NULL
      AND customer_video_consent_at >= created_at
      AND (accepted_at IS NULL OR listener_video_consent_at IS NOT NULL)
      AND (listener_video_consent_at IS NULL OR
        (accepted_at IS NOT NULL AND listener_video_consent_at >= created_at)))
  );

CREATE FUNCTION guard_call_media_terms() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.media_type IS DISTINCT FROM OLD.media_type
    OR NEW.rate_id IS DISTINCT FROM OLD.rate_id
    OR NEW.rate_snapshot IS DISTINCT FROM OLD.rate_snapshot
    OR NEW.max_duration_seconds IS DISTINCT FROM OLD.max_duration_seconds
    OR NEW.customer_video_consent_at IS DISTINCT FROM OLD.customer_video_consent_at
    OR (OLD.listener_video_consent_at IS NOT NULL AND
      NEW.listener_video_consent_at IS DISTINCT FROM OLD.listener_video_consent_at) THEN
    RAISE EXCEPTION 'Call media, pricing and recorded consent terms are immutable' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER call_media_terms_immutable BEFORE UPDATE ON call_sessions
  FOR EACH ROW EXECUTE FUNCTION guard_call_media_terms();
