-- FA-007 foundation only. These tables do not enable provider authentication,
-- listener approval, purchases or payouts. Commerce remains sandbox/test-only.

CREATE FUNCTION guard_foundation_record() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE column_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.state <> TG_ARGV[0] THEN
      RAISE EXCEPTION 'Invalid initial state for %', TG_TABLE_NAME USING ERRCODE = '23514';
    END IF;
  ELSE
    FOREACH column_name IN ARRAY string_to_array(TG_ARGV[2], ',') LOOP
      IF (to_jsonb(NEW)->column_name) IS DISTINCT FROM (to_jsonb(OLD)->column_name) THEN
        RAISE EXCEPTION 'Immutable field %.%', TG_TABLE_NAME, column_name USING ERRCODE = '23514';
      END IF;
    END LOOP;
    IF TG_NARGS > 3 THEN
      FOREACH column_name IN ARRAY string_to_array(TG_ARGV[3], ',') LOOP
        IF (to_jsonb(OLD)->column_name) <> 'null'::jsonb
          AND (to_jsonb(NEW)->column_name) IS DISTINCT FROM (to_jsonb(OLD)->column_name) THEN
          RAISE EXCEPTION 'Recorded timestamp %.% cannot change', TG_TABLE_NAME, column_name USING ERRCODE = '23514';
        END IF;
      END LOOP;
    END IF;
    IF NEW.state <> OLD.state AND NOT COALESCE((TG_ARGV[1]::jsonb->OLD.state) ? NEW.state, false) THEN
      RAISE EXCEPTION 'Invalid state transition for %', TG_TABLE_NAME USING ERRCODE = '23514';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE FUNCTION reject_foundation_event_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = '23514';
END $$;

CREATE FUNCTION reject_foundation_financial_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Financial records in % cannot be deleted', TG_TABLE_NAME USING ERRCODE = '23514';
END $$;

CREATE TABLE auth_identities (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  provider text NOT NULL CHECK (length(provider) BETWEEN 1 AND 80),
  issuer text NOT NULL CHECK (length(issuer) BETWEEN 1 AND 256),
  subject_digest text NOT NULL CHECK (subject_digest ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','verified','revoked')),
  verified_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, issuer, subject_digest),
  CHECK (state <> 'verified' OR verified_at IS NOT NULL),
  CHECK (state <> 'pending' OR verified_at IS NULL),
  CHECK ((state = 'revoked') = (revoked_at IS NOT NULL)),
  CHECK (verified_at IS NULL OR verified_at >= created_at),
  CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);
CREATE INDEX auth_identities_user ON auth_identities(user_id);
CREATE TRIGGER auth_identity_guard BEFORE INSERT OR UPDATE ON auth_identities FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('pending', '{"pending":["verified","revoked"],"verified":["revoked"]}',
    'id,user_id,provider,issuer,subject_digest,created_at', 'verified_at,revoked_at');

CREATE TABLE listener_applications (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  state text NOT NULL DEFAULT 'draft' CHECK (state IN ('draft','submitted','needs_information','approved','rejected','withdrawn')),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(id, user_id),
  CHECK (state NOT IN ('submitted','needs_information','approved','rejected') OR submitted_at IS NOT NULL),
  CHECK (state <> 'draft' OR submitted_at IS NULL),
  CHECK ((state IN ('approved','rejected')) = (decided_at IS NOT NULL)),
  CHECK (submitted_at IS NULL OR submitted_at >= created_at),
  CHECK (decided_at IS NULL OR decided_at >= submitted_at)
);
CREATE UNIQUE INDEX listener_application_one_pending ON listener_applications(user_id)
  WHERE state IN ('draft','submitted','needs_information');
CREATE TRIGGER listener_application_guard BEFORE INSERT OR UPDATE ON listener_applications FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('draft',
    '{"draft":["submitted","withdrawn"],"submitted":["needs_information","approved","rejected","withdrawn"],"needs_information":["submitted","withdrawn"]}',
    'id,user_id,created_at', 'submitted_at,decided_at');

-- Existing local-seed reviews retain a null application reference. A linked
-- review must belong to the applicant; approval still requires a future staff API.
ALTER TABLE listener_reviews ADD COLUMN application_id uuid;
ALTER TABLE listener_reviews ADD CONSTRAINT listener_review_application_owner
  FOREIGN KEY (application_id, user_id) REFERENCES listener_applications(id, user_id);
CREATE INDEX listener_reviews_application ON listener_reviews(application_id) WHERE application_id IS NOT NULL;

