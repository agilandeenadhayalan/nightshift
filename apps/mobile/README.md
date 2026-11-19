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
  production age assurance. MSG91/Firebase phone sign-in is not implemented here.
- Test reports persist to the backend and blocks end/exclude a pair. Staffing,
  escalation, retention, appeals and production safety controls remain launch gates.

Native RTC reference: [Agora Flutter voice quickstart](https://docs.agora.io/en/realtime-media/rtc/voice-quickstart/flutter).
Pinned SDK: [agora_rtc_engine 6.5.3](https://pub.dev/packages/agora_rtc_engine/versions/6.5.3).
