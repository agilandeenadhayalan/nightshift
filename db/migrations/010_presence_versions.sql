-- Redis is only a liveness cache. Durable account/session/intent transitions
-- fence delayed writes with this version; losing Redis never loses authority.
ALTER TABLE users ADD COLUMN presence_version bigint NOT NULL DEFAULT 0
  CHECK (presence_version >= 0);

CREATE FUNCTION guard_presence_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.presence_version < OLD.presence_version THEN
    RAISE EXCEPTION 'presence version cannot decrease' USING ERRCODE='23514';
  END IF;
  -- Future review/suspension code must not revive a lease issued under older
  -- eligibility, even if it does not explicitly change the cache version.
  IF ROW(NEW.desired_online,NEW.mode,NEW.listener_approved,NEW.adult_confirmed,NEW.suspended,NEW.identity_revoked_before)
      IS DISTINCT FROM ROW(OLD.desired_online,OLD.mode,OLD.listener_approved,OLD.adult_confirmed,OLD.suspended,OLD.identity_revoked_before)
      AND NEW.presence_version = OLD.presence_version THEN
    NEW.presence_version := OLD.presence_version + 1;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER users_presence_version BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION guard_presence_version();
