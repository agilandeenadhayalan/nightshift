# NightShift Firebase development setup

Recorded 20 November 2026. The owner selected project **nightshift-c3e1a** (NightShift), number **844582070891**, and explicitly chose **Firebase paid Phone Authentication SMS to India (+91)**. This supersedes the previous Twilio and MSG91 provider choices. The connected Firebase tools registered Android application **com.nightshift.app**, app ID **1:844582070891:android:43b3988afbd1e2d4a61f2e**. The `development` alias in `.firebaserc` points to this project; it is not a production release approval.

An earlier isolated project, `nightshift-dev-agilan`, was created before the owner supplied the intended project. It also has billing disabled and is unused. No existing unrelated application project was modified. Removing that unused cloud project remains an explicit cleanup decision.

## Local configuration

The Android app now uses the native Firebase Phone Authentication SDK: application admission, SDK verification callbacks/manual code entry, Firebase ID token, then the NightShift session exchange. Firebase UIDs map to opaque NightShift account IDs. The backend accepts only a verified phone sign-in proof for an Indian number, checks revocation, and binds the phone to an existing account or its deletion restriction before creating a new account. No live SMS has been sent.

`firebase.json` is local configuration, not evidence of enabled cloud providers. The owner-authenticated Console showed the **Spark** plan. Authentication was initialized and Phone was enabled after explicit owner approval of the displayed Play Integrity agreement. The saved SMS region policy allows **India (IN) only**. Blaze billing account selection and the monthly budget remain pending. The owner approved **1,000 SMS/day** as an operating limit; no provider quota was raised and no SMS was sent. The earlier MSG91 custom-token adapter remains for compatibility tests; it is not the selected mobile live flow.

The selected Android SDK configuration and USB-test build definitions are saved under ignored `artifacts/private/firebase/`. They are not committed. The key in the SDK configuration is a Firebase client API key; it is not an Admin credential or a substitute for server permissions.

The API needs privately configured Application Default Credentials for Firebase revocation checks, `PHONE_AUTH_PROVIDER=firebase`, the selected project ID, a stable protected phone-digest key, the notice version and an explicit `PHONE_AUTH_DAILY_ADMISSION_LIMIT`. See `.env.example`. `PHONE_AUTH_ENABLED` stays false until these prerequisites are ready. The application admission limit is **not a Firebase SMS spending cap**: direct SDK calls can bypass the app API, and billing alerts do not automatically stop charges. Provider region restrictions, monitoring and an operating budget are separate controls.

The app initializes Firebase with four ignored client build definitions: `FIREBASE_WEB_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_PROJECT_ID` and `FIREBASE_MESSAGING_SENDER_ID`. The pinned native packages are `firebase_auth` 6.5.7 and `firebase_core` 4.13.0, compatible with the existing Flutter 3.27/Dart 3.6/minSdk 23 toolchain. Firebase SDK persistence is SDK-managed; secure app storage holds the backend-accepted identity marker. On restart the app verifies that marker and registers a fresh ID token with the backend before restoring protected access. A leftover native SDK user alone cannot restore the app account. Android backup and device-transfer rules exclude app and Firebase authentication storage.

The current local debug certificate's SHA-1 and SHA-256 were registered through Firebase. A release signed by Google Play needs the corresponding Play app-signing fingerprints separately; debug registration does not cover them.

For local Android USB testing, the ignored build definitions select `http://127.0.0.1:3000`. Use the runbook's `adb reverse` setup. Phone credentials are permitted only over HTTPS or explicit debug loopback/emulator origins; arbitrary LAN HTTP and redirects are rejected. A phone sign-in build can use:

```powershell
# From apps/mobile; the referenced definitions remain private and ignored.
flutter build apk --debug --target-platform android-arm64 --split-per-abi --dart-define-from-file=../../artifacts/private/firebase/phone-build-defines.json
```

That build does not enable the server's SMS adapter or approve a provider bill. A build without the definitions retains the existing fictional development login and a safely unavailable phone entry point.

## Evidence still required

- Server credential/permission verification for Firebase ID-token revocation checks.
- Blaze billing with an explicitly selected billing account and monthly budget; verify actual provider quotas against the approved 1,000 SMS/day operating limit.
- Approved notice wording and consenting Indian-SIM testers.
- Actual SDK delivery, manual/automatic verification, refresh and disabled/revoked/expired identities through this project.
- Physical-device account recovery and accessibility checks.
- Publisher/package confirmation and release decisions before production distribution.

Firebase's [authentication limits](https://firebase.google.com/docs/auth/limits) require Blaze for verification SMS. Its [Android phone authentication guide](https://firebase.google.com/docs/auth/android/phone-auth) covers provider enablement, fingerprints, Play Integrity and SMS regions. See also [billing protection guidance](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills). No billing account was linked here.
