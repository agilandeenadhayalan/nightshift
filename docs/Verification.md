# Android test milestone verification

Recorded 20 November 2026. This distinguishes executed automation from physical-device and provider evidence. The implementation is a development slice, not completion of all 64 issues or a paid-release approval.

## Executed automatic checks

| Check | Result and scope |
|---|---|
| Browser reference: Node 24.13.0 `node --test` from `audio/` | 3/3 passed. Existing audio source and tests unchanged. Windows Node 20 initially lacked the required SQLite runtime; all final checks used Node 24. |
| TypeScript build / type check | Passed for NestJS 11.2.11 and TypeScript 5.9.3. |
| Backend unit suite | 4/4 passed: tariff boundaries, fixed-point earnings, production-startup refusal, field validation. |
| PostgreSQL/Redis integration suite | 18/18 passed against real local services. Isolated schema per run; no production data. Covers concurrent reservations, idempotency, ownership, stale/terminal transitions, reconnect gaps, journal balance/immutability, bounded test-credit exhaustion, role/session guards, blocks/reports, HTTP contracts, revoked sockets, ordered event replay and block/end lock contention. |
| Migrations and seed | Applied to empty databases; repeated migration and seed preserved one grant. Additive migration 002 supplies durable event ordering. |
| API/event contracts | Generator `--check` passed; HTTP response validation and deliberately incompatible response checks passed. Full generated Dart-client adoption remains outstanding in #7. |
| Flutter static analysis | Passed with no issues on Flutter 3.27.4 / Dart 3.6.2. |
| Flutter tests | 25/25 passed: navigation/restoration, Tamil and large text, roles, microphone denial, SDK-readiness boundary, token failure, background termination, immediate offline hang-up, stale response/version recovery, no rejoin after end, safety controls and history pagination/date grouping. RTC is fake only inside these tests. |
| Android universal debug APK | Built successfully. Package `com.nightshift.app`, label NightShift, version 0.1.0+1, minimum SDK 23 and target SDK 35 confirmed with Android `aapt`. |
| Economics | 10/10 Python tests passed, including historical example, 12 audio/video scenarios, OTP amortization, nonfinite input rejection and negative-contribution rejection. |
| Checkout secret/file guard | Passed; 2 tests passed. A separate deliberate synthetic private-key-header file made the actual CLI exit 1; after removal the same CLI exited 0. Local environments, credentials, databases and generated builds remain ignored. |
| npm dependency audit | 0 vulnerabilities reported for the locked dependency set during this run. |
| Diff whitespace | Checked after cleanup of authored documentation. |

## Actual WSL runtime and HTTP journey

The final NestJS image was built and run with PostgreSQL 17.7 and Redis 7.4.7 in Ubuntu WSL 2. All three health checks passed, and Windows reached `http://127.0.0.1:3000/v1/health`.

`npm run smoke:api` exercised real HTTP login for the fictional Customer and Listener, Listener availability, Customer discovery, an idempotent invitation, Listener acceptance, Customer end, released claims and the same completed call in both histories. No media-readiness event was fabricated; the unjoined call cost zero. Safe diagnostic call ID: `26f02d98-285f-4ebe-824e-05aa9686125f`.

The API container was restarted. The smoke harness with `SMOKE_CALL_ID` then confirmed both participants could still retrieve that completed zero-charge call. This verifies persistence across an actual process/container restart.

Windows Docker Desktop and Ubuntu's native Docker daemon are distinct on this machine. The initial mixed-context attempt collided on local ports, and detached WSL commands allowed the distro to stop. The verified route keeps one Ubuntu session active and runs the whole stack in one context; see [Local_Development.md](Local_Development.md). No unrelated containers or data were removed.

After verification, only the NightShift test services and the temporary agent WSL keepalive were stopped. Database volumes were preserved. Start the stack with the runbook when installing the APK; no hidden persistent helper is required.

## APK artifact

Recommended for ARM64 phones: `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, 159,492,318 bytes (about 152 MiB), SHA256 `0e16a32ae87cc3e8f763755e8c79d3e4cba0c693a9c2ff8f63a4066e0cf7da2a`. Android `aapt` confirms the same `com.nightshift.app` package and only the ARM64 ABI. Flutter assigns split-APK version code 2001; the universal build has version code 1. Use one variant consistently, or allow debug downgrade explicitly when changing back to universal.

Universal local output: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.

- Size: 450,914,362 bytes (debug/native RTC libraries across ABIs).
- SHA256: `b431f95fc147920525df5330de2ba92c740adf62d9ffc458d5fd0a5286513d81`.
- Debug build only; no production signing, embedded test access key or Agora certificate.
- Both modes share this single package. CI builds the smaller ARM64 variant from the same project.

The subsequent workspace/task-graph refactor was revalidated separately; see [Monorepo_Verification.md](Monorepo_Verification.md) for its 73 tests, packaged API smoke run and APK rebuild. The latest schema/generated-client continuation is recorded in [FA007_Verification.md](FA007_Verification.md), including 94 passing tests, a real Dart SDK HTTP journey and the newer ARM64 APK hash. The artifact hashes above belong to the earlier milestone build.

## Subsequent physical verification and remaining evidence

The later [20 November two-phone run](Device_Debug_2026-11-20.md) **passed the first foreground test-credit milestone** on Redmi and Motorola phones with one APK and backend. The tester confirmed audible speech both ways, speaker/earpiece routing and both mute controls. Each participant ended a connected call; native microphone access stopped, both histories matched and survived app/API restarts. Read-only database audits verified balanced unique settlements and released claims/holds. These results supplement the earlier automation and APK evidence above; use the dated report for the installed QA APK hash and exact call IDs.

Brief reconnect transitions occurred and their cause is unresolved. Controlled network interruption, Wi-Fi/mobile crossover, headset/Bluetooth, permission-denial recovery and physical accessibility checks remain open in [Two_Phone_Test.md](Two_Phone_Test.md).

The prototype intentionally ends calls and withdraws availability when backgrounded. Full FCM/background/lock-screen calling is #29. Provider callbacks and immediate server-enforced media cutoff against a modified client remain #25/#27/#37. Short-lived tokens and a cooperative client leaving are not cutoff proof.

Production OTP/Firebase, real listener onboarding/review, purchases, refunds, payouts, staffed safety/support, reviewed policies, Play testing/release and expansion remain in [Issue_Status.md](Issue_Status.md). No issue is closed based on a mock, missing approval or this test build. All owner decisions are recorded in [Decision_Register.md](Decision_Register.md).
