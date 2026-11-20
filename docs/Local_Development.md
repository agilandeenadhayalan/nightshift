# Windows Flutter and WSL 2 backend

This is the first **test-credit** Android milestone. One install serves Customer and Listener. Keep the fictional-login API private: the local access key authorizes all fictional test identities. Production identity and paid operations are unavailable.

## WSL 2 backend

Use Flutter 3.27.4 / Dart 3.6.2 on Windows, Node 24.13.0 with its bundled npm 11.6.2 in WSL 2, Docker Desktop with Ubuntu WSL integration enabled, and the Android SDK/JDK selected by Flutter. PostgreSQL 17.7 and Redis 7.4.7 are pinned in Compose. Check `flutter doctor -v`; accept SDK licenses yourself if Android tooling prompts.

A Windows checkout at `D:\Learning\NightShift` is `/mnt/d/Learning/NightShift` in Ubuntu. A clone in the Linux filesystem is faster. Do not share one installed `node_modules` between Windows and Linux: Turbo has a native executable for each platform. Run `npm ci` in each separate checkout or use the backend container below, which installs Linux dependencies in its own image. See [monorepo ownership and task commands](Monorepo.md).

From Ubuntu in the repo root:

```bash
bash scripts/bootstrap-wsl-node.sh
export PATH="$HOME/.local/share/nightshift/node-v24.13.0-linux-x64/bin:$PATH"
node --version
bash scripts/setup-local.sh
docker compose --env-file .env -f infra/compose.yaml --profile api up -d --build --wait
docker compose --env-file .env -f infra/compose.yaml ps
curl --fail http://127.0.0.1:3000/v1/health
docker compose --env-file .env -f infra/compose.yaml logs -f api
```

This runs the NestJS process in a Linux container with PostgreSQL/Redis on the same Compose network, migrates the database and seeds fictional accounts idempotently. It avoids Windows/WSL loopback differences. Keep this Ubuntu terminal open while testing; `logs -f` follows safe startup messages and keeps the WSL session alive. Some WSL setups stop a distro after the last client process exits even when systemd Docker was started; a sequence of separate short `wsl.exe` calls can therefore stop the stack. Use another terminal for tests. Run Compose consistently from the same shell and Docker context: a native Ubuntu Docker daemon and Docker Desktop can have separate images, volumes and services. Both roles must use the one API URL from this stack.

For native Node development inside WSL, start only PostgreSQL/Redis in that same WSL Docker context, then run:

```bash
docker compose --env-file .env -f infra/compose.yaml stop api
docker compose --env-file .env -f infra/compose.yaml up -d --wait postgres redis
npm ci
npm run build
npm run db:migrate
npm run db:seed
npm run start:api
```

The bootstrap script installs Node under the WSL user's local data directory and verifies the archive against Node's published SHA256 list. On ARM64, use the printed `linux-arm64` path. Existing `.env` files are preserved; setup generates random local credentials without printing them. The seed contains only fictional adults and an explicitly approved test Listener.

The npm scripts load the ignored root `.env`. PostgreSQL listens only on host loopback 55432; Redis on loopback 56379. The API uses port 3000 (Compose publishes it only to loopback). Docker volumes store local data outside Git. Stop services with `docker compose --env-file .env -f infra/compose.yaml --profile api stop`. Preserve the database password when data already exists: changing `.env` alone does not change PostgreSQL's stored password. Do not delete volumes if you want to retain histories.

## Server-only Agora test configuration

Set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in the ignored root `.env` using your own token-enabled Agora **test** project. Recreate the API with `docker compose --env-file .env -f infra/compose.yaml --profile api up -d --force-recreate api`, or restart the native process. Keep credentials off Git, issues and logs. The certificate stays on NestJS. Flutter obtains short-lived participant/channel tokens after acceptance. Missing configuration returns a recoverable error, never simulated audio success.

Unit/integration tests need no provider credentials. They check control-plane behavior, not audible/visible media, provider connectivity or provider-side cutoff. Voice and video travel directly through Agora, not NestJS.

### Private video testing

`VIDEO_CALLS_ENABLED=false` is the default. To test video, set `VIDEO_CALLS_ENABLED=true` only in the ignored root `.env` for the private local stack, with the server-side Agora test configuration above. Do not change the committed default or copy credentials into Flutter. From that same checkout and WSL Docker context, build/recreate the updated API:

```bash
docker compose --env-file .env -f infra/compose.yaml --profile api up -d --build --wait api
```

Startup applies the additive video migration and seeds the separate rate without deleting audio histories. For native Node, rebuild, run `npm run db:migrate` and `npm run db:seed`, then restart the API. Build and install the updated same APK on both phones using the Windows instructions below. Returning the flag to `false` and recreating/restarting the API hides video and makes recovery end existing video sessions; it is not proof of immediate provider-side cutoff.

Customer selects video and explicitly starts the local camera preview. Android camera permission and checked camera consent are required before sending the invitation; Listener reviews their own preview and consents before accepting. Grant microphone permission for the call when prompted. Opening an invitation or restoring a session does not automatically authorize camera publication. Both participants must be consenting adults using the fictional test accounts.

The proposed engineering video fixture is **120 test coins/minute**, versus **60 for audio**. Both are free through 40 healthy seconds and have a 60-second minimum thereafter, so video needs at least 120 available test coins. These are not approved production prices. Camera off pauses healthy video metering and uses the bounded reconnect timeout. Audio fallback ends the video session; Customer then starts a new audio invitation at its displayed rate. Listener can end video and request an audio redial. The rate never changes within a call.

