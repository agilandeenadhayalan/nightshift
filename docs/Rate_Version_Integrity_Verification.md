# Test rate-version integrity

This continuation addresses an integrity prerequisite for [FA-033 / #33](https://github.com/agilandeenadhayalan/nightshift/issues/33), following the schema foundation. It does not supply approved production prices, Listener compensation, store SKUs, a payment route or the full versioned catalogue. Customer and Listener remain the only app modes.

## Problem and behavior

Calls already freeze their rate ID, policy snapshot and maximum duration under the existing call-terms trigger. However, `rate_versions` itself permitted changes, and development seeding silently accepted any existing row under the bundled audio/video version IDs. The runtime currently uses its server-owned test-rate constants, so this was an integrity gap rather than evidence of changed charges on the installed phones.

Migration 018 makes rate versions append-only: changed updates, deletion and truncation are rejected with SQLSTATE 23514. A whole-row semantic no-op update is allowed; JSONB object-key ordering does not constitute a policy change. New version insertion remains possible under the existing test-only constraint. No stored price, historical call, journal or event is rewritten.

Seeding retains its transaction and advisory lock. It inserts missing bundled rates, then validates both policies with PostgreSQL JSONB equality and the test-only flag under shared row locks. A fixed `RATE_VERSION_CONFLICT` error rolls back the entire transaction before fixture users, wallets, grants or reviews are written. If the second rate conflicts, a newly inserted first rate also rolls back. Policy values are not included in that error.

Existing conflicting rows survive migration unchanged and are rejected by subsequent seeding. There is no automatic repair or API startup gate. Any actual historical mismatch requires a separately reviewed repair; changing a version in place or silently replacing it is not recovery. Older unchanged seed behavior remains compatible with already valid rows, while the new seeder also works against the older 001/002 schema used in forward-upgrade tests.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Meaningful pre-fix failures | 2 tests failed because policy mutation and conflicting seeding were incorrectly accepted | `rate-versions-red.log` |
| Focused isolated PostgreSQL | 11 passed; zero failures/skips; 16.859 seconds | `rate-versions-focused.log` |
| Full isolated backend regression | 415 passed; zero failures, skips or cancellations; 367.107 seconds | `rate-versions-integration-final.log` |
| Typecheck/build/unit checks | Passed; 74 API, 7 domain and 3 audio reference cases | `rate-versions-typecheck-final.log`, `rate-versions-build-final.log`, `rate-versions-test-final.log` |
| Direct `node --test` from `audio/` | 3 passed | `rate-versions-audio-reference-final.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling cases | `rate-versions-repo-check.log` |
| Independent migration, seed and test review | No blocking findings | Recorded in the PR |
| Final-commit CI | Pending | Recorded in the PR after completion |

The focused suite covers changed policy/ID/timestamp rejection, semantic no-op updates, unused-version deletion and actual cascading truncation, insertion of a new test version, key-order equivalence, repeat seeding, full rollback on first/second-rate conflict, eight concurrent seeders, and a conflicting insert committed while seeding demonstrably waits on its database lock. Forward17→18 fixtures preserve valid and conflicting rate rows, call snapshots, journal and outbox data, with stable prior migration checksums. The broader schema suite also exercises the older001/002 forward fixture.

The separate post-insert validation query matters: an insert with `ON CONFLICT DO NOTHING` can encounter a competing row that was not visible at the start of that statement. The later locking read checks the committed policy and holds it through fixture creation. These tests exercise PostgreSQL's documented [read-committed behavior](https://www.postgresql.org/docs/17/transaction-iso.html) and [shared row locks](https://www.postgresql.org/docs/17/explicit-locking.html).

## Deployment and remaining acceptance

Migration 018 is forward-only and changes guards without backfilling data. It is exercised only against isolated test schemas in this continuation; the private phone database remains at its original 14 migrations. No live migration, data repair, deployment, purchase, payout, provider operation or mobile installation is included.

Mobile and API response contracts are unchanged, so there is no new APK. APK 6007 retains its source provenance at PR #85. Reverting application code does not require removing the new database protections; any proposed removal or historical repair must be reviewed separately.

Full FA-033 still lacks issued/expiring owner-bound quotes, pack/SKU availability, paid/promo distinctions and the approved route/economics/tariff decisions recorded in D12–D15 and D23–D24. The present quote ID is still the test rate ID; no claim of quote expiry is made by this fix. Production catalogue activation and price changes remain outside this integrity slice.
