# Local media connection details

This continuation implements bounded local technical evidence for [FA-032 / #32](https://github.com/agilandeenadhayalan/nightshift/issues/32), following PR84's verified history query. Customer and Listener remain the only app modes. It does not establish real network impairment, audible one-way audio, provider cutoff, staffed support or full physical acceptance for FA-028/031/032.

## What is available

Connection details is an explicit action on the active call and the matching recent-call row. One in-memory receipt covers the current or most recent call, with an absolute 15-minute monotonic deadline from its creation. Reads, callbacks and another join attempt for that same call cannot extend the deadline. A new call replaces it. Owner, origin, session invalidation, logout/401 and disposal clear the receipt; an already mounted dialog hides its old contents. Expired same-call snapshots cannot recreate it.

The view separates authenticated server acceptance observed from an actual SDK channel-join callback, local capture and remote decoding. Acceptance is observed only in `connecting`, `connected` or `reconnecting`, never inferred from an ended/declined invitation. The timestamps describe when this device observed events; they are not the server's acceptance timestamp or billable duration. Successful return from the asynchronous join method alone does not establish SDK join.

The recorder stores fixed milestone slots, bounded counters and seven numeric summaries. Missing or invalid readings remain unavailable. It accepts percentages within 0–100, bitrates within 0–100,000 Kbps and delays within 0–60,000 ms; out-of-range values are discarded rather than clamped into plausible readings. Sample/reconnect counts are bounded at 65,535. These engineering bounds do not impose a media-quality threshold or affect calls.

| Measurement | Meaning |
|---|---|
| Local packet loss | Outgoing audio packet loss, percent |
| Local sent bitrate | Outgoing audio bitrate, Kbps |
| Remote frame loss | Incoming audio frame loss, percent; distinct from packet loss |
| Remote received bitrate | Incoming audio bitrate, Kbps |
| Network transport delay | Sender-to-receiver delay, milliseconds |
| Jitter-buffer delay | Receiver-to-buffer delay, milliseconds; not raw jitter |
| Client/server delay | Client-to-access-server delay, milliseconds |

SDK API signatures were checked against the installed pinned Agora Flutter 6.5.3 source. Current publisher documentation corroborates the [remote audio metric meanings](https://pub.dev/documentation/agora_rtc_engine/latest/agora_rtc_engine/RemoteAudioStats-class.html) and [call delay definition](https://pub.dev/documentation/agora_rtc_engine/latest/agora_rtc_engine/RtcStats-class.html); those web pages currently describe 6.6.4. No SDK upgrade was performed. Metrics, capture/decode callbacks, missing samples, mute or silence do not prove that either participant heard speech and never determine charges.

## Ownership, cleanup and sharing

The optional diagnostics capability captures an immutable per-attempt sink before asynchronous join work. Preview, unrelated peer/connection and stale engine callbacks cannot update the current receipt. A previous attempt can settle only its separately labelled cleanup slot. The original native close future alone reports release completion; caller timeout remains pending and the existing engine-release barrier is unchanged. A later authenticated server End observation can still be recorded after native release, without accepting stale QoS data.

Export uses an explicit field allowlist: random local reference, existing opaque call UUID, typed enums and numeric summaries. It contains no account/origin identifiers, participant names, phone numbers, SDK UID/channel/token, arbitrary SDK messages, conversation audio or private text. Normal in-memory owner checks still compare the app's identity and origin. The random reference is local; support cannot retrieve a receipt by that reference.

The user may explicitly select a symptom, including not hearing the other person or being told they were not heard. It is labelled user-reported and included only in an explicit copy, separately from measurements. There is no automatic diagnosis, clipboard write, persistence, upload, report-text injection or change to the existing Report or block action.

Copy rechecks owner, call and receipt immediately before dispatch, with no intervening asynchronous work. Late success/error feedback is suppressed after ownership or receipt changes. A clipboard write already dispatched by the user's explicit action cannot be revoked by a subsequent logout or expiry; that separate copy does not inherit the in-app deadline. The UI states this distinction.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Receipt model | 8 passed; targeted analyzer clean | `media-diagnostics-focused.log`, `media-diagnostics-analyze.log` |
| Adapter/controller | 30 passed: 17 actual fake-engine callback cases and 13 controller cases | `media-diagnostics-integration-focused.log` |
| Localized UI and real screen integration | 12 passed | `media-diagnostics-ui-final.log` |
| Full Flutter and analyzer | 499 passed, 24 explicit platform/time-zone skips, zero failures; analyzer clean | `media-diagnostics-mobile-tests.log`, `media-diagnostics-mobile-analyze.log` |
| Required `node --test` from `audio/` | 3 passed | `media-diagnostics-audio-reference.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling cases | `media-diagnostics-repo-check.log` |
| Independent source review | No remaining blocking findings | Model, callbacks, controller and UI reviewed |
| Configured private APK | Built and statically verified; not installed | `media-diagnostics-build-record.json` |
| Final-commit CI | Pending | Recorded in the PR after completion |

Tests cover accepted-but-never-joined failures, synthetic loss/delay mapping, missing versus zero readings, intentional mute, foreign/stale callbacks, exact expiry, logout/relogin/origin changes, immutable/redacted bounded exports, original close completion after timeout and late server End. Collection does not invoke the controller's network reconciler or change readiness. The UI checks English/Tamil at 2x text, user-selected symptoms, held copy success/failure during logout, mounted expiry/origin/new-call hiding, and actual Call → End → Recents navigation with only the retained receipt's row eligible.

The model initially reproduced a dropped server-End observation after native release; the narrow fix permits that authenticated terminal observation while rejecting stale media samples. Test-development failures are retained separately: the initial widget harness disposed its controller after Flutter's pending-timer invariant, an adapter fixture created its initial future outside the widget fake-async zone, and a Recents navigation tap ran before hydration/layout settled. Harness ownership, future creation and hit-testable scrolling were corrected; no product timeout or test assertion was relaxed. One analyzer brace warning was also corrected.

## Deployment boundary

Configured private ARM64 APK 6007 (`nightshift-media-diagnostics-6007-arm64.apk`) is 163,341,167 bytes, SHA-256 `9b3eb77c9fac55e6a2a5e9cd8d009f77b6e182490248af290895abc64f57c0fc`. Its package is `com.agilandeenadhayalan.nightshift`, version 0.1.0/6007, using the previously registered debug signer. Flutter's ARM64 split adds 2000 to supplied build number 4007. The build took 40.83 seconds; all 222 source/test/SDK inputs and four ignored private inputs stayed unchanged. The build record is sealed to the final source commit when committed; earlier APK 6003–6006 remain preserved.

All 31 ARM64 native libraries passed ELF and stored-ZIP 16KB alignment, and official Android BuildTools 36 zipalign passed. The alignment record explicitly retains `runtime16kbTested:false`. These static checks do not establish a 16KB device result. This remains a debug compile/target 35 artifact; current Play target/release signing and runtime evidence remain separate. No APK was installed.

No backend/schema/contract/provider configuration changes, new paid service, media recording or diagnostic upload is included. Current physical phone runtime and installed apps are not upgraded by this continuation. Build-specific physical loss/jitter, join-failure and audible one-way tests, wider device/accessibility evidence and approved support/retention processes remain separate gates.
