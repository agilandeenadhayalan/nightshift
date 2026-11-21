-- Existing history is closed without rewriting any posting or classifying a
-- historical test grant as a purchase. A durable seal also survives logical
-- restore; transaction identifiers are deliberately not used as authority.
ALTER TABLE journal_batches ADD COLUMN sealed boolean NOT NULL DEFAULT true;

CREATE FUNCTION open_new_journal_batch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Caller-supplied values cannot bypass the deferred completeness check.
  NEW.sealed := false;
  RETURN NEW;
END $$;
CREATE TRIGGER journal_batch_open BEFORE INSERT ON journal_batches
FOR EACH ROW EXECUTE FUNCTION open_new_journal_batch();

CREATE FUNCTION guard_journal_batch_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Sealing early is safe, but reopening or changing any original field is not.
  -- Compare the complete record so future columns are immutable by default.
  IF TG_OP = 'UPDATE' AND OLD.sealed IS FALSE AND NEW.sealed IS TRUE THEN
    NEW.sealed := OLD.sealed;
    IF NEW IS NOT DISTINCT FROM OLD THEN
      NEW.sealed := true;
      RETURN NEW;
    END IF;
  END IF;
  RAISE EXCEPTION 'Journal records are append-only' USING ERRCODE = '23514';
END $$;
DROP TRIGGER journal_batches_immutable ON journal_batches;
CREATE TRIGGER journal_batches_immutable BEFORE UPDATE OR DELETE ON journal_batches
FOR EACH ROW EXECUTE FUNCTION guard_journal_batch_mutation();

CREATE FUNCTION require_open_journal_batch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Only the creating transaction can see a new uncommitted, unsealed batch.
  -- A missing/invisible batch fails closed, as does every committed batch.
  IF NOT EXISTS (SELECT 1 FROM journal_batches WHERE id = NEW.batch_id AND sealed IS FALSE) THEN
    RAISE EXCEPTION 'Journal batch is closed' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER journal_line_open_batch BEFORE INSERT ON journal_lines
FOR EACH ROW EXECUTE FUNCTION require_open_journal_batch();

CREATE FUNCTION complete_new_journal_batch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Always validate, including a batch sealed explicitly before this check.
  IF NOT EXISTS (SELECT 1 FROM journal_lines WHERE batch_id = NEW.id) THEN
    RAISE EXCEPTION 'Journal batch must contain postings' USING ERRCODE = '23514';
  END IF;
  IF EXISTS (
    SELECT a.unit FROM journal_lines l JOIN wallet_accounts a ON a.id = l.account_id
    WHERE l.batch_id = NEW.id GROUP BY a.unit HAVING sum(l.amount) <> 0
  ) THEN
    RAISE EXCEPTION 'Unbalanced journal' USING ERRCODE = '23514';
  END IF;
  UPDATE journal_batches SET sealed = true WHERE id = NEW.id AND sealed IS FALSE;
  RETURN NULL;
END $$;
-- Explicit SET CONSTRAINTS ... IMMEDIATE closes posting earlier; ordinary
-- multi-statement/savepoint writers remain open until the transaction commits.
CREATE CONSTRAINT TRIGGER journal_batch_complete AFTER INSERT ON journal_batches
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION complete_new_journal_batch();

CREATE FUNCTION guard_wallet_account_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'Wallet account identity is immutable' USING ERRCODE = '23514';
END $$;
CREATE TRIGGER wallet_accounts_immutable BEFORE UPDATE OR DELETE ON wallet_accounts
FOR EACH ROW EXECUTE FUNCTION guard_wallet_account_identity();

CREATE FUNCTION reject_financial_truncation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Financial records cannot be truncated' USING ERRCODE = '23514';
END $$;
CREATE TRIGGER journal_batches_no_truncate BEFORE TRUNCATE ON journal_batches
FOR EACH STATEMENT EXECUTE FUNCTION reject_financial_truncation();
CREATE TRIGGER journal_lines_no_truncate BEFORE TRUNCATE ON journal_lines
FOR EACH STATEMENT EXECUTE FUNCTION reject_financial_truncation();
CREATE TRIGGER wallet_accounts_no_truncate BEFORE TRUNCATE ON wallet_accounts
FOR EACH STATEMENT EXECUTE FUNCTION reject_financial_truncation();
