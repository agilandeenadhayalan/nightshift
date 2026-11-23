-- Persist channel preferences independently of the master availability intent.
-- Existing clients that only send {online} retain their prior audio/video behavior.
-- These preferences are not camera consent or a production capability flag.
ALTER TABLE users ADD COLUMN audio_enabled boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN video_enabled boolean NOT NULL DEFAULT true;
