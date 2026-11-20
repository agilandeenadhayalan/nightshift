-- Short-lived owner/filter-bound directory views contain IDs and frozen ranks,
-- never copied names, phone identities, private profiles or financial data.
CREATE TABLE directory_views (
  id uuid PRIMARY KEY,
  sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  owner_id uuid NOT NULL REFERENCES users,
  language text NOT NULL CHECK (language IN ('ta','en')),
  available_only boolean NOT NULL,
  favorites_only boolean NOT NULL,
  truncated boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL CHECK (expires_at > created_at)
);
CREATE INDEX directory_views_owner ON directory_views(owner_id,created_at DESC);
CREATE INDEX directory_views_expiry ON directory_views(expires_at);
CREATE TABLE directory_members (
  view_id uuid NOT NULL REFERENCES directory_views ON DELETE CASCADE,
  listener_id uuid NOT NULL REFERENCES users,
  rank integer NOT NULL CHECK (rank BETWEEN 1 AND 2000),
  served boolean NOT NULL DEFAULT false,
  PRIMARY KEY(view_id,listener_id), UNIQUE(view_id,rank)
);
CREATE TABLE directory_cursors (
  id uuid PRIMARY KEY,
  view_id uuid NOT NULL REFERENCES directory_views ON DELETE CASCADE,
  after_rank integer NOT NULL CHECK (after_rank BETWEEN 1 AND 2000),
  UNIQUE(view_id,after_rank)
);
CREATE INDEX directory_members_listener ON directory_members(listener_id);

-- Account deletion must erase transient social graph data in the same commit.
CREATE FUNCTION purge_restricted_directory_views() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.suspended AND NOT OLD.suspended THEN
    DELETE FROM directory_views WHERE owner_id=NEW.id;
    DELETE FROM directory_members WHERE listener_id=NEW.id;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER users_directory_restriction AFTER UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION purge_restricted_directory_views();
