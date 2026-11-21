# Call history pagination and calendar verification

This continuation addresses stable pagination and calendar evidence for [FA-031 / #31](https://github.com/agilandeenadhayalan/nightshift/issues/31), following the call lifecycle foundation. Customer and Listener remain the only app modes. Full upstream FA-020/027 and current-device acceptance remain separate.

## Cursor precision

PostgreSQL stores timestamps at microsecond precision; the JavaScript Date used by the previous cursor path retains only milliseconds. Binding that Date back into the page query changed an anchor at `.123456` to `.123000`. Valid older calls within the same millisecond could therefore disappear after the first page.

The continuation compares the original stored `(created_at, id)` tuple inside PostgreSQL. The cursor is still the last returned session UUID, validated through the existing participant-authorized lookup. The page query also filters both its results and its anchor by participant. It keeps descending timestamp/UUID ordering, 20 returned items and one lookahead row. Public timestamp formatting and all response contracts are unchanged; display timestamps do not determine cursor ordering.

Current call creation uses millisecond timestamps. The regression exercises schema-valid microsecond rows; it does not establish that the installed phones previously lost history. No migration, financial mutation, lifecycle change or mobile production change is required.

Newer calls inserted after a page do not displace its older continuation; they appear on a fresh first page. This is keyset pagination, not a snapshot spanning multiple HTTP requests. The current runtime does not delete or retimestamp call rows. External deletion or retimestamping can invalidate or move an anchor; a missing cursor before validation retains the existing 404, and an anchor removed between validation and the page query produces an empty continuation.

## Calendar behavior

The existing Dart helper converts instants to the user's local calendar date and compares today/yesterday by year, month and day. It already avoids treating a day as an elapsed 24-hour interval. Verification adds fixed boundaries for year changes and leap days plus four process-scoped Linux zones: UTC, Asia/Kolkata, America/New_York and Pacific/Kiritimati. New York fixtures include spring/fall transitions and the repeated autumn hour. No host time-zone setting or third-party time-zone dependency changes.

Local Windows checks and actual named-zone Linux CI results are recorded separately below. Automated date grouping does not establish physical rendering, TalkBack behavior or a complete device matrix.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Focused real PostgreSQL/HTTP pagination | 8 passed; unchanged old query first reproduced four precision failures with four controls passing | `call-history-red.log`, `call-history-focused.log` |
| Full isolated backend regression | 404 passed; zero failures/skips/cancellations; 309.864 seconds | `call-history-integration-final.log` |
| Local focused calendar verification | 2 passed, 24 explicitly skipped because no Linux zone was configured | `history-calendar-local-focused.log` |
| Full local Flutter and analyzer | 449 passed, 24 explicit zone skips, no failures; analyzer clean | `history-calendar-mobile-tests.log`, `history-calendar-mobile-analyze.log` |
| Typecheck/build and unit/provider/domain/reference | Passed; 74 API, 7 domain, 3 reference tests | `call-history-typecheck-final.log`, `call-history-build-final.log`, `call-history-test-final.log` |
| Direct `node --test` from `audio/` | 3 passed | `call-history-audio-reference-final.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling tests | `history-repo-check.log` |
| Independent query, test and CI review | No blocking findings | Recorded in the PR |
| Four named-zone Linux probes and final-commit CI | UTC, Kolkata and Kiritimati: 8 passed each; New York: 11 passed. Other-zone cases explicitly skipped per process. Backend, Android and staff CI all passed for `3d76f5d41bb31bd7c922f6c2d529dfc2e7465bd9` | [PR84 / run44871582338](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44871582338) |

The eight database cases cover 45 distinct microsecond timestamps inside one millisecond, identical full-precision timestamp ties, empty and boundary-sized pages, 121 rows across both participant positions, foreign/missing/malformed cursors and details, unauthenticated access, insertion between pages and zero-charge failed history without financial or event writes. HTTP responses validate against the real `CallPage` schema.

The first test-development run also contained two incorrect error-envelope assertions. That log is retained as `call-history-initial-fixture-red.log`. Correcting those assertions and rerunning the unchanged query established the four actual precision failures recorded above; no runtime assertion or timeout was relaxed.

## Deployment boundary

The fix reads existing schema and uses the same endpoint/cursor contract. It needs no data rewrite or database migration. No new Android artifact is needed because mobile production inputs are unchanged; the previous configured APK6006 remains preserved with its own source provenance. No APK installation, live backend upgrade, SMS, FCM, RTC call or staff grant is part of this history continuation.

The earlier two-phone history/restart result remains attributed to its original runtime and build in [device evidence](Device_Debug_2026-11-20.md). It is not a physical test of this newer query. Issue #31 remains open while its wider dependency and physical acceptance evidence is incomplete.
