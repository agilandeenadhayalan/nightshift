# Call history precision and calendar verification

FA-031 / issue #31 continuation, stacked on PR83 at `f9a9238c49cc0a28376ec498d2de9d755bd66a16`. Customer and Listener remain the only app modes; staff authorization is separate. FA-020 and FA-027 remain the acceptance dependencies.

## Problem and scope

The history query loads a PostgreSQL cursor timestamp into a JavaScript Date and binds it back into SQL. This truncates microseconds: an anchor at `.123456` becomes `.123000`, potentially skipping older rows in the same millisecond. Current call creation writes millisecond timestamps, so this is a schema-valid precision defect, not evidence of lost history from the installed phones.

Preserve UUID cursor validation and participant authorization, but compare the original stored `(created_at, id)` tuple inside PostgreSQL. Retain descending order, the 20-item page plus one lookahead, response shape and existing errors. No migration, financial calculation, contract or mobile production change is needed.

The existing mobile calendar helper already compares local calendar dates rather than elapsed hours. Add verification for year/leap boundaries and fixed UTC fixtures under process-scoped UTC, Asia/Kolkata, America/New_York and Pacific/Kiritimati zones in Linux CI. Cover New York's 23/25-hour days and repeated hour without modifying host settings or adding a time-zone dependency.

## Ownership and checks

- Backend: `service.ts` and focused real PostgreSQL/HTTP history tests. First reproduce the microsecond skip; then test ties, multiple pages, bounds, ownership/errors, newer concurrent insertions and failed-call zero charges. Use only the isolated test database and Redis lane.
- Mobile verification: one focused calendar test file and a narrow Linux CI step; no production Dart changes or new APK.
- Root: integration test registration, evidence, issue register, review and draft PR publication.
- Independent reviewer: query/privacy/order and test coverage, then documentation accuracy.

Run focused checks followed by the full isolated backend regression, typecheck/build, repository checks and affected mobile tests. CI must pass for the final source commit, including the actual named-zone executions. Preserve failure logs and distinguish local Windows evidence from Linux zone evidence. Do not deploy, install, send provider messages or close the whole issue from this continuation.

## Execution

- [x] Reproduce and fix the precision defect with participant-only pagination evidence: four pre-fix precision failures, then eight focused cases passed.
- [x] Verify calendar boundaries locally and all four process-scoped zones in CI: UTC/Kolkata/Kiritimati 8 passed each, New York 11 passed; no failures and explicit other-zone skips.
- [x] Complete independent review and required local regression checks: 404 backend integration, 449 Flutter (24 explicit Linux-zone skips), clean analyzer, 74 API, 7 domain, 3 audio reference and 11 tooling cases.
- [x] Publish draft PR84 stacked on PR83; backend, Android and staff CI passed for final head `3d76f5d41bb31bd7c922f6c2d529dfc2e7465bd9` in run44871582338.

Physical current-build history/reconnect checks and upstream acceptance remain separate. There is no new owner decision required for this engineering fix.
