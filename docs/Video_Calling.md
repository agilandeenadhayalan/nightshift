# Private test video calling — #57

The owner requested video implementation on 20 November 2026. This extends the same Flutter application, Customer/Listener modes, NestJS backend and PostgreSQL call/credit model. It does not clear the audio stability, paid cutoff or launch dependencies of [#57](https://github.com/agilandeenadhayalan/nightshift/issues/57), or the public privacy/safety review in [#58](https://github.com/agilandeenadhayalan/nightshift/issues/58).

## Design

- Video is separately selected from discovery or explicitly accepted from a video invitation. An authenticated public RTC configuration endpoint enables local camera preview; it never returns a certificate or token. Preview does not join a channel or capture microphone audio.
- Each participant reviews their local preview and gives explicit camera consent. The app closes preview before sending the invitation/acceptance. Server consent is recorded with the call; client permission to join is held only in memory for that call. Restoring a signed-in app cannot silently restart its camera.
- The accepted video session renders the remote participant and local preview, with microphone mute, speaker, camera off/on, camera switching, End and report/block controls. Ending, denial, cancellation, invitation expiry, background, logout and disposal release camera resources. Turning camera off stops capture, not merely publication.
- The server freezes media type and rate when creating the call. The proposed development fixture is `test-video-v1`, 120 test coins/minute, versus 60 for `test-audio-v1`. Both preserve the 40-second free threshold and 60-second minimum thereafter. Video uses twice the audio microcredits/second; its hold and affordable duration use that selected rate. Listener estimates stay non-payable at the existing fixture rate. These are engineering test fixtures, not approved launch prices.
- Video healthy-time reports require both audio readiness and actual local capture/remote video readiness. Missing media pauses test metering and uses the existing bounded reconnect timeout. Claims, terminal states, idempotency, histories and balanced settlements are shared with audio.
- Video starts at 640×360/15fps, adapts down to 320×180/10fps on poor network quality, and discloses reduced quality. The SDK's adaptive orientation/balanced degradation is enabled. Adaptation never changes the frozen rate.
- Audio fallback is explicit: end the video session and offer a new audio invitation at its disclosed rate. The Customer can redial; the Listener can end and request an audio redial. There is no silent in-place repricing.
- `VIDEO_CALLS_ENABLED` is off by default. Existing production-startup refusal, fictional identities, test-credit gates and screen-capture protection remain. No recording or biometric identity claims are added. Provider-side enforcement against a modified client is not established by cooperative app teardown.

## Verification and owner decisions

Automated checks must cover old audio clients/history, consent/flag rejection, video tariff boundaries/holds, mixed-media claim contention, missing video readiness, reconnect gaps, unique balanced settlement, camera denial/cancellation/background/end, stale asynchronous preview/join work and visible price/fallback copy. Regenerate and verify the Dart client; run Flutter checks, backend integration tests, browser-reference tests and the Android debug build.

Physical verification must separately record local preview without remote transmission, both received video feeds and voice, camera switching/off/on, mute, either-side End, revoked permissions, backgrounding, network degradation and matching histories. No physical pass may be inferred from mocked RTC or a successful APK build.

Production video price, listener pay, spend cap, supported quality/device matrix, provider usage reconciliation and staffed privacy/moderation response require owner approval. Compare provider-reported participant-minutes with actual join/leave intervals and server healthy duration; accepted-to-ended wall time is only a diagnostic bound and is not a provider invoice. Public video remains disabled until those dependencies pass.

## Implementation evidence — 20 November 2026

Backend/domain review and mobile camera/lifecycle review covered the combined implementation. Review and tests found and corrected stale joins tearing down a newer call, an expired preview dismissing its replacement screen, renderer reuse across SDK engines, and optional video fields breaking legacy audio request serialization. The checked-in generator template owns the serialization fix; generated Dart files are reproducible.

The backend migration was applied to the private local Docker stack. A read-only audit before and after verified all **16 existing calls, 97 call events and 10 journal batches**, with an identical fingerprint of call timestamps, durations, amounts and rate snapshots. There were no active calls, claims or held funds during the upgrade. Startup seeded `test-video-v1`, the API health check passed, and video was enabled only in the owner's ignored local environment.

All **281 automated tests passed**:

| Check | Result |
|---|---|
| Flutter app, controller, adapter, generated contract and UI tests | 144 passed; `flutter analyze` clean |
| API units and provider-boundary tests | 40 passed |
| Shared billing domain | 7 passed |
| Isolated PostgreSQL/Redis integration, schema and HTTP tests | 67 passed |
| Browser reference (`node --test` from `audio/`) | 3 passed |
| Economics | 10 passed |
| Monorepo/tooling | 10 passed |

Repository secret/contract/boundary guards, TypeScript typecheck/build and the pinned generated-client check passed. The generator reproduces all 52 Dart SDK files. Separate real HTTP journeys through the generated Dart SDK passed for audio and video against a disposable schema in a dedicated test database. They exercised configuration, discovery, mutual video consent, immutable rates, invitation replay, both participants reporting **not ready**, end, both histories and claim cleanup; no RTC token or healthy media was fabricated.

The ARM64 debug APK built and was installed successfully on Redmi 23077RABDC (Android 13) and Motorola Edge 50 Fusion (Android 16), retaining the existing app sessions and USB API forwarding. Artifact: `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, 180,336,607 bytes, SHA-256 `072079b4a8a9a4fb6c6108301c6cf9f5ccf228984b806be860ad584138414d78`. This local build explicitly permits Vysor mirroring; CI uses the protected default. No provider credential or development access key is compiled into it.

Automated coverage uses fake media engines or synthetic readiness. It verifies software behavior, not actual camera frames, audible media, provider invoices or hostile-client cutoff. Physical results are recorded separately below.

## Physical result — 20 November 2026

The user activated preview/permissions/consent on the two installed phones, then confirmed live video, clear voice in both directions and camera switching on both devices during the connected video session. The correlated call was `e4a7e4dd-a8dd-4e18-b704-c6a036cf96be`, created at 18:24:53 IST and accepted at 18:25:08 IST. The first server-connected transition followed acceptance by 4.096 seconds.

Turning the Redmi camera off removed its running Android camera operation and showed the camera-off/billing-paused message. The server entered reconnecting with 84,944 healthy milliseconds. The Listener's end request completed at 18:26:58 IST, before camera re-enable could be exercised; healthy time remained 84,944 ms. Settlement produced **170 test coins** and **₹11.80 non-payable illustrative earnings**. There was one balanced customer settlement and one balanced earnings illustration, no remaining participant claims, and the hold was released.

Both phones' histories were visually inspected: each shows Video call, the same full call ID, 1:24 displayed healthy time and 170 test coins; the Listener also shows ₹11.80. Android camera and microphone operations were no longer running on either phone after end. The Listener was left offline. No live camera images were captured for evidence.

Four reconnect episodes occurred before the deliberate camera-off test. Their cause is not established; they must not be reported as deliberate bandwidth tests or as a stability fix. The broader audio/media readiness investigation remains open. Camera re-enable, Customer-initiated video hangup, permission denial/revocation, explicit background interruption, physical audio fallback, deliberate network degradation and provider participant-minute reconciliation still require dedicated checks. These limits keep #57/#58 and their launch dependencies open.

## Two-phone video procedure

Use the same APK on both phones, the existing fictional accounts, USB API forwarding and each phone's own network for Agora. Keep both apps in the foreground. Start with the Listener online and both participants ready before sending the short-lived invitation.

1. Customer selects **Video call**, then **Preview camera**, grants camera permission and checks the local preview. Before confirmation, verify the microphone indicator stays off and nothing appears on the Listener's phone. Cancel once and verify the camera indicator stops.
2. Repeat preview, explicitly check camera/microphone consent and start the video invitation. Listener selects the preview/accept flow, grants camera permission, reviews the preview, checks consent and accepts. Neither tester's consent is supplied by automation.
3. Confirm both received video feeds and speech. Switch front/back cameras, mute/unmute both microphones and check speaker controls. Turn a camera off and verify the physical capture indicator stops and healthy-time charging pauses; turn it on before the bounded reconnect timeout.
4. End from Customer, then make another call and end from Listener. Verify both capture indicators stop, both histories identify **Video**, the same call ID and test charge appear, and no active claim/hold remains.
5. Verify denied/revoked camera recovery, Home/background capture shutdown, a fresh preview after restoration and degraded-network quality messaging. Separately confirm **End video and use audio** ends the old session and presents a new 60-test-coin/minute invitation with a new call ID.

Use benign scenes and consenting adults. NightShift does not record the call; another participant can still capture it externally. Default APKs retain screen-capture protection; the explicitly opted-in Vysor debug build permits mirroring for local QA. Capture deterrence is not recording prevention. Only the physical results recorded above have passed; provider reconciliation and the remaining device cases stay open.
