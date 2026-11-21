# Android audio invitation verification

This record covers the incoming-invitation subset of [FA-029 / #29](https://github.com/agilandeenadhayalan/nightshift/issues/29), built on the bounded matching implementation in PR80. It does not complete ongoing background calls or the required physical-device matrix.

## Behavior

An approved, available Listener can explicitly enable generic incoming audio notifications for up to 30 minutes, bounded by the authenticated session. Android 8 (API26) or later, notification permission, an enabled channel and configured Firebase options are required. The app first prepares a server registration, durably installs its native binding, then activates it. Refresh and recovery reads do not renew consent.

Notification taps open the visible app and fetch the current call with the current account. The normal Answer action remains explicit. A push cannot accept a call, start capture, issue RTC credentials, change the ringing deadline or authorize a charge. Video requires a foreground presence lease. Accepted audio and video calls retain foreground-only teardown when the app backgrounds; this change adds no foreground service or ongoing-media claim.

FA-017's existing foreground presence lease can remain valid for up to 45 seconds after the last heartbeat. Backgrounding with an active invitation opt-in stops heartbeats and preserves availability intent, so a stale video invitation can be offered during that residual interval. The background client cannot accept it or report ready media. Immediate foreground withdrawal would require an additional versioned protocol that also rejects delayed heartbeats.

## Authority, privacy and delivery

The four registration routes bind to the current canonical phone identity, device and authentication lineage. Same-device refresh preserves a binding; fresh sign-in, logout, takeover, deletion and restrictions invalidate it. Mutation receipts use exact versions and fresh authorization. The FCM target is write-only, encrypted with authenticated AES-256-GCM, and indexed with a separate keyed digest. Raw targets and credentials do not appear in contracts, logs or generic command records.

Migration017 creates six tables for target claims, registrations, commands, delivery jobs, per-call send budgets and attempts. Push jobs are independent of socket outbox consumption. Each call and message kind has at most two admitted sends across token generations, with a durable minimum ten-second retry floor and the original invitation deadline. Provider acceptance is not device receipt; an uncertain result remains uncertain.

The sender validates call state, event version, recipient authority, registration, deadline and exact leased attempt before admission and again after credential acquisition. It does not hold database locks across the Google request. As with any external send, cancellation after the final database check cannot recall a request already in flight. Native expiry and binding checks plus the authenticated Open fetch remain necessary.

Native data is a strict nine-field schema with no caller name, phone, message text, balance, URL, auth token or RTC credential. Generic English/Tamil copy is bundled. Immutable explicit PendingIntents, version checks, durable terminal tombstones, conservative server-time anchoring and OS notification timeout reject stale hints. Clock uncertainty, reboot mismatch and persistence failure disable the binding. Logout clears memory and notices before durable invalidation/network cleanup. Token operations retain their process-wide admission slot until the actual SDK task settles, including after a UI timeout. Bounded server expiry cleanup erases expired prepared/active ciphertext even when sending is disabled or no transport is configured.

The dedicated credential adapter accepts only the expected project sender identity and reviewed private credential shapes. OAuth/IAM and FCM endpoints are fixed; redirects and implicit retries are disabled. Responses and operation time are bounded. Four actual network operations may be in flight; timeout does not release capacity while an underlying operation remains unsettled. No ambient Firebase Admin credential is reused for sending.

## Verification

| Check | Actual result | Ignored local evidence |
|---|---|---|
| Final full isolated PostgreSQL/Redis/HTTP regression | 384 passed, including all 48 push cases; zero failures/skips/cancellations; 289.888 seconds | `push-full-integration-final.log` |
| Top-level typecheck/build/test | Passed; 74 API units/provider checks, 7 domain tests, 3 audio reference tests | `push-typecheck-final.log`, `push-build-final.log`, `push-workspace-test-final.log` |
| Flutter | 365 passed; final affected tests 36 passed; analyzer clean | `invitations-mobile-tests.log`, `invitations-mobile-analyze.log` |
| Native invitation policy/shared fixtures | 29 checks passed; Kotlin compiled in the configured APK build | `invitations-native-policy-final.log` and split build record |
| Generated Dart client | 90 generated files verified without drift | `invitations-client-check.log` |
| Repository/contracts/boundaries/secret guard | Passed, including 11 tooling tests | `invitations-root-repo.log` |
| Economics and native artifact checker | 19 passed: 10 economics and 9 malformed ELF/ZIP fixtures | `invitations-root-python.log` |
| Dependency audit | Zero reported vulnerabilities | `invitations-dependency-audit.log` |

The independent push suites first reproduced missing behavior against the stub, then demonstrated five additional timing failures: premature retry after lease reclamation; logout, cancellation and registration expiry during credential acquisition; and background registration expiry during reservation. The fixes passed all five. A separate disabled-sender regression reproduced retained expired ciphertext before the cleanup fix. Transport tests also reproduced stale callback dispatch and extra/private payload fields before fixes. These use real isolated PostgreSQL/Redis/HTTP plus synthetic provider requests; no FCM or SMS was sent.

The first full backend run passed 382 of 383 tests. Its one failure was the older discovery test's exact field allowlist, which omitted the newly contracted `reachability` field. The expectation now includes that field and verifies its value. The earlier Flutter run passed 360 with four cascading video-fixture failures caused by missing foreground reachability; the fixture was corrected before the final 365-pass run. Failed logs are preserved separately.

The configured private APK is `nightshift-invitations-6003-arm64.apk`, 163,270,523 bytes, SHA-256 `3bd14c3c6405190f38c4e452cf58ab98cd62ee859ecce34294251c6150b536d8`. Its actual version is 0.1.0 / 6003: Flutter applies the ARM64 split offset to build-number4003. The final build took 22.2 seconds and preserved all 208 source and four ignored configuration/CA input hashes. `invitations-arm64-split-build-record.json` records those inputs and the packaged manifest/signature checks. An earlier unsplit artifact contained four native ABIs and is retained as earlier evidence; it is not the ARM64-only deliverable.

All 31 ARM64 libraries passed ELF load and stored-ZIP 16KB alignment checks; Android BuildTools36 `zipalign -c -P 16 -v 4` independently passed. The checker explicitly records `runtime16kbTested:false`. The APK retains target/compile API35, so the separate current Play target upgrade remains outstanding. Existing Agora manifest declarations include a media-projection service/foreground-service permissions; this slice adds no ongoing-call service implementation. Neither artifact was installed by this continuation.

## Firebase and Android package change

The owner approved permanent Android application ID `com.agilandeenadhayalan.nightshift`. The matching Firebase Android app `1:844582070891:android:e673f4c812adeb21a61f2e` was created in `nightshift-c3e1a`. The existing local debug certificate was independently inspected with Android apksigner, registered on the new Firebase app and read back. The previous `com.nightshift.app` registration remains active for installed build4002. Source namespaces remain unchanged; the Android application ID is the new package.

New public SDK options and the private local build defines remain in ignored files. A new package is a separate Android installation and requires fresh phone authentication/device validation. Debug certificate registration does not establish release-signing or Play App Signing configuration. After the owner explicitly confirmed the three prepared declarations, NightShift was created in Play as a free app with English (United States) as the default language. The actual dashboard requires a closed-test release with at least 12 testers opted in continuously for 14 days before applying for production access. No release was uploaded or published.

## Configuration and rollout

`FCM_SEND_ENABLED` defaults to false. Enabling it requires native Firebase phone identity, the same project in `FCM_PROJECT_ID`, an absolute private `FCM_SENDER_CREDENTIALS_FILE`, a separate 64-character lowercase hexadecimal `FCM_TOKEN_ENCRYPTION_KEY`, and a separate 32–256-character `FCM_TOKEN_DIGEST_KEY`. The expected sender is `nightshift-push-sender@<project>.iam.gserviceaccount.com`. Credential parsing and synthetic tests do not establish actual IAM permission. Invalid enabled configuration fails startup; production startup remains disabled.

The existing private phone runtime remains on migrations001–014. This continuation has not applied015–017 there, installed the new APK, enabled the FCM sender, granted staff access or approved a Listener. A coordinated upgrade needs an exact reviewed build, backup/restore verification, quiescent calls/workers and compatible API/staff/client versions. Disable sending before retiring a deployment. Keep encryption/digest material stable while registrations exist; losing or replacing it requires deliberate invalidation and fresh client registration. Do not roll back by dropping tables containing live delivery evidence.

The remaining acceptance work is actual provider delivery and foreground Answer on an approved Listener; locked screen, denied/channel-disabled notifications, battery restrictions, offline/API-unreachable behavior, rotation, logout/account switching and expired hints on selected phones; ongoing audio engine/focus/teardown; new-package phone sign-in; and release target/API, signing and 16KB runtime evidence. A statically aligned APK does not establish operation on a 16KB device. FCM receipt does not establish that the USB-forwarded local control API is reachable. No issue closure or public release is implied by this subset.
