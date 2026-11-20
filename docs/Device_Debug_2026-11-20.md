# Two-phone Android debugging — 20 November 2026

Related issues: [#6](https://github.com/agilandeenadhayalan/nightshift/issues/6), [#26](https://github.com/agilandeenadhayalan/nightshift/issues/26), [#31](https://github.com/agilandeenadhayalan/nightshift/issues/31). **The first Android milestone remains incomplete: audible two-way media was not tested because the backend had no Agora test-project configuration.**

Two physical phones exercised the same app and backend through Vysor and USB forwarding. Test accounts and test credits were used. This record separates observed device behavior, database evidence and unexecuted media checks. The reusable procedure remains in [Two_Phone_Test.md](Two_Phone_Test.md).

## Devices and build

| Item | Observed value |
|---|---|
| Redmi / Customer | Model `23077RABDC`, Android 13, security patch 2023-12-01, ARM64 |
| Motorola Edge 50 Fusion / Listener | Android 16, security patch 2026-07-01, ARM64 |
| App | One application ID, `com.nightshift.app`; version 0.1.0, version code 2001; Customer and Listener only |
| Installed APK on both devices | The same ARM64 debug APK, 159,703,503 bytes |
| APK SHA-256 | `deae02bc0cbd6671a95cc96d5ebe66060e85ef8129957c5f3927ab266526e159` |
| APK timestamp | 2026-11-20 10:41:13 UTC / 16:11:13 IST |
| Source provenance | Foundation commit `b17a99930ac511831aef849b4ca05c87e4f6f7bf` plus the native debug-capture changes on `codex/two-phone-debug`; the QA APK was built before that follow-up commit |
| Toolchain | Flutter 3.27.4 / Dart 3.6.2; Agora Flutter package 6.5.3 |
| Backend | Shared NestJS API with PostgreSQL 17.7 and Redis 7.4.7; health check passed |
| API connection | USB `adb reverse` on both phones to local port 3000 |
| Media networking | Not established; Wi-Fi/mobile topology and media behavior are not claimed |

Provider certificates, tokens and the development access key were not compiled into the APK or committed. Device serial numbers and credential values are omitted from this record.

## Fixes and setup findings

The app's `FLAG_SECURE` protection prevented Vysor from showing its screen. A local QA opt-in now permits capture only when the APK is a debug build, its native build type is exactly `debug`, and `NIGHTSHIFT_ALLOW_DEBUG_SCREEN_CAPTURE=true` was supplied at build time. Ordinary debug builds remain protected by default. Profile and release configurations force the capture field false. See [Local_Development.md](Local_Development.md) for the explicit build command and its intended QA scope.

The first camelCase Gradle property did not survive Flutter's Windows process environment handling: Dart uppercased the environment variable name, so Gradle's case-sensitive property lookup missed it. The final uppercase property works through Flutter. Generation-only checks verified these values without changing the installed APK's hash:

| Build configuration | Debug capture field | Profile capture field | Release capture field |
|---|---|---|---|
| Default | false | false | false |
| Explicit QA opt-in | true | false | false |

Flutter's profile variant has native `DEBUG=true`, so the separate `BUILD_TYPE == "debug"` check is necessary. Profile/release native field generation was checked; those variants were not installed for a physical capture test.

The Redmi initially lacked its USB reverse mapping and could not reach the backend. Reapplying the mapping after installation restored access. No API or database exposure to a public network was needed. The inspected Android/Flutter startup logs showed no fatal crash during this run.

## Physical results

| Check | Result and evidence |
|---|---|
| Both phones sign in | Passed with separate fictional accounts, the same app ID and backend |
| Listener goes online | Passed in Listener mode |
| Customer discovers Listener | Passed; the online Listener appeared and could be called |
| Invitation and acceptance | Passed up to the connecting state; missing RTC configuration produced the actionable setup error and safe termination |
| Missing RTC failure cleanup | Passed: no connected state, no healthy duration or charge, released claims and holds |
| Listener decline | Passed; call `1b03c0a5-4f4d-44e7-80a7-c301126fe448` ended as `declined` without acceptance |
| Customer cancellation | Passed; call `e832d9ba-72c7-4352-9a18-bacf411a9193` ended as `cancelled` without acceptance |
| Unanswered invitation timeout | Passed; call `9da35392-6b7e-47cc-ac63-1f3b70242aef` ended as `timeout` after approximately 30.7 seconds without acceptance |
| Both histories and persistence | Passed for the completed test attempts: both apps restored history after force-stop/relaunch, and histories remained after API restart without signing in again |
| Stale Listener availability | Passed at the observed sampling interval: after the idle Listener app was force-stopped, Customer discovery showed no available Listener at the first inspection about 65 seconds later; availability returned after Listener relaunch and foreground heartbeat |
| Audible speech in both directions | Not run; Agora app ID/certificate were absent from the backend environment |
| Either participant ends an audible call | Not run; automatic failure cleanup is not this acceptance test |
| Microphone denial, mute, routing, headset and speaker | Not run |
| Provider cutoff, network changes and media reconnect | Not run |
| Physical TalkBack and large-text checks | Not run |

For the stale-availability check, the Motorola Listener app was force-stopped with no active call at `11:02:41.097Z`. The Redmi's first inspection at `11:03:45.915Z` showed no available Listener. The configured Redis TTL is 45 seconds, but this run measured only disappearance **by that approximately 65-second inspection**, not the exact expiry instant. The Listener was relaunched around `11:03:53Z`; its signed-in history returned without another login, and Customer discovery showed the Listener available again by the next settled inspection at `11:04:15Z`. Call `e832d9ba-72c7-4352-9a18-bacf411a9193` was confirmed in both histories after the app/API restart checks.

## Durable call evidence

The following was obtained through read-only PostgreSQL queries, without logging in again, revoking sessions or changing call data. Times are UTC on 20 November 2026.

| Call ID | Created | Accepted | Ended | Recorded transitions / reason |
|---|---|---|---|---|
| `dd9a0796-c990-41a4-8e91-3caf0faf9ec8` | 10:51:42.029 | 10:51:49.060 | 10:51:49.271 | ringing → connecting → ended / participant_ended |
| `d862a7da-75a0-43be-a227-340ae6bce4ae` | 10:55:39.176 | 10:55:43.805 | 10:55:43.930 | ringing → connecting → ended / participant_ended |
| `1b03c0a5-4f4d-44e7-80a7-c301126fe448` | 10:57:05.539 | — | 10:57:10.301 | ringing → ended / declined |
| `0e441424-c8e0-4114-97fe-a3eebdbe410d` | 10:57:22.444 | 10:57:26.926 | 10:57:27.069 | ringing → connecting → ended / participant_ended |
| `149b39bd-708a-44b0-8cbc-704250acfcb7` | 10:57:40.282 | 10:57:41.619 | 10:57:41.724 | ringing → connecting → ended / participant_ended |
| `e832d9ba-72c7-4352-9a18-bacf411a9193` | 10:57:58.083 | — | 10:58:02.839 | ringing → ended / cancelled |
| `9da35392-6b7e-47cc-ac63-1f3b70242aef` | 11:00:54.009 | — | 11:01:24.686 | ringing → ended / timeout |

Every listed call had **0 healthy connected milliseconds, 0 charged test microcredits, 0 estimated earning paise, 0 active participant claims and 0 settlement batches**, with its spend hold released. None reached connected state. For the first call, every event was delivered to both recipients.

`participant_ended` is also used by automatic client cleanup after audio failure; it does not independently prove a human pressed End or heard audio. The first intended timeout attempt (`d862a7da…`) was accepted and cannot count as timeout evidence; the later `9da35392…` attempt provides that evidence. Extra calls visible during the session are recorded without attributing them to an unobserved human action.

Safe request reference `0369c555-59cb-460e-9002-f4a8ad4ad016` was not present in retained API logs. The current exception filter returns request references but does not persist them, so this reference alone cannot identify a server-side trace.

## Automated checks and remaining gate

The local repository checks passed, including 10 tooling tests. All 82 Flutter tests and Flutter analysis passed, and the ARM64 debug APK built successfully. Native generated configuration checks passed for default and opted-in debug, profile and release variants. These checks supplement the device observations above; they do not establish audible media.

The backend environment still lacked `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE`. The owner-controlled private configuration location remains to be confirmed. Once configured, repeat the full foreground two-phone audio procedure, including fresh spoken phrases both ways, mute/routing, ending from each participant and matching durable histories. Keep the milestone open until those observations exist. Microphone permission recovery, provider-side cutoff, TalkBack and the broader device matrix remain separate unexecuted checks.
