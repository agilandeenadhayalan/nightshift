# Committed test-journal integrity

This is a bounded prerequisite for [FA-034 / #34](https://github.com/agilandeenadhayalan/nightshift/issues/34), stacked on the rate-version integrity change in PR #86. Customer and Listener remain the only app modes. Test units remain `TEST_MICROCREDIT` and `TEST_PAISE`; neither is production money or a payout entitlement.

## Concrete problem and resulting behavior

The existing journal rejected updates and deletes, but a later transaction could insert another balanced pair into an already committed batch. Wallet-account metadata could also be changed after posting, reclassifying an owner, unit or account kind without rechecking historical balances. Two isolated pre-fix failures reproduced these gaps.

Migration 019 adds a persistent batch seal. Existing batches start sealed without changing their IDs, timestamps, original fields, lines or totals. Before inserting a new batch, the database forces its seal to false regardless of a caller-supplied value. Lines may be appended only to a visible unsealed batch. A deferred batch-insert check always requires nonempty postings balanced separately per unit, then seals the batch. Other transactions cannot see its uncommitted open state; once committed it cannot receive further lines.

The only allowed batch update is false-to-true sealing with every other field unchanged. An early seal rejects more lines but cannot skip deferred validation. Reopening, other batch changes, deletion, line mutation and truncation are rejected. Account identity, owner, unit and kind are immutable; semantic no-op account updates and new accounts remain possible. Existing seed and call-settlement writers already post complete batches in one transaction and need no source changes.

The seal persists independently of transaction-number reuse, including across database installations. Independent design review rejected a transaction-ID-only approach for this reason. Savepoint coverage verifies that rolling back an early forced constraint check restores pending validation. This follows PostgreSQL's [deferred constraint-trigger semantics](https://www.postgresql.org/docs/17/sql-createtrigger.html); a full production backup/restore exercise is still separate acceptance under FA-054.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Meaningful pre-fix failures | 2 tests failed because late balanced appends and unit reclassification were incorrectly accepted | `journal-integrity-red.log` |
| Focused isolated PostgreSQL | 16 passed; zero failures/skips/cancellations; 22.104 seconds | `journal-integrity-focused.log` |
| Independent migration and test review | No blocking findings | Recorded in the PR |
| Full isolated backend regression | 431 passed; zero failures/skips/cancellations; 363.211 seconds | `journal-integrity-integration-final.log` |
| Typecheck/build/unit checks | Passed; 74 API, 7 domain and 3 audio cases; unchanged domain/audio results reused by Turbo | `journal-integrity-typecheck-final.log`, `journal-integrity-build-final.log`, `journal-integrity-test-final.log` |
| Direct `node --test` from `audio/` | 3 passed | `journal-integrity-audio-reference-final.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling cases | `journal-integrity-repo-check.log` |
| Implementation-commit CI | Backend, Android and staff passed for `9083a397e8477f4fb8ad74399e4972467b0d4c57` | [PR #87](https://github.com/agilandeenadhayalan/nightshift/pull/87), [run 44876049224](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44876049224); any subsequent documentation-head result is recorded in the PR |

The focused suite covers account identity/owner/unit/kind changes, unused deletion, semantic no-ops, multi-statement and savepoint posting, caller-supplied true/false/null seals, empty and cross-unit-unbalanced commit rejection, early sealing, forced deferred checks followed by savepoint rollback, injected whole-transaction rollback, immutable history, separate corrective test postings, actual cascading truncation, foreign-transaction attempts and a same-key contender observed waiting on the creator. Concurrent/idempotent seeding retains three grants and six lines without reopening batches.

Valid and deliberately anomalous 18→19 fixtures preserve original accounts, batches, lines, unit totals, calls, events and outbox records exactly while marking existing batches sealed. Prior migration checksums remain unchanged and migration replay succeeds. Older schema/rate-upgrade fixtures exclude only the new seal metadata from their historical comparisons; they retain their existing financial/rate assertions and explicitly check sealed batches after upgrade.

## Recovery and incomplete acceptance

Existing anomalies are preserved and closed, not certified, corrected or silently reclassified. Any actual historical mismatch needs a reviewed reconciliation and correction. This change does not create the required original-event reversal service, credit lots, allocations, paid/promo rules, real currency books, purchase verification, refunds or payout accounting. Those remain part of FA-034 and downstream issues, with the production route/economics decisions still outstanding.

The new column and guards are additive for current transactional writers. An application rollback can retain the guards; do not reopen committed batches to regain old behavior. Restore procedures must preserve the seal. A data-only import with active validation cannot use an autocommit stream of empty batches followed later by their lines; loading a complete balanced batch in one transaction is required. That alone cannot restore preserved legacy empty or per-unit-anomalous batches, because active insertion guards treat them as new and reject them. Faithful historical restoration needs a reviewed full-restore sequence that loads sealed data before installing guards, or an equivalent controlled restoration procedure. This continuation does not claim a restore exercise.

No live migration, history repair or deployment was performed. The private phone database remains at migration 014. Mobile and response contracts are unchanged, so APK 6007 retains its existing source provenance; no new build or installation is required for this change.
