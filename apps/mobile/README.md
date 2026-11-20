# NightShift Android

One Flutter project, one application ID (`com.nightshift.app`), exactly two modes:
Customer and Listener. Staff review and financial operations remain outside this app.
This is an adult, fictional-account, test-credit development milestone. The package
name is provisional pending owner approval before Play registration.

## Windows development

Use Flutter **3.27.4**, Dart **3.6.2**, Android SDK platform **35**, NDK
**27.0.12077973**, and Java **17 or 21**. Gradle **8.10.2**, Android Gradle Plugin
**8.7.3**, Kotlin **2.0.21**, and Dart package versions are pinned. Run from PowerShell:

```powershell
cd D:\Learning\NightShift\apps\mobile
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Replace the example IP with the reachable backend address. The login screen also
lets you change it. `10.0.2.2:3000` is the default for the Android emulator; a real
phone needs the computer's LAN IP, or an HTTPS development endpoint when testing
mobile data. Follow [the WSL 2 / Windows runbook](../../docs/Local_Development.md)
for backend startup and network forwarding. For phones connected over USB, use
`adb -s DEVICE_SERIAL reverse tcp:3000 tcp:3000` and enter `http://127.0.0.1:3000`;
Agora can still use mobile data while the control API remains private. A missing SDK license requires the
owner to review and accept it; do not blindly accept license prompts.

The universal APK is `build/app/outputs/flutter-apk/app-debug.apk`; bundled debug
RTC binaries make it large. For typical modern Android phones, build the smaller
ARM64 APK with:

```powershell
flutter build apk --debug --split-per-abi --target-platform android-arm64
```

Use `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` on devices whose
`adb -s DEVICE_SERIAL shell getprop ro.product.cpu.abi` reports `arm64-v8a`.
Use the universal APK for other supported ABIs. Both modes use the same APK and
`com.nightshift.app` package; ABI outputs do not create additional applications.
There are no role-specific flavors or application ID suffixes.
Cleartext HTTP is enabled only in the debug manifest. Release UI and controller
startup are disabled; release builds do not restore debug credentials or make
background API/media connections. Production signing is not configured.

## Two devices

1. Seed the backend's fictional users. Configure its `DEV_ACCESS_KEY` and Agora
   credentials outside Git. Never put the Agora certificate or development key in
   `--dart-define`; the app requests short-lived channel/UID-scoped tokens.
2. On phone B choose `Listener · approved test B`, enter the local development key,
   confirm adult test consent, and sign in. Tap **Go online**.
3. On phone A choose `Customer · test A` with the same backend and development key.
   Select Tamil or English, refresh Discover, and choose **Call**. Review the
   explicit test tariff and permit microphone access.
4. On B tap **Accept**, permit the microphone, and speak in both directions.
   Ringing/connecting are distinct from SDK-confirmed audio readiness.
5. End on either phone. Both should show the same call ID and server totals in
   Recents / Earnings. Report and block are available in-call and in history.

See [the complete two-phone checklist](../../docs/Two_Phone_Test.md). The automated
tests use a fake RTC boundary to check controller behavior; they do **not** prove
audible media, device routing, vendor cutoff, or background notification delivery.

## Implemented behavior and limits

- Riverpod owns session/call state; GoRouter redirects restored active sessions to
  the call screen. Customer navigation is Discover, Recents, Profile; Listener
  navigation is Availability, Earnings, Profile. Only server-approved listeners
  can switch modes or go online; mode switching is unavailable during a call.
- Tamil/English app strings and conversation selection are separate. History uses
  server IDs, cursor pagination, local date grouping, and server-calculated totals.
- Snapshot reconciliation runs every two seconds; foreground presence every
  fifteen seconds. The database and server are authoritative. This version uses
  polling, with Socket.IO event consumption and push delivery still pending.
- Agora 6.5.3 captures microphone audio only. Both local capture and remote decoded
  audio must be healthy before the client sends readiness. It sends no duration,
  price, balance or earnings. No recording is requested. Mute and speaker controls
  use the native SDK. Provider credentials never reside in the app.
- End immediately releases native media, even when HTTP is offline. A persisted
  local end intent prevents accidental rejoin while the server reconciles. Stale
  transition versions reload and retry; old snapshots cannot resurrect a call.
- This milestone is **foreground only**: backgrounding or locking ends the call
  and withdraws availability. Incoming FCM notifications, an ongoing-call service,
  lock-screen acceptance and interruption/resume device evidence remain #29.
- Backend control loss stops native media after the bounded request deadline.
  This is not proof of provider-enforced paid-media cutoff. Use test credits only.
- Android screenshot protection is requested with `FLAG_SECURE`; external capture
  and native-surface behavior still require physical-device verification.
- Sessions are stored with Android encrypted secure storage; the developer access
  key is never persisted. The login checkbox is a development consent gate, not
  production age assurance. Phone sign-in uses Firebase Phone Authentication
  for Indian numbers, followed by backend ID-token verification and admission.
- Test reports persist to the backend and blocks end/exclude a pair. Staffing,
  escalation, retention, appeals and production safety controls remain launch gates.

