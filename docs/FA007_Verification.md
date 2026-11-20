# FA-007 verification — 20 November 2026

Actual GitHub issue: [#7](https://github.com/agilandeenadhayalan/nightshift/issues/7). This continuation implements its database and versioned-client foundation on top of the monorepo PR. One Android application still exposes only Customer and Listener modes, using one NestJS/PostgreSQL backend.

## Acceptance evidence

| Requirement | Implementation and check |
|---|---|
| Identity, review, calls, claims, ledger, purchases, payouts, reports and outbox schema | Existing core tables plus additive migration 003 cover the named entities. New identity/applicant ownership links and sandbox purchase/refund/payout records enforce unique references, ownership and immutable amount snapshots. No production adapter or monetary route is enabled. |
| State transitions, unique keys, UTC and fixed-point units | [Database_Model.md](Database_Model.md) describes existing API call transitions and new database transition guards, compound foreign keys, idempotency/deduplication keys, `timestamptz` instants and integer paise/microcredits. |
| Versioned schemas and generated client | Canonical OpenAPI 3.1/events schemas remain checked in. Official OpenAPI Generator 7.26.0 with a pinned JAR SHA256 produces the 44-file Dart SDK. The Flutter API facade uses its operations/models in the real call path. |
| Empty and representative database migrations | Ten real PostgreSQL schema tests include repeated empty migration and forward upgrade from 001/002 while preserving prior checksums, seeded identities/review/journal and completed-call/outbox records. |
| Incompatible changes rejected | Backend HTTP contract tests and generated Flutter tests reject missing required fields, unknown mode/language values, malformed nullability and fractional/string financial integers. A deliberate generated-source edit failed exact regeneration comparison; restoring its bytes returned the check to green. |

The generator is not a complete JSON Schema validator; backend validation continues to enforce formats, bounds and authorization. Production identity, full financial journaling/credit lots, receipt fulfilment, provider verification, payable reservations, staff controls and payments/payout workflows remain their separate downstream issues. Engineering verification here does not infer owner approvals, merge the PR or close GitHub issues automatically.

## Checks actually run

**94 tests passed:** 10 repository-tooling regressions, 5 backend-domain tests, 2 API units, 3 unchanged browser-reference Node tests, 28 PostgreSQL/Redis integration/schema tests, 36 Flutter tests and 10 Python economics tests.

Root commands used: `check:repo`, `typecheck`, `test`, `test:integration`, `test:economics`, `check:client`, `check:mobile`, `build:android` and `smoke:client`. TypeScript and Flutter static checks passed. Fresh Linux container build/runtime dependency installs reported zero npm vulnerabilities and the rebuilt API became healthy after applying migration 003.

The refund concurrency review reproduced a REPEATABLE READ over-reservation defect in a lock-only implementation. Two earlier snapshots could each reserve 6,000 against 10,000. The final trigger writes the parent row before aggregating reservations: the stale transaction receives SQLSTATE `40001`, and a fresh whole-transaction retry rejects the excess. Both READ COMMITTED and REPEATABLE READ regressions now pass.

The root validation gate was also tested with a temporary synthetic forbidden-key header. It exited 1 before downstream checks, then passed after removal. No actual secret was used or committed. This supplements the existing green CI evidence for #5.

One initial local integration run waited because the existing Docker Redis container had no published host port, despite being reachable from the API network. Only NightShift's Redis container was recreated to restore loopback port 56379. The combined suite then passed, and a fresh bounded run passed all 28 cases in about 8.5 seconds. Integration commands now impose a 60-second test timeout.

## Actual generated-client HTTP journey

`npm run smoke:client` used the generated Dart SDK against the rebuilt local NestJS container. It verified fictional Customer/Listener authentication, online discovery, idempotent invitation, acceptance, Customer end, zero charge without media, the same completed call in both histories, released claims and session cleanup. Credentials were inherited privately from the ignored environment; output contains only safe diagnostics.

Safe call ID: `ddc510e9-3fa3-4d96-b7ff-770787651d84`.

## Android artifact and remaining gates

The ARM64 debug APK was rebuilt at `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`: **179,990,217 bytes**, SHA256 `c84a50b7f64858b4b4d3d39f5ef216a90647669bd68d362e13167262068efc7b`. It uses the existing single application ID. Generated artifacts and generator JARs remain ignored.

No physical Android phones or owner-controlled Agora credentials were available. Audible two-way media, hardware permissions/routing, provider cutoff, background calls and the two-phone milestone remain unverified. The optional Playwright browser-media script was not run. Follow [Two_Phone_Test.md](Two_Phone_Test.md); provider, spending and release decisions remain in the owner decision register.

The existing local edits to `Decision_Register.md` and `Product_Scope.md` were preserved and are not included in this engineering change.