CREATE TABLE provider_events (
  id uuid PRIMARY KEY,
  provider text NOT NULL CHECK (length(provider) BETWEEN 1 AND 80),
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  event_digest text NOT NULL CHECK (event_digest ~ '^[0-9a-f]{64}$'),
  payload_digest text NOT NULL CHECK (payload_digest ~ '^[0-9a-f]{64}$'),
  kind text NOT NULL CHECK (kind IN ('purchase','refund','payout','rtc')),
  occurred_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, environment, event_digest),
  UNIQUE(id, provider, environment, kind)
);
CREATE TRIGGER provider_events_immutable BEFORE UPDATE OR DELETE ON provider_events FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_event_mutation();

CREATE TABLE purchases (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  provider text NOT NULL CHECK (length(provider) BETWEEN 1 AND 80),
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  purchase_token_digest text NOT NULL CHECK (purchase_token_digest ~ '^[0-9a-f]{64}$'),
  sku text NOT NULL CHECK (length(sku) BETWEEN 1 AND 160),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  credit_microcredits bigint NOT NULL CHECK (credit_microcredits > 0),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','verified','fulfilled','rejected','cancelled','revoked')),
  test_only boolean NOT NULL DEFAULT true CHECK (test_only),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, environment, purchase_token_digest),
  UNIQUE(id, user_id, provider, environment)
);
CREATE INDEX purchases_user ON purchases(user_id, created_at DESC, id);
CREATE TRIGGER purchase_guard BEFORE INSERT OR UPDATE ON purchases FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('pending',
    '{"pending":["verified","rejected","cancelled"],"verified":["fulfilled","revoked"],"fulfilled":["revoked"]}',
    'id,user_id,provider,environment,purchase_token_digest,sku,amount_paise,credit_microcredits,currency,test_only,created_at');
CREATE TRIGGER purchases_no_delete BEFORE DELETE ON purchases FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_financial_delete();

CREATE TABLE refunds (
  id uuid PRIMARY KEY,
  purchase_id uuid NOT NULL,
  user_id uuid NOT NULL,
  provider text NOT NULL,
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  request_key text NOT NULL CHECK (length(request_key) BETWEEN 1 AND 128),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  state text NOT NULL DEFAULT 'requested' CHECK (state IN ('requested','processing','unknown','succeeded','failed','cancelled')),
  test_only boolean NOT NULL DEFAULT true CHECK (test_only),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (purchase_id, user_id, provider, environment) REFERENCES purchases(id, user_id, provider, environment),
  UNIQUE(purchase_id, request_key)
);
CREATE TRIGGER refund_guard BEFORE INSERT OR UPDATE ON refunds FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('requested',
    '{"requested":["processing","cancelled"],"processing":["unknown","succeeded","failed"],"unknown":["succeeded","failed"]}',
    'id,purchase_id,user_id,provider,environment,request_key,amount_paise,test_only,created_at');
CREATE TRIGGER refunds_no_delete BEFORE DELETE ON refunds FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_financial_delete();

-- Write the parent before aggregating reservations. This serializes competing
-- READ COMMITTED refunds and forces a serialization failure for a stale
-- REPEATABLE READ/SERIALIZABLE snapshot. A SELECT FOR UPDATE alone is insufficient.
-- Unknown outcomes continue to reserve amount until reconciled.
CREATE FUNCTION guard_refund_total() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE purchase_amount bigint; purchase_state text; reserved numeric;
BEGIN
  UPDATE purchases SET updated_at = now() WHERE id = NEW.purchase_id
    RETURNING amount_paise, state INTO purchase_amount, purchase_state;
  IF purchase_state IS NULL THEN RETURN NEW; END IF; -- The foreign key rejects an absent parent.
  IF NEW.state NOT IN ('failed','cancelled') THEN
    IF purchase_state NOT IN ('verified','fulfilled','revoked') THEN
      RAISE EXCEPTION 'Cannot refund an unverified purchase' USING ERRCODE = '23514';
    END IF;
    SELECT COALESCE(SUM(amount_paise),0) INTO reserved FROM refunds
      WHERE purchase_id = NEW.purchase_id AND id <> NEW.id AND state NOT IN ('failed','cancelled');
    IF reserved + NEW.amount_paise > purchase_amount THEN
      RAISE EXCEPTION 'Refund reservations exceed purchase amount' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER refund_total_guard BEFORE INSERT OR UPDATE ON refunds FOR EACH ROW EXECUTE FUNCTION guard_refund_total();

