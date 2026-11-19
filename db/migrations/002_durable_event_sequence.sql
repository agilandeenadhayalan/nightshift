-- UUIDs identify events, but must never order a reconnect cursor. Millisecond
-- timestamps can tie. Writers serialize allocation through commit in service.event.
ALTER TABLE call_events ADD COLUMN sequence bigint GENERATED ALWAYS AS IDENTITY;
CREATE UNIQUE INDEX call_events_sequence ON call_events(sequence);
