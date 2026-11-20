-- Read-only review access. No decisions, entitlements or notifications.
CREATE INDEX listener_submitted_queue ON listener_applications(submitted_at,id) WHERE state='submitted';
CREATE TABLE staff_review_access_events (
  id uuid PRIMARY KEY,
  principal_id uuid NOT NULL REFERENCES staff_principals,
  session_id uuid NOT NULL REFERENCES staff_sessions,
  application_id uuid NOT NULL REFERENCES listener_applications,
  action text NOT NULL CHECK(action IN ('queue.read','detail.read','sample.read')),
  material_version text CHECK(material_version ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL,
  CHECK((action='queue.read')=(material_version IS NULL))
);
CREATE INDEX staff_review_access_application ON staff_review_access_events(application_id,created_at);
CREATE TRIGGER staff_review_access_immutable BEFORE UPDATE OR DELETE ON staff_review_access_events
  FOR EACH ROW EXECUTE FUNCTION reject_foundation_event_mutation();
