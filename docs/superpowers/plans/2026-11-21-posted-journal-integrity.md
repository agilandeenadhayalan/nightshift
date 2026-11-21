# Preserve committed test-journal contents

FA-034 prerequisite, stacked on PR #86 at `a3412e2e910c179eb8e13fd43bca3d6903e22513`. Exactly Customer and Listener app modes remain unchanged; this is database integrity for the current non-monetary test books. Full FA-034 still requires credit lots, allocations, referenced corrections and production finance decisions.

## Observed source gaps and intended behavior

The current journal rejects row updates/deletes and checks per-unit balance after inserts. It does not close a committed batch against later balanced inserts, and changing wallet-account unit/kind/owner can reclassify historical postings without repeating that balance check. Capture meaningful isolated database failures before changing either behavior.

Migration 019 will make wallet-account identity and classification immutable, allowing semantic no-op updates. New journal batches start unsealed, accept lines while visible in their creation transaction, and are sealed by a deferred check requiring nonempty balanced postings. Only the false-to-true sealing transition may change batch metadata; reopening or changing any original field is rejected. Existing batches start sealed without changing their IDs, line contents or financial totals. Later line insertion, history changes, deletion and truncation must fail. No automatic history repair, production unit, tariff, lot policy or payment authority is introduced.

Independent design review rejected a transaction-ID-only marker because a logical restore into a different cluster can reuse the imported transaction number. The persistent sealed state avoids that dependency and survives export/restore. The deferred check must validate even if a caller seals early. Savepoint rollback after a forced deferred check must not permit an empty or unsealed parent commit.

Audit all current seed, identity/onboarding and call-settlement writers for compatibility before choosing the marker implementation. Cover transactions and savepoints, not just an autocommit happy path. A correction must use a separate future batch; a complete reversal service is not claimed in this prerequisite.

## Ownership and verification

- Backend agent owns migration 019, focused real-database tests, schema migration-list adjustment and any necessary narrow posting-helper compatibility change. No live database operations.
- Root registers the test and updates schema, issue and verification documentation.
- Independent reviewer checks account binding, posting closure, trigger ordering, concurrency and forward-migration preservation before full regression.

Focused evidence must cover late balanced appends, account reclassification, valid multi-line/multi-statement transactions, empty/unbalanced commit rejection, semantic no-op account writes, rollback, competing transactions, immutable corrections, actual cascading truncation and an 18→19 history-preserving upgrade. Include legacy schema compatibility where current tests exercise it. Then run the full isolated backend integration suite, typecheck/build/unit checks and repository guard. No mobile input change or new APK is expected.

Keep existing phone runtime/database at their verified baseline. No installation, migration, deployment, real-money operation or staff grant follows from this source change. Parent and final-head CI must pass before handoff. Staff provisioning remains separately dependent on the owner's exact Redmi account and request references.

## Execution

- [x] Reproduce both source gaps and implement persistent seals/account integrity without changing runtime writers.
- [x] Verify 16 focused and 431 full backend cases (zero failures/skips/cancellations), independent source/docs review, typecheck/build/unit, explicit audio and repository checks.
- [ ] Publish a draft stacked PR and verify exact-head CI.
