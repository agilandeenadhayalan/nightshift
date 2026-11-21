-- Existing test rate rows and call snapshots are preserved, including drift.
-- A version is append-only; a conflicting bundled fixture must be reviewed,
-- never silently repaired by seeding. No production tariff is introduced.
CREATE FUNCTION guard_rate_version_integrity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW IS NOT DISTINCT FROM OLD THEN
      RETURN NEW;
    END IF;
  END IF;
  RAISE EXCEPTION 'Rate versions are immutable' USING ERRCODE = '23514';
END $$;

CREATE TRIGGER rate_versions_immutable BEFORE UPDATE OR DELETE ON rate_versions
  FOR EACH ROW EXECUTE FUNCTION guard_rate_version_integrity();
CREATE TRIGGER rate_versions_no_truncate BEFORE TRUNCATE ON rate_versions
  FOR EACH STATEMENT EXECUTE FUNCTION guard_rate_version_integrity();