CREATE TABLE payout_accounts (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users,
  provider text NOT NULL CHECK (length(provider) BETWEEN 1 AND 80),
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  account_digest text NOT NULL CHECK (account_digest ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','verified','rejected','disabled')),
  verified_at timestamptz,
  test_only boolean NOT NULL DEFAULT true CHECK (test_only),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(provider, environment, account_digest),
  UNIQUE(id, user_id, provider, environment),
  CHECK (state <> 'verified' OR verified_at IS NOT NULL),
  CHECK (state NOT IN ('pending','rejected') OR verified_at IS NULL),
  CHECK (verified_at IS NULL OR verified_at >= created_at)
);
CREATE INDEX payout_accounts_user ON payout_accounts(user_id);
CREATE TRIGGER payout_account_guard BEFORE INSERT OR UPDATE ON payout_accounts FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('pending', '{"pending":["verified","rejected","disabled"],"verified":["disabled"]}',
    'id,user_id,provider,environment,account_digest,test_only,created_at', 'verified_at');

CREATE TABLE payout_requests (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL,
  payout_account_id uuid NOT NULL,
  provider text NOT NULL,
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  request_key text NOT NULL CHECK (length(request_key) BETWEEN 1 AND 128),
  request_fingerprint text NOT NULL CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  fee_paise bigint NOT NULL DEFAULT 0 CHECK (fee_paise >= 0),
  net_paise bigint GENERATED ALWAYS AS (amount_paise - fee_paise) STORED CHECK (net_paise > 0),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  state text NOT NULL DEFAULT 'requested' CHECK (state IN ('requested','approved','processing','unknown','paid','failed','cancelled','reversed')),
  test_only boolean NOT NULL DEFAULT true CHECK (test_only),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (payout_account_id, user_id, provider, environment) REFERENCES payout_accounts(id, user_id, provider, environment),
  UNIQUE(user_id, request_key),
  UNIQUE(id, provider, environment)
);
CREATE INDEX payout_requests_account ON payout_requests(payout_account_id);
CREATE TRIGGER payout_request_guard BEFORE INSERT OR UPDATE ON payout_requests FOR EACH ROW
  EXECUTE FUNCTION guard_foundation_record('requested',
    '{"requested":["approved","cancelled"],"approved":["processing","cancelled"],"processing":["unknown","paid","failed"],"unknown":["paid","failed"],"paid":["reversed"]}',
    'id,user_id,payout_account_id,provider,environment,request_key,request_fingerprint,amount_paise,fee_paise,currency,test_only,created_at');
CREATE TRIGGER payouts_no_delete BEFORE DELETE ON payout_requests FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_financial_delete();

CREATE FUNCTION require_verified_payout_account() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE account_state text;
BEGIN
  -- A disabled account prevents new authorization, but must not prevent recording
  -- an already-sent transfer's late outcome or reversal.
  IF TG_OP = 'INSERT' OR (NEW.state IS DISTINCT FROM OLD.state AND NEW.state IN ('approved','processing')) THEN
    SELECT state INTO account_state FROM payout_accounts WHERE id = NEW.payout_account_id FOR UPDATE;
    IF account_state IS DISTINCT FROM 'verified' THEN
      RAISE EXCEPTION 'Payout account is not verified' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER payout_verified_account_guard BEFORE INSERT OR UPDATE ON payout_requests FOR EACH ROW
  EXECUTE FUNCTION require_verified_payout_account();

CREATE TABLE payout_events (
  id uuid PRIMARY KEY,
  payout_request_id uuid NOT NULL,
  provider_event_id uuid NOT NULL UNIQUE,
  provider text NOT NULL,
  environment text NOT NULL DEFAULT 'sandbox' CHECK (environment = 'sandbox'),
  kind text NOT NULL DEFAULT 'payout' CHECK (kind = 'payout'),
  outcome text NOT NULL CHECK (outcome IN ('processing','unknown','paid','failed','reversed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (payout_request_id, provider, environment) REFERENCES payout_requests(id, provider, environment),
  FOREIGN KEY (provider_event_id, provider, environment, kind) REFERENCES provider_events(id, provider, environment, kind)
);
CREATE INDEX payout_events_request ON payout_events(payout_request_id);
CREATE TRIGGER payout_events_immutable BEFORE UPDATE OR DELETE ON payout_events FOR EACH ROW
  EXECUTE FUNCTION reject_foundation_event_mutation();
