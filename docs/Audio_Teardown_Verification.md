# Audio teardown verification

This continuation hardens the implemented audio lifecycle in FA-026/027/028/029. It builds on PR81's incoming invitations. It does not add ongoing background media or complete the physical-device acceptance criteria.

## Behavior and ownership

End, background teardown and logout admit native cleanup immediately, without waiting for disk storage or a server response. Local readiness and join callbacks are invalidated synchronously. Native shutdown explicitly attempts microphone capture disable before transmission mute, channel leave and engine release. Individual rejected cleanup operations do not prevent later shutdown operations from being attempted.

The caller waits at most three seconds for cleanup. A timeout reports `RTC_CLEANUP_PENDING`; a rejected native release reports `RTC_CLEANUP_FAILED`. The original native completion future remains the ownership barrier. Neither result permits a second engine or proves that capture stopped. Repeated preview stops observe the same pending release. Call permission preflight checks this barrier before and after the Android permission dialog, so an unresolved prior engine cannot admit a new reservation through preflight.

Controller termination captures the owner, API origin, call, action, expected version and idempotency key. Unknown network outcomes retry the same command. Only a definitive conflict response followed by an authenticated current-call read creates a replacement command. Stop intent is saved separately from native cleanup and server dispatch; a blocked storage operation cannot block End. Recovery accepts a legacy call marker only when the authenticated current snapshot names that same call. Late cleanup, network and persistence work is fenced against a replacement account or call.

Stopping prevents new positive media reports. It does not recall a positive report already in flight, and it does not promise an immediate server-side `ready:false`: the current protocol has no media epoch. Terminal End remains the durable server fence. UI copy says the app is waiting for confirmation instead of asserting that the microphone or camera has stopped.

The server compares End's expected version with the initially locked persisted version. Its own uncommitted time-based reconnect transition can no longer invalidate an otherwise current End. A genuinely committed competing transition still produces a conflict. Terminal replay keeps its payload binding and current authorization checks.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Full isolated PostgreSQL/Redis/HTTP regression | 388 passed; zero failures/skips/cancellations; 295.222 seconds | `audio-teardown-full-integration-final.log` |
| Focused server ordering/authority/integration/video | 48 passed, including four new End-ordering cases | `call-end-ordering-green.log` |
| Top-level typecheck/build/test | Passed; 74 API unit/provider tests and 7 domain tests | `audio-teardown-typecheck-final.log`, `audio-teardown-build-final.log`, `audio-teardown-workspace-test-final.log` |
| Full Flutter and analyzer | 401 passed; zero failures; analyzer clean | `audio-teardown-mobile-tests.log`, `audio-teardown-mobile-analyze.log` |
| Final focused controller/media/safety | 78 passed, including 19 new teardown regressions and stronger real-transport safety coverage; analyzer clean | `audio-teardown-controller-final-focused.log`, `audio-teardown-controller-final-analysis.log` |
| Focused native adapter/video | 30 passed, including 15 new lifecycle regressions | `audio-teardown-adapter-focused.log` |
| Required browser audio reference | 3 passed with `node --test` from `audio/` | `audio-teardown-audio-reference.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling tests | `audio-teardown-repo-check.log` |
| Generated Dart client | 90 files verified without drift | `audio-teardown-client-check.log` |

The server regression first reproduced a failure when End itself advanced stale media into reconnecting. After the fix, a call with 42 seconds of confirmed healthy time followed by a six-second gap ends once, settles once, excludes the gap from charging and releases its claims and hold. Separate real-lock tests preserve rejection of genuinely stale versions. Exact replay and late healthy media cannot revive or charge the terminal call.

Mobile regressions use fake SDK operations and controlled storage/network completion. They establish ownership and ordering under stalls; they do not establish native microphone release, audible media, Android focus behavior or provider delivery. Earlier failed logs are retained alongside final results.

The first full Flutter run passed 398 of 399 tests. Its old safety fixture depended on SDK cleanup blocking a request before account replacement. Replacing that timing assumption with real `NightShiftApi` transport gates exposed a separate stale-error path: rejection of the old owner's mutation could publish an error and refresh the replacement account. The safety operation now fences its failure continuation by owner and origin. Tests cover both replacement during credential preparation and a successful old-owner block response after replacement; a current-owner failure still surfaces normally. The final full run passed all 401 tests.

Stop intent is admitted in memory before disk work. If secure storage never acknowledges a write or the process exits before that acknowledgment, durability is not established; server media freshness and session/call reconciliation remain necessary. A cleanup timeout similarly leaves actual capture release uncertain and blocks later engine creation.

## Configured private Android artifact

`nightshift-audio-teardown-6004-arm64.apk` is 163,287,278 bytes, SHA-256 `d31c83ea4105a99d9a486e4ce7cf64fa71178eeb101e8866dccba32f72109e23`. It uses `com.agilandeenadhayalan.nightshift`, version 0.1.0 / 6004, with the already registered local debug signer. Flutter's ARM64 split adds 2000 to the supplied build number4004. The build took 40.43 seconds; all 211 source inputs and four ignored private configuration/CA inputs stayed unchanged. `audio-teardown-build-record.json` records their hashes and the signature/manifest checks. Earlier APK6003 remains preserved.

All 31 ARM64 native libraries passed ELF load and stored-ZIP 16KB alignment checks. Android BuildTools36 `zipalign -c -P 16 -v 4` independently passed. `audio-teardown-native-alignment.json` explicitly records `runtime16kbTested:false`; static alignment does not prove operation on a 16KB device. Target/compile API35 and release-signing/current Play target work remain separate gates. No ongoing-call service was added, and this APK was not installed.

## Deployment and remaining evidence

No migration, contract expansion, new foreground service, live provider request or device installation is part of this continuation. The private phone runtime and installed build remain unchanged. Physical tests still need to measure capture cessation, interruptions, headset and network changes, background behavior and process recovery on the selected phones. Ongoing Android call support and production/provider acceptance remain open.
