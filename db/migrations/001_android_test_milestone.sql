CREATE TABLE users (
  id uuid PRIMARY KEY, test_handle text UNIQUE, display_name text NOT NULL,
  languages text[] NOT NULL DEFAULT '{ta,en}' CHECK (languages <@ ARRAY['ta','en']::text[] AND cardinality(languages)>0),
  mode text NOT NULL DEFAULT 'customer' CHECK (mode IN ('customer','listener')),
  listener_approved boolean NOT NULL DEFAULT false, adult_confirmed boolean NOT NULL DEFAULT true,
  suspended boolean NOT NULL DEFAULT false, desired_online boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE auth_sessions (
  token_hash text PRIMARY KEY, user_id uuid NOT NULL REFERENCES users, device_id text NOT NULL,
  expires_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_sessions_user ON auth_sessions(user_id);
CREATE TABLE listener_reviews (
  id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES users, reviewer text NOT NULL,
  approved boolean NOT NULL, reason text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE rate_versions (
  id text PRIMARY KEY, policy jsonb NOT NULL, test_only boolean NOT NULL CHECK(test_only), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE call_sessions (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES users, listener_id uuid NOT NULL REFERENCES users,
  CHECK(customer_id<>listener_id), state text NOT NULL CHECK(state IN ('ringing','connecting','connected','reconnecting','ended')),
  version integer NOT NULL DEFAULT 1, rate_id text NOT NULL REFERENCES rate_versions, rate_snapshot jsonb NOT NULL,
  max_duration_seconds integer NOT NULL CHECK(max_duration_seconds BETWEEN 60 AND 600),
  created_at timestamptz NOT NULL, expires_at timestamptz NOT NULL, accepted_at timestamptz,
  ended_at timestamptz, reason text, connected_ms bigint NOT NULL DEFAULT 0 CHECK(connected_ms>=0),
  connected_since timestamptz, reconnect_since timestamptz,
  charge_microcredits bigint NOT NULL DEFAULT 0 CHECK(charge_microcredits>=0),
  earning_paise bigint NOT NULL DEFAULT 0 CHECK(earning_paise>=0),
  customer_ready boolean NOT NULL DEFAULT false, listener_ready boolean NOT NULL DEFAULT false,
  customer_media_at timestamptz, listener_media_at timestamptz,
  CHECK((state='ended')=(ended_at IS NOT NULL))
);
CREATE INDEX call_history_customer ON call_sessions(customer_id, created_at DESC, id DESC);
CREATE INDEX call_history_listener ON call_sessions(listener_id, created_at DESC, id DESC);
CREATE TABLE active_participant_claims (
  user_id uuid PRIMARY KEY REFERENCES users, call_id uuid NOT NULL REFERENCES call_sessions
);
CREATE TABLE call_participants (
  call_id uuid NOT NULL REFERENCES call_sessions, user_id uuid NOT NULL REFERENCES users,
  rtc_uid integer NOT NULL CHECK(rtc_uid>0), PRIMARY KEY(call_id,user_id), UNIQUE(call_id,rtc_uid)
);
CREATE TABLE call_events (
  id uuid PRIMARY KEY, call_id uuid NOT NULL REFERENCES call_sessions, version integer NOT NULL,
  kind text NOT NULL, payload jsonb NOT NULL, created_at timestamptz NOT NULL, UNIQUE(call_id,version)
);
CREATE TABLE outbox_events (
  id uuid PRIMARY KEY, event_id uuid NOT NULL REFERENCES call_events, recipient_id uuid NOT NULL REFERENCES users,
  delivered_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(event_id,recipient_id)
);
CREATE TABLE idempotency_keys (
  actor_id uuid NOT NULL REFERENCES users, operation text NOT NULL, key text NOT NULL,
  fingerprint text NOT NULL, response jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(actor_id,operation,key)
);
CREATE TABLE wallet_accounts (
  id text PRIMARY KEY, user_id uuid REFERENCES users, unit text NOT NULL CHECK(unit IN ('TEST_MICROCREDIT','TEST_PAISE')),
  kind text NOT NULL CHECK(kind IN ('customer_test','platform_test','listener_test','subsidy_test'))
);
CREATE TABLE journal_batches (
  id text PRIMARY KEY, call_id uuid REFERENCES call_sessions, kind text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE journal_lines (
  id bigserial PRIMARY KEY, batch_id text NOT NULL REFERENCES journal_batches, account_id text NOT NULL REFERENCES wallet_accounts,
  amount bigint NOT NULL CHECK(amount<>0), UNIQUE(batch_id,account_id)
);
CREATE INDEX journal_account ON journal_lines(account_id);
CREATE TABLE spend_holds (
  call_id uuid PRIMARY KEY REFERENCES call_sessions, user_id uuid NOT NULL REFERENCES users,
  amount bigint NOT NULL CHECK(amount>0), released_at timestamptz
);
CREATE FUNCTION reject_journal_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Journal records are append-only'; END $$;
CREATE TRIGGER journal_lines_immutable BEFORE UPDATE OR DELETE ON journal_lines FOR EACH ROW EXECUTE FUNCTION reject_journal_mutation();
CREATE TRIGGER journal_batches_immutable BEFORE UPDATE OR DELETE ON journal_batches FOR EACH ROW EXECUTE FUNCTION reject_journal_mutation();
CREATE FUNCTION require_balanced_journal() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT a.unit FROM journal_lines l JOIN wallet_accounts a ON a.id=l.account_id WHERE l.batch_id=NEW.batch_id GROUP BY a.unit HAVING SUM(l.amount)<>0) THEN
   RAISE EXCEPTION 'Unbalanced journal';
 END IF;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER balanced_journal AFTER INSERT ON journal_lines DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION require_balanced_journal();
CREATE TABLE blocks (
  actor_id uuid NOT NULL REFERENCES users, target_id uuid NOT NULL REFERENCES users,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(actor_id,target_id), CHECK(actor_id<>target_id)
);
CREATE TABLE favorites (
  actor_id uuid NOT NULL REFERENCES users, target_id uuid NOT NULL REFERENCES users,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(actor_id,target_id), CHECK(actor_id<>target_id)
);
CREATE TABLE reports (
  id uuid PRIMARY KEY, actor_id uuid NOT NULL REFERENCES users, call_id uuid NOT NULL REFERENCES call_sessions,
  reason text NOT NULL, status text NOT NULL DEFAULT 'open', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE support_tickets (
  id uuid PRIMARY KEY, actor_id uuid NOT NULL REFERENCES users, call_id uuid REFERENCES call_sessions,
  category text NOT NULL, message text NOT NULL, status text NOT NULL DEFAULT 'open', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE deletion_requests (
  id uuid PRIMARY KEY, user_id uuid NOT NULL UNIQUE REFERENCES users, status text NOT NULL DEFAULT 'requested',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE audit_events (
  id uuid PRIMARY KEY, actor_id uuid REFERENCES users, action text NOT NULL, reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
