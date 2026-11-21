# Server-confirmed call allowance verification

This continuation implements the remaining-time and warning portion of [FA-030 / #30](https://github.com/agilandeenadhayalan/nightshift/issues/30), on PR82's verified teardown foundation. Customer and Listener remain the only app modes. It does not complete the issue's physical headset/screen-reader checks or its upstream background-call acceptance.

## Meaning of the display

The call's frozen `maxDurationSeconds` allocates healthy connected time. Remaining allowance is that duration minus the server's confirmed `connectedMs`, clamped at zero. Positive milliseconds round up to a whole second for display only. The app does not tick this value using its own clock, calculate a charge, extend a call when wallet credits change or send End when the display reaches zero.

The development tariff's minimum charge and time allowance are different. A 60-test-coin audio reservation allocates 60 healthy seconds. It is free through 40 seconds; at 40.001 seconds the server applies the 60-coin minimum while 19.999 seconds of the allocation remain. Video has the same time boundary with its separate 120-test-coin minimum. The displayed charge and illustrative Listener earnings continue to come from the server. Held credits make the wallet's available balance unsuitable for an in-call time warning.

Both audio and video show their frozen rate. In Listener mode it is explicitly labelled the customer rate, separate from illustrative Listener earnings. At one minute or less of confirmed allowance, the warning distinguishes a test-credit limit from the development duration cap. Legacy calls without that reason use neutral allowance wording. Invalid allowance values reaching the presentation model show unavailable information rather than a fabricated zero warning. Missing or wrongly typed required wire fields retain the generated client's invalid-response handling; the controller preserves its last accepted snapshot and reports the error. Zero allowance waits for server confirmation and retains the manual End control. Reconnect copy explains uncharged confirmed gaps and limited recovery without inventing a grace countdown.

The value is a confirmed allocation, not a promise of equivalent wall-clock conversation time: interruption, loss of authorization, blocking, the absolute lifetime limit or other authoritative termination can still end a call. Production prices and payable earnings remain unapproved; this is test-credit behavior.

## Contract and compatibility

`Call.durationLimitReason` is an optional string enum: `test_credit_balance` or `test_duration_cap`. New server projections derive it solely from the frozen duration: below 600 seconds is balance-limited; 600 seconds is the current development cap. The existing database constraint is 60–600 seconds. No pricing, reservation, hold, charging, settlement, lifecycle or database migration changes are included.

Omission stays valid for historical durable events and cached idempotent receipts. Those old payloads are not rewritten on read. New clients preserve both known reasons and accept omission; unknown wire enum values retain the existing safe invalid-response handling. Generator templates were not relaxed.

The actual previous generated Dart decoder accepted the additional response field before generation and ignored it, which supports the old-client/new-server direction. The previous standalone event JSON Schema disallowed additional properties and would reject the new field if used independently. Deploy the canonical contract/schema with its API; this local evidence does not establish a live rolling upgrade. Public and event schemas are generated from the same definition and the required property list is unchanged.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Focused isolated database/HTTP allowance cases | 8 passed; initial run reproduced six missing-field failures with two existing-behavior controls passing | `call-allowance-red.log`, `call-allowance-focused.log` |
| Final full isolated database/HTTP regression | 396 passed; zero failures/skips/cancellations; 317.776 seconds | `call-allowance-integration-final.log` |
| SDK and API decoding | 33 passed, including six new compatibility cases | `call-allowance-contract-RED.log`, `call-allowance-contract-GREEN.log` |
| Final full Flutter and analyzer | 447 passed; zero failures; analyzer clean | `call-allowance-mobile-tests.log`, `call-allowance-mobile-analyze.log` |
| Focused allowance presentation/models | 38 passed, including English/Tamil audio/video at 2x text and explicit End/report at zero allowance | `call-allowance-mobile-focused.log` |
| Top-level typecheck/build/test | Passed; 74 API unit/provider, 7 domain and 3 reference tests executed | `call-allowance-typecheck-final.log`, `call-allowance-build-final.log`, `call-allowance-test-final.log` |
| Required `node --test` from `audio/` | 3 passed independently with pinned Node24 | `call-allowance-audio-reference-final.log` |
| Canonical and generated-client checks | Canonical schemas match; 90 generated files verified without drift | `call-allowance-client-check.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling tests | `call-allowance-repo-check.log` |

The database tests cover both rates, the 599/600-second boundary and above-cap balances, minimum reservation rejection, frozen classification after later wallet credits, minimum-charge/remaining-time separation, ringing and reconnect gaps, participant-only HTTP/event/history access, and exact replay of legacy receipts without extra effects. Old event bytes remain unchanged. Provider transports are not contacted.

The first full integration attempt lost PostgreSQL and Redis during an existing matching test. Its first error was `ECONNRESET`, followed by connection refusals; the existing local containers had stopped with exit 255. The failed run is preserved as `call-allowance-integration-infrastructure-failure.log`. After restoring the same dependency containers and volumes, the unchanged suite passed all 396 tests. No test timeout, source assertion or application behavior was changed to address that incident.

## Configured private Android artifact

`nightshift-call-allowance-6006-arm64.apk` is 163,291,461 bytes, SHA-256 `f5f643541baec6c092176c9e3933c86283354eceb1d08f751f030f6cb4cd9560`. It uses `com.agilandeenadhayalan.nightshift`, version 0.1.0 / 6006, and the already registered debug signer. Flutter's ARM64 split adds 2000 to the supplied build number4006. The build took 50.24 seconds. All 215 mobile/SDK source inputs and four ignored private configuration/CA inputs stayed unchanged; `call-allowance-build-record.json` records their hashes and signature/manifest checks. Earlier APK6003–6005 remain preserved.

All 31 ARM64 libraries passed ELF load and stored-ZIP 16KB alignment. Android BuildTools36 `zipalign -c -P 16 -v 4` also passed. `call-allowance-native-alignment.json` records `runtime16kbTested:false`; static alignment is not a 16KB device result. Target/compile API35, release signing and current Play target work remain separate. The artifact was not installed.

## Deployment and remaining evidence

The existing private phone runtime code, installed apps and provider configuration remain unchanged. The infrastructure outage also stopped the private phone API; its previously verified runtime was restarted with the same private configuration. Its health check passes and a read-only check confirms the original 14 migrations. Both phones retain their existing USB routes. This was baseline recovery, not deployment of the new branch.

No SMS, FCM, RTC call, purchase, staff grant or device installation occurred for this display work. Current-source physical TalkBack, headset changes and the wider network/background matrix remain required before claiming FA-030 or its dependencies complete.