Follow [Video_Calling.md](Video_Calling.md) for the controls, actual verification evidence and remaining two-phone checklist. Check preview isolation, received video and voice, camera switching/off/on, permissions, backgrounding, either-party End and histories on physical phones. Provider cost reconciliation, public privacy/moderation review and #57/#58 dependencies remain open; enabling this private flag does not authorize a public rollout.

## Windows build and two devices

The root commands `npm run check:mobile` and `npm run build:android` run Flutter dependency setup, contract checks and the native checks/build in order. Install Node 24.13.0/npm 11.6.2 and run `npm ci` at the root first; these commands do not require a local API or database. `build:android` produces the ARM64 variant. The following native Flutter commands are also supported and produce a universal APK:

```powershell
Set-Location D:\Learning\NightShift\apps\mobile
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb devices
```

The app consumes the generated SDK under `packages/contracts/dart`. After an API contract change, run `npm run generate:client` from the root with Java 17+ on PATH or configured through `JAVA_HOME`; `npm run check:client` compares a fresh generation against the committed SDK. The first run downloads the checksum-pinned generator JAR into ignored `artifacts/openapi-generator`; subsequent runs reuse it. No provider credentials are needed for generation.

With the backend healthy, return to the root and run `npm run smoke:client` with the pinned Node and Flutter tools on PATH. The wrapper loads root `.env` privately and runs the Dart SDK against `http://127.0.0.1:3000` (override `API_BASE_URL` if needed). It verifies the HTTP call lifecycle and both histories using test identities without simulating media readiness. It does not replace the two-phone test.

APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`. Both phones install the same APK, with provisional application ID `com.nightshift.app`, and connect to the same backend. Production registration/signing remain owner decisions.

For a smaller APK on ARM64 phones, build `flutter build apk --debug --split-per-abi --target-platform android-arm64` and install `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`. Check the phone with `adb -s DEVICE_SERIAL shell getprop ro.product.cpu.abi`; use the universal APK for other ABIs. The split APK uses version code 2001, so switching back to universal version code 1 requires `adb install -r -d` for an explicit debug downgrade. Both variants remain the same application and modes.

The development sign-in screen accepts an API base URL, fictional account and the local `DEV_ACCESS_KEY` read privately from `.env`. Select `listener` on one phone, `customer` on the other. Enter the key at runtime; never compile it into an APK. `customer2` supports race testing.

For each USB-attached phone:

```powershell
adb -s DEVICE_SERIAL install -r .\build\app\outputs\flutter-apk\app-debug.apk
adb -s DEVICE_SERIAL reverse tcp:3000 tcp:3000
adb -s DEVICE_SERIAL reverse --list
```

Use API URL `http://127.0.0.1:3000`. First verify Windows can reach `http://localhost:3000/v1/health` in WSL. Create and verify the reverse mapping after installation and again after a USB/ADB reconnect: it is temporary, and a missing mapping causes the app's connection-unavailable error even when the backend is healthy. USB reverse transports control traffic; each phone's Wi-Fi/mobile data carries Agora media. This permits one phone on mobile data without publishing the development API.

Without USB, use a private LAN address. WSL mirrored networking can use the Windows LAN IP with a narrowly scoped private-network firewall rule. WSL NAT needs forwarding and firewall configuration and its IP can change. Prefer USB reverse for the first test. Never expose PostgreSQL/Redis to the LAN. A phone's own localhost works only with `adb reverse`.

Only debug builds permit local cleartext HTTP; use HTTPS before an external pilot. Android emulator host forwarding normally uses `http://10.0.2.2:3000`. The prototype is foreground-only: backgrounding ends the current call and marks the Listener offline. Full background incoming calls remain #29. Follow [Two_Phone_Test.md](Two_Phone_Test.md) for manual evidence.

### Vysor and physical-device debugging

Ordinary debug, profile and release builds protect their screens with Android `FLAG_SECURE`, so Vysor shows a black app surface. For a local test using fictional accounts, explicitly opt a debug APK into mirroring:

```powershell
# From apps/mobile, with Flutter on PATH and both USB reverse forwards configured.
$env:ORG_GRADLE_PROJECT_NIGHTSHIFT_ALLOW_DEBUG_SCREEN_CAPTURE = 'true'
try {
    flutter build apk --debug --split-per-abi --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000
} finally {
    Remove-Item Env:ORG_GRADLE_PROJECT_NIGHTSHIFT_ALLOW_DEBUG_SCREEN_CAPTURE
}
```

The uppercase property name is intentional: Flutter's Windows process environment uppercases keys. Only the literal value `true` enables capture, and only the `debug` variant honors it. Profile and release remain protected even when the property is set. CI and builds without the opt-in keep capture protection. The API URL above works on phones only with `adb reverse`; no access key or provider credential is compiled into this APK.

Install this APK on both phones with `adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`, reapply `adb -s DEVICE_SERIAL reverse tcp:3000 tcp:3000`, then launch NightShift. Vysor's mirror can now show the app for interactive QA. Keep test-account keys masked and exclude private notifications or credentials from any evidence. To restore capture protection, rebuild without the environment option and reinstall; removing the environment variable alone does not change an installed APK.

## Isolated test data

From a Node 24 shell:

```bash
npm run check:secrets
node --test scripts/check-secrets.test.mjs
npm run typecheck
npm test
npm run test:audio
```

Integration tests require a separate test database. Create one (omit `createdb` if it exists), then set a private URL using the local password and `nightshift_test` database:

```bash
docker compose --env-file .env -f infra/compose.yaml exec -T postgres createdb -U nightshift nightshift_test
export TEST_DATABASE_URL='postgresql://nightshift:YOUR_LOCAL_PASSWORD@127.0.0.1:55432/nightshift_test'
npm run test:integration
```

Never use production or the development-history database for tests. CI supplies isolated services and fictional credentials. Results actually obtained are recorded in [Verification.md](Verification.md).
