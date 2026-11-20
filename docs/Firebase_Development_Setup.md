# NightShift Firebase development setup

Recorded 20 November 2026. The owner selected project **nightshift-c3e1a** (NightShift). The connected Firebase tools confirmed access and registered Android application **com.nightshift.app**. Billing is disabled. The `development` alias in `.firebaserc` points to this project; it is not a production release approval.

An earlier isolated project, `nightshift-dev-agilan`, was created before the owner supplied the intended project. It also has billing disabled and is unused. No existing unrelated application project was modified. Removing that unused cloud project remains an explicit cleanup decision.

## Local configuration

The owner has now selected **Firebase's paid Phone Authentication SMS to India (+91)**, superseding MSG91/Twilio for the next integration. The configuration and implementation below describe the earlier custom-token checkpoint. Native Firebase phone integration, Phone provider/India region policy, app fingerprints, Blaze billing and an approved test cap remain to be completed; no live SMS has been sent.

`firebase.json` contains authentication configuration with no enabled anonymous, email/password or Google sign-in providers. This app's intended protocol is server-verified MSG91 proof, a Firebase custom token, client exchange to ID/refresh tokens, and backend ID-token verification. A project/app registration alone does not establish that the full protocol works.

The selected Android SDK configuration and USB-test build definitions are saved under ignored `artifacts/private/firebase/`. They are not committed. The key in the SDK configuration is a Firebase client API key; it is not an Admin credential or a substitute for server permissions.

The API still needs privately configured Application Default Credentials, the selected project ID, a stable protected phone-digest key, approved MSG91 widget/authentication configuration, the notice version and an explicit approved daily SMS-send cap. See `.env.example`. `PHONE_AUTH_ENABLED` stays false until those prerequisites are ready. No real SMS was sent or spending enabled by this setup.

For local Android USB testing, the ignored build definitions select `http://127.0.0.1:3000`. Use the runbook's `adb reverse` setup. Phone credentials are permitted only over HTTPS or explicit debug loopback/emulator origins; arbitrary LAN HTTP and redirects are rejected. A phone sign-in build can use:

```powershell
# From apps/mobile; the referenced definitions remain private and ignored.
flutter build apk --debug --target-platform android-arm64 --split-per-abi --dart-define-from-file=../../artifacts/private/firebase/phone-build-defines.json
```

That build does not enable the server's SMS adapter or approve a provider bill. A build without the definitions retains the existing fictional development login and a safely unavailable phone entry point.

## Evidence still required

- Server credential/permission verification for custom-token signing and Firebase ID-token revocation checks.
- MSG91 entity/header/template/PE–TM approval, consent wording, approved SMS cap and consenting Indian-SIM testers.
- Actual custom-token exchange and refresh through this project, including disabled/revoked/expired identities.
- Physical-device account recovery and accessibility checks.
- Publisher/package confirmation and release decisions before production distribution.

Firebase's [pricing documentation](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans) explains the no-cost Spark plan and that linking Cloud Billing upgrades the project to Blaze. No billing account was linked here. Authentication flow reference: [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth).
