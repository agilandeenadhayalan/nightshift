-- Native staff authority is tied to an explicitly verified app identity.
-- No enrollment, grants, or provider changes occur during migration.
ALTER TABLE staff_permission_grants DROP CONSTRAINT staff_permission_grants_permission_check;
ALTER TABLE staff_permission_grants ADD CHECK(permission IN ('listener.review.read','listener.review.evidence.read','listener.review.decide','staff.access.manage'));
ALTER TABLE staff_audit_events DROP CONSTRAINT staff_audit_events_permission_check;
ALTER TABLE staff_audit_events ADD CHECK(permission IN ('listener.review.read','listener.review.evidence.read','listener.review.decide','staff.access.manage'));
ALTER TABLE staff_audit_events DROP CONSTRAINT staff_audit_events_action_check;
ALTER TABLE staff_audit_events ADD CHECK(action IN ('authority.changed','session.created','session.revoked','permission.used','access.provisioned'));
ALTER TABLE staff_auth_challenges ADD COLUMN app_binding jsonb;
ALTER TABLE staff_sessions ADD COLUMN app_binding jsonb;
-- Old fixture-only sessions remain nullable. The real factory requires a
-- binding on both exchange and every authorization; upgrading grants no access.
CREATE TABLE staff_access_requests (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  issuer text NOT NULL,
  audience text NOT NULL,
  tenant text NOT NULL,
  provider_subject text NOT NULL,
  subject_digest text NOT NULL CHECK(subject_digest ~ '^[a-f0-9]{64}$'),
  app_binding jsonb NOT NULL,
  created_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL CHECK(expires_at>created_at),
  provisioned_at timestamptz,
  principal_id uuid REFERENCES staff_principals,
  CHECK((provisioned_at IS NULL)=(principal_id IS NULL))
);
CREATE INDEX staff_access_owner ON staff_access_requests(user_id,created_at DESC);
CREATE INDEX staff_access_expiry ON staff_access_requests(expires_at);
CREATE INDEX staff_challenge_binding_owner ON staff_auth_challenges((app_binding->>'userId')) WHERE app_binding IS NOT NULL;
CREATE INDEX staff_challenge_binding_expiry ON staff_auth_challenges(expires_at) WHERE app_binding IS NOT NULL;
CREATE FUNCTION erase_staff_access_request() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.suspended OR NOT NEW.adult_confirmed THEN
    -- Request references are not financial/audit retention. Keep the separate
    -- staff authority/audit history; erase enrollment's duplicated private data.
    DELETE FROM staff_access_requests WHERE user_id=NEW.id;
    -- Preserve hashed client rate-window accounting, not the native identity.
    UPDATE staff_auth_challenges SET app_binding=NULL WHERE app_binding->>'userId'=NEW.id::text;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER staff_access_private_cleanup AFTER UPDATE OF suspended,adult_confirmed ON users
  FOR EACH ROW EXECUTE FUNCTION erase_staff_access_request();