Native RTC reference: [Agora Flutter voice quickstart](https://docs.agora.io/en/realtime-media/rtc/voice-quickstart/flutter).
Pinned SDK: [agora_rtc_engine 6.5.3](https://pub.dev/packages/agora_rtc_engine/versions/6.5.3).

## Private phone sign-in and onboarding

The phone entry point stays unavailable without explicitly configured
`FIREBASE_WEB_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`
and `FIREBASE_PROJECT_ID=nightshift-c3e1a`. Configure `PHONE_API_BASE_URL` at build time for the
intended backend, and `PHONE_AUTH_CONSENT_VERSION` to match its approved notice
version (development default `phone-signin-v1`). The Firebase Web API key is a
public project identifier; never substitute a service-account credential. No
provider credentials or project files are checked into the Android app.

Phone sign-in uses a fixed build origin, independently of the fictional-login
address field. HTTPS is required except explicit debug loopback/emulator hosts
(`localhost`, `127.0.0.1`, `::1`, `10.0.2.2`). For USB testing, build with
`PHONE_API_BASE_URL=http://127.0.0.1:3000` and use the documented `adb reverse`
procedure. General LAN HTTP is rejected for phone credentials. All API and
Firebase requests refuse redirects.

The official [Firebase Flutter phone SDK](https://firebase.google.com/docs/auth/flutter/phone-auth)
handles SMS and Android app verification. Pinned `firebase_auth 6.5.7` and
`firebase_core 4.13.0` preserve Flutter 3.27.4/Dart 3.6.2 and Android minSdk 23.
Before invoking the SDK, the app obtains a five-minute backend admission tied to
the phone, device and consent. An admission does not mean an SMS was sent, and
server admission limits are not a Firebase billing cap. Automatic completion is
accepted only for the active consented attempt; the 60-second auto-retrieval
timeout still permits manual code entry. Resending requires an explicit action.

[Firebase's native authentication persistence](https://firebase.google.com/docs/auth/flutter/start#persisting_authentication_state)
is SDK-managed and cannot be disabled through Flutter's web persistence setting.
Native refresh tokens are not exported by FlutterFire. The app separately stores
the accepted provider UID, backend origin and backend ID token using Android
secure storage; an SDK session without that acceptance marker is signed out.
SDK-owned state is not described as encrypted by the app. Android backup and
device-transfer rules exclude application files, databases and preferences,
including the Firebase SDK's private authentication state.

Renewal is coalesced using `getIdTokenResult(true)` before expiry and exchanges
the resulting ID token with the backend. Owner and origin checks run after
renewal and before protected requests dispatch. Old request failures cannot erase
a renewed session. Logout signs out the SDK and clears the accepted-session
marker and token; a late credential completion is discarded before another
sign-in can run. No failed mutation is automatically replayed. SMS codes and
verification identifiers remain ephemeral, and Firebase UID is never used as
the public application user ID. The former REST custom-token adapter remains
only for isolated legacy fixtures; the app's default phone entry uses Firebase SMS.

Android setup requires SHA-256 for Play Integrity and SHA-1 for the reCAPTCHA
fallback used by sideloaded debug APKs, plus the correct API-key/auth-domain
configuration. Enable the phone provider and the India SMS region policy in the
explicit project before live testing. These are external configuration checks;
automated tests never send SMS or disable app verification.

New phone identities are routed to private adult onboarding. The backend owns the
18+ decision and immutable birth-date rule. Public APIs use an assigned alias
until the submitted nickname is reviewed. Interface language and speaking
languages are separate controlled selections. Onboarding uses the development
notice `adult-onboarding-v1`; approval of production notices, live Indian SIM
delivery, actual Firebase project permissions and physical-device accessibility
remain external evidence. Neither phone verification nor self-declared age grants
Listener approval, credits, payments or production access.

Privacy is available from Profile and restricted onboarding. Deletion requires
an explicit second confirmation and server-verified recent authentication, not
just an ID-token refresh. Before submission the app securely persists a random
32-byte recovery capability tied to the configured backend and local account.
It survives logout and must not be overwritten by a different account. A lost
response is resolved through the public, tokenless status endpoint; deletion is
never automatically resubmitted. The capability is never displayed or put in a
URL. Receipt copy distinguishes removed profile data from retained financial,
dispute and age-safety evidence; it does not promise full erasure or a date.

Listener applications are available from Profile. Drafts, review status and
voice consent stay private to the current account. Choosing an existing sample
uses Android's [system document picker](https://developer.android.com/training/data-storage/shared/documents-files)
through a [Flutter platform channel](https://docs.flutter.dev/platform-integration/platform-channels);
no recording starts automatically. The Android adapter reads a bounded stream
into memory without making an app-cache copy or persisting a URI permission.
WAV samples are limited to 2 MiB and
2–60 seconds, PCM16 mono/stereo at 8–48 kHz with only fmt/data chunks. Both client
and server validate the format. The client computes SHA-256 using pinned
[crypto 3.0.6](https://pub.dev/packages/crypto/versions/3.0.6), then sends raw WAV
through the generated SDK with an owner bearer and a five-minute upload capability.
The picker never stores or sends the source filename or path. Sample bytes and
upload capabilities remain in memory and are discarded when the account changes.

Private application requests require HTTPS or debug loopback/emulator transport;
they recheck account ownership and origin after token renewal. Interrupted create,
upload and submit requests require checking saved status before an explicit retry.
Stable request keys prevent duplicate operations; expired upload permission and
a later request for more information begin separate retry cycles. Withdrawing
consent removes the review sample, including after an approval/rejection, while
preserving that staff decision. Samples are never presented as proof of age,
gender or identity. Applications are free and carry no promise of approval,
review timing or earnings. Native file-provider behavior and accessibility still
need physical-device evidence; tests and smoke journeys use synthetic audio only.
