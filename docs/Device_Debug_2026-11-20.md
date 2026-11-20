# Two-phone Android debugging — 20 November 2026

Related issues: [#6](https://github.com/agilandeenadhayalan/nightshift/issues/6), [#26](https://github.com/agilandeenadhayalan/nightshift/issues/26), [#31](https://github.com/agilandeenadhayalan/nightshift/issues/31). **The first foreground, test-credit Android milestone passed on two physical phones:** Listener online, Customer discovery, invitation/acceptance, user-confirmed two-way audio, hangup from each participant and matching histories that survived both-app and API restarts. Broader issue and release gates remain open.

Two physical phones exercised the same app and backend through Vysor and USB forwarding. Test accounts and test credits were used. This record separates observed device behavior, database evidence and unexecuted media checks. The reusable procedure remains in [Two_Phone_Test.md](Two_Phone_Test.md).

## Devices and build

| Item | Observed value |
|---|---|
| Redmi / Customer | Model `23077RABDC`, Android 13, security patch 2023-12-01, ARM64 |
| Motorola Edge 50 Fusion / Listener | Android 16, security patch 2026-07-01, ARM64 |
| App | One application ID, `com.nightshift.app`; version 0.1.0, version code 2001; Customer and Listener only |
| APK for the first two audible calls | The same ARM64 debug APK on both devices, 159,703,503 bytes |
| APK SHA-256 | `deae02bc0cbd6671a95cc96d5ebe66060e85ef8129957c5f3927ab266526e159` |
| APK timestamp | 2026-11-20 10:41:13 UTC / 16:11:13 IST |
| Source provenance | Foundation commit `b17a99930ac511831aef849b4ca05c87e4f6f7bf` plus the native debug-capture changes on `codex/two-phone-debug`; the QA APK was built before that follow-up commit |
| Toolchain | Flutter 3.27.4 / Dart 3.6.2; Agora Flutter package 6.5.3 |
| Backend | Shared NestJS API with PostgreSQL 17.7 and Redis 7.4.7; health check passed |
| API connection | USB `adb reverse` on both phones to local port 3000 |
| Microphone permission | Both phones used Android's one-time microphone grant during this run; denial/recovery was not tested |
| Media networking | Actual Agora audio established after private backend configuration. Both default transports were observed as Wi-Fi at 11:42:24Z, shortly after the second call ended at 11:42:15.484Z; no transport snapshot during active audio or deliberate Wi-Fi/mobile crossover test is claimed |

Provider certificates, tokens and the development access key were not compiled into the APK or committed. Agora configuration was supplied through the ignored backend environment after the initial missing-configuration tests. Device serial numbers and credential values are omitted from this record.

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
| Invitation and acceptance | Passed with actual Agora media after backend configuration; the earlier missing-configuration attempts also produced the actionable setup error and safe termination |
| Missing RTC failure cleanup | Passed: no connected state, no healthy duration or charge, released claims and holds |
| Listener decline | Passed; call `1b03c0a5-4f4d-44e7-80a7-c301126fe448` ended as `declined` without acceptance |
| Customer cancellation | Passed; call `e832d9ba-72c7-4352-9a18-bacf411a9193` ended as `cancelled` without acceptance |
| Unanswered invitation timeout | Passed; call `9da35392-6b7e-47cc-ac63-1f3b70242aef` ended as `timeout` after approximately 30.7 seconds without acceptance |
| Both histories and persistence | Passed for both audible calls: both IDs remained after force-stop/relaunch of both apps without login, then after an API-only restart and fresh history HTTP loads on both phones |
| Stale Listener availability | Passed at the observed sampling interval: after the idle Listener app was force-stopped, Customer discovery showed no available Listener at the first inspection about 65 seconds later; availability returned after Listener relaunch and foreground heartbeat |
| Audible speech in both directions | Passed by the user's actual hearing confirmation on call `3429a1bd-e85f-443d-b40c-d75a1d906afe`; speaker speech was audible both ways |
| Either participant ends an audible call | Customer End on the first call and Listener End on the second both ended the peer's call. Both records appeared in both histories; post-end Android AppOps confirmed microphone operations were no longer running before any process stop |
| Mute and earpiece routing | User confirmed each mute control silenced its outgoing direction, then confirmed clear audio through both earpieces |
| Microphone denial and headset routing | Not run |
| Media reconnect | First call recorded 14 transitions to reconnecting, including the last transition before hangup; 13 returned to connected. The second call recorded two reconnect transitions. The healthy-duration counter did not advance across the recorded reconnect/resume pairs. Root cause and deliberate network-switch recovery remain unverified |
| Provider cutoff and different-network tests | Not run |
| Physical TalkBack and large-text checks | Not run |

For the stale-availability check, the Motorola Listener app was force-stopped with no active call at `11:02:41.097Z`. The Redmi's first inspection at `11:03:45.915Z` showed no available Listener. The configured Redis TTL is 45 seconds, but this run measured only disappearance **by that approximately 65-second inspection**, not the exact expiry instant. The Listener was relaunched around `11:03:53Z`; its signed-in history returned without another login, and Customer discovery showed the Listener available again by the next settled inspection at `11:04:15Z`. Call `e832d9ba-72c7-4352-9a18-bacf411a9193` was confirmed in both histories after the app/API restart checks.

## Audible call evidence

Call `3429a1bd-e85f-443d-b40c-d75a1d906afe` was accepted at `11:34:05.010Z` and first reached the server's connected state at `11:34:09.648Z`: **4.638 seconds after acceptance**, measured separately from ringing. The user confirmed two-way speaker speech, silence in each direction when that participant muted, and clear audio from both earpieces. Customer End was exercised through the app, and both phones displayed the same completed call ID in history.

The first call ended at `11:40:29.749Z` with reason `participant_ended`. The server recorded **309.804 healthy seconds**, charged **18,600,000 test microcredits = 310 test coins**, and recorded **4,303 test paise = ₹43.03 in non-payable illustrative earnings**. Its credit settlement and earnings illustration each produced one balanced journal batch. Both readiness flags were false after end, its hold was released, and no active participant claim remained. All 31 state events were delivered to both recipients. Post-end Android AppOps showed finite past recording durations and neither microphone operation running.

The call spent 384.739 seconds between acceptance and end; this wall duration is distinct from healthy metered time. It had repeated reconnect transitions, so continuous stable media is not claimed.

On the second call, `6e0d7ee0-30ae-485a-82b5-9d21c052c4d3`, the user again confirmed clear speech in both directions through the earpieces. End was tapped on the Motorola Listener: its Earnings screen returned and the Redmi Customer returned to Discover. Opening Recents confirmed both new call IDs on both phones. Android AppOps showed both microphones running at `11:42:00Z`, then neither running at `11:42:46Z`, before any process stop; recorded completed operation durations were 56.899 seconds on Redmi and 59.445 seconds on Motorola.

The second call was accepted at `11:41:14.888Z`, first reached server connected at `11:41:19.745Z` (**4.857 seconds after acceptance**), and ended at `11:42:15.484Z` with reason `participant_ended`. It recorded **49.820 healthy seconds**, **3,600,000 test microcredits = 60 test coins**, and **692 test paise = ₹6.92 in non-payable illustrative earnings**. Its credit settlement and earnings illustration each produced one balanced journal batch. Both readiness flags were false, its hold was released and its participant claims were gone. All seven state events were delivered to both recipients. The final audit found no active call, active participant claim or unreleased hold anywhere in the local test database.

Both apps were then force-stopped and relaunched without signing in again. Redmi Recents and Motorola Earnings each showed both `3429a1bd-e85f-443d-b40c-d75a1d906afe` and `6e0d7ee0-30ae-485a-82b5-9d21c052c4d3`. The API alone was restarted and its health check passed. Navigating away from and back to history triggered fresh history HTTP requests on both phones; both IDs remained present. Customer available balance was **9,630 test coins = 10,000 − 310 − 60**. Listener history showed **₹49.95 in non-payable illustrative earnings = ₹43.03 + ₹6.92**.

This completes the requested first foreground test-credit path, including ending from either participant and durable histories. The 4.638s and 4.857s timings measure server-observed readiness, not raw SDK join callback latency. The audible results are the user's physical confirmations. Hangup evidence covers the cooperating app's teardown, peer screen exit and stopped native capture; it does not establish provider enforcement against a modified client.

After these checks, the Listener was set offline and both phones' temporary stay-awake-on-USB settings were restored to their original values. The local backend remained available, with database volumes preserved.

## Earlier failure and recovery evidence

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

## Automated checks and remaining release gates

A subsequent controller regression reproduced heartbeat starvation independently of Agora: hold the snapshot HTTP response for six virtual seconds while the audio adapter remains ready, and the original implementation sends zero media health reports. The server's readiness lease expires after five seconds. Media reporting now uses its own two-second timer and no longer waits for snapshot completion. Slow media requests also cannot block snapshots from observing a terminal call. Current-call join, single-flight, session, hangup and disposal guards remain in place. This fixes the reproduced scheduling defect; the original physical runs did not capture enough request/SDK telemetry to attribute every reconnect transition to it.

The initial QA build passed 82 Flutter tests and analysis. The heartbeat follow-up passed **93 Flutter tests**, including 11 focused regression cases, plus Flutter analysis, all three `audio/` reference tests and the repository guards/10 tooling tests. Its ARM64 debug APK built successfully. Native generated configuration checks previously passed for default and opted-in debug, profile and release variants, which this follow-up does not change. These checks supplement the device observations above; they do not establish audible media.

The follow-up QA APK was built at `11:54:02Z`, is 159,730,708 bytes, and has SHA-256 `2cc83d1286968e8bb77f39ab4ad4a642d9d08bb4ba21230c6d48a3ae9244ca38`. It was installed on both phones without clearing app data; both signed-in sessions and the two prior histories remained. The first two calls above used the original APK hash in the device table, not this follow-up binary.

Comparison call `6be26a93-747f-4ae2-bb08-a14780f631c2` used the follow-up APK. It was accepted at `11:55:43.446Z`, first reached server connected at `11:55:49.575Z` (6.129s), and ended from the Customer at `11:58:35.901Z`. The server recorded 117.977 healthy seconds, 118 test coins and ₹16.39 non-payable illustrative earnings. Its two journal batches were unique and balanced, all 21 events were delivered to both users, and both histories showed the new ID. The final database audit found zero active calls, claims and unreleased holds. Both microphones were running and both default transports were Wi-Fi at `11:56:05Z`, during this call; both microphone operations were inactive at `11:58:57Z`, before cleanup. The Listener's one-time microphone grant was renewed through Android's permission dialog before acceptance.

**The follow-up APK's audible check remains unconfirmed:** the tester has not yet answered the fresh listening question for this third call. Its connected states, microphone operations and histories are not substituted for an audible result. It also recorded eight recovered reconnect intervals totaling 33.235 seconds, plus a 0.825-second end-adjacent interval. Several false readiness reports were fresh (270–1,172ms old), so missed heartbeats alone cannot explain these episodes. The remaining investigation needs the specific SDK connection, capture and remote-audio readiness reasons, correlated with control-request timing; those reasons were not recorded in this run. The first two calls' user-confirmed audio results remain valid for the original APK.

The missing Agora configuration was resolved through the ignored backend environment. The main foreground test-credit path passed; the repeated reconnect transitions still need diagnosis. Microphone denial/recovery, wired-headset/Bluetooth routing, deliberate Wi-Fi/mobile crossover, provider-side cutoff, TalkBack and the broader device matrix remain unexecuted release checks. Background/locked-screen calling is still unsupported by this foreground milestone. Test-credit audio does not establish readiness for paid calls or close the broader issue acceptance criteria.
