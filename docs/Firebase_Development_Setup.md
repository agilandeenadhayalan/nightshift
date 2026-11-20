# NightShift Firebase development setup

Recorded 20 November 2026. The owner selected project **nightshift-c3e1a** (NightShift), number **844582070891**, and explicitly chose **Firebase paid Phone Authentication SMS to India (+91)**. This supersedes the previous Twilio and MSG91 provider choices. The connected Firebase tools registered Android application **com.nightshift.app**, app ID **1:844582070891:android:43b3988afbd1e2d4a61f2e**. The `development` alias in `.firebaserc` points to this project; it is not a production release approval.

An earlier isolated project, `nightshift-dev-agilan`, was created before the owner supplied the intended project. It also has billing disabled and is unused. No existing unrelated application project was modified. Removing that unused cloud project remains an explicit cleanup decision.

## Local configuration

The Android app now uses the native Firebase Phone Authentication SDK: application admission, SDK verification callbacks/manual code entry, Firebase ID token, then the NightShift session exchange. Firebase UIDs map to opaque NightShift account IDs. The backend accepts only a verified phone sign-in proof for an Indian number, checks revocation, and binds the phone to an existing account or its deletion restriction before creating a new account. Automated verification uses synthetic identities; the separate owner-device evidence is recorded below.

`firebase.json` is local configuration, not evidence of enabled cloud providers. The owner-authenticated Console now shows **Blaze**. Authentication was initialized and Phone was enabled after explicit owner approval of the displayed Play Integrity agreement. The saved SMS region policy allows **India (IN) only**. The owner approved **₹5,000/month** and **1,000 SMS/day** as operating limits. The selected My Billing Account 2 reached its linked-project quota; subsequent Console activity linked My Billing Account 3. The saved billing page was independently checked: NightShift has a monthly ₹5,000 alerts-only budget, with actual-spend thresholds at 50%, 90% and 100% (₹2,500/₹4,500/₹5,000), emailed to billing admins and users. These alerts do not stop Authentication charges. No billing account identifiers or payment details are recorded here.

After the upgrade, the Authentication Console displayed a sent-SMS quota of **1,000/day** for new projects with billing accounts. This records the observed provider quota, not an agent-configured hard spending cap. No quota was raised and no SMS was sent by the agent. The earlier MSG91 custom-token adapter remains for compatibility tests; it is not the selected mobile live flow.

The selected Android SDK configuration and USB-test build definitions are saved under ignored `artifacts/private/firebase/`. They are not committed. The key in the SDK configuration is a Firebase client API key; it is not an Admin credential or a substitute for server permissions.

The API needs privately configured Application Default Credentials for Firebase revocation checks, `PHONE_AUTH_PROVIDER=firebase`, the selected project ID, a stable protected phone-digest key, the notice version and an explicit `PHONE_AUTH_DAILY_ADMISSION_LIMIT`. See `.env.example`. `PHONE_AUTH_ENABLED` stays false until these prerequisites are ready. The application admission limit is **not a Firebase SMS spending cap**: direct SDK calls can bypass the app API, and billing alerts do not automatically stop charges. Provider region restrictions, monitoring and an operating budget are separate controls.

A read-only Admin SDK permission probe against the selected project did not succeed with the existing local credentials (`auth/internal-error`); no credential, token or user record was logged. The failure cause is not established. A file's presence is not proof of working server access. Firebase documents that ordinary gcloud end-user credentials are not accepted for Authentication: its [local Admin setup](https://firebase.google.com/docs/admin/setup#test-with-gcloud-end-user-credentials) requires a supported service identity or a project-owned Desktop OAuth client for that route. Verify the private credential and `firebaseauth.users.get` access before enabling phone sign-in; a successful native SMS alone does not prove server revocation checks work.

The owner subsequently requested dedicated server access and volunteered to test OTP on their own Indian SIM. The `nightshift-auth-verifier` service account was created in this project. Its custom project role contains only `firebaseauth.users.get`; the owner was granted a service-account-scoped custom role containing only `iam.serviceAccounts.getAccessToken`. IAM Credentials API is enabled. No user-managed service-account key was created. The owner completed the corrected Google Auth Library confirmation in Opera, and the isolated impersonated ADC now passes the Admin SDK read-permission probe: a fresh nonexistent UID returns `auth/user-not-found`, rather than a permission failure. No token, credential or user record was printed. The existing global ADC file was not replaced. The local ADC includes an owner OAuth source credential and must remain private; the service account's narrow role does not restrict all authority of that source credential.

For the first device test, source at `900c1ab` was extracted and built in a private local runtime directory outside Git. It uses a dedicated PostgreSQL database, Redis database 13 and loopback port 3001; the original local API and development data remain running separately. Private configuration enables Firebase phone auth with `phone-signin-v1`, a stable generated phone-digest key, the isolated ADC and a 1,000/day application-admission limit. All migrations through 010 applied and the health check passed. The previously verified ARM64 Firebase APK was installed successfully on both connected phones without clearing their app storage; USB reverse forwarding connects its loopback port 3000 to this isolated server. The isolated server subsequently recorded one verified Firebase phone identity, one sign-in consent and completed adult onboarding. This is real server evidence of native ID-token exchange with provider revocation checks, not a synthetic verifier. The owner reports working sign-in on one phone; SMS delivery versus automatic verification and the Redmi follow-up remain unconfirmed. No phone number, OTP, UID or profile fields were included in the recorded aggregate evidence.

The app initializes Firebase with four ignored client build definitions: `FIREBASE_WEB_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_PROJECT_ID` and `FIREBASE_MESSAGING_SENDER_ID`. The pinned native packages are `firebase_auth` 6.5.7 and `firebase_core` 4.13.0, compatible with the existing Flutter 3.27/Dart 3.6/minSdk 23 toolchain. Firebase SDK persistence is SDK-managed; secure app storage holds the backend-accepted identity marker. On restart the app verifies that marker and registers a fresh ID token with the backend before restoring protected access. A leftover native SDK user alone cannot restore the app account. Android backup and device-transfer rules exclude app and Firebase authentication storage.

The current local debug certificate's SHA-1 and SHA-256 were registered through Firebase. A release signed by Google Play needs the corresponding Play app-signing fingerprints separately; debug registration does not cover them.

For local Android USB testing, the ignored build definitions select `http://127.0.0.1:3000`. Use the runbook's `adb reverse` setup. Phone credentials are permitted only over HTTPS or explicit debug loopback/emulator origins; arbitrary LAN HTTP and redirects are rejected. A phone sign-in build can use:

```powershell
# From apps/mobile; the referenced definitions remain private and ignored.
flutter build apk --debug --target-platform android-arm64 --split-per-abi --dart-define-from-file=../../artifacts/private/firebase/phone-build-defines.json
```

That build does not enable the server's SMS adapter or approve a provider bill. A build without the definitions retains the existing fictional development login and a safely unavailable phone entry point.

## Evidence still required

- Owner confirmation of real SMS delivery and screen behavior; subsequent refresh, logout/restart and deliberately revoked/disabled identity checks remain.
- Monitor actual provider usage against the approved 1,000 SMS/day and ₹5,000/month operating limits; alerts alone cannot enforce the monthly limit.
- Approved production notice wording and completion of the Redmi follow-up test.
- Actual SDK delivery, manual/automatic verification, refresh and disabled/revoked/expired identities through this project.
- Physical-device account recovery and accessibility checks.
- Publisher/package confirmation and release decisions before production distribution.

Firebase's [authentication limits](https://firebase.google.com/docs/auth/limits) require Blaze for verification SMS. Its [Android phone authentication guide](https://firebase.google.com/docs/auth/android/phone-auth) covers provider enablement, fingerprints, Play Integrity and SMS regions. See also [billing protection guidance](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills). The currently documented [Firebase spend-cap preview](https://firebase.google.com/docs/projects/billing/spend-caps) covers selected services, not Authentication; it must not be presented as an SMS cutoff.

## First owner-device result

The owner reports sign-in working on one phone and corrected the failing handset to **Redmi 23077RABDC / Android 13**. The server recorded one verified Firebase phone identity, active Firebase session, sign-in consent and completed adult onboarding. The Redmi log reports provider error `17028`, `Invalid app info in play_integrity_token`. Read-only checks confirm the exact APK SHA-1/SHA-256, package/app ID, client key selection, authorized Firebase domains and reCAPTCHA callback activity. No key restriction or provider verification was disabled.

A separate USB reconnect cleared forwarding and produced a server-unreachable error. Forwarding was restored using the official Android SDK bridge; both phone-local health requests then returned `status: ok`. The earlier provider failure remains a separate device verification investigation. The physical test is not reported as passing on both phones. No phone number, OTP, UID or private profile is included here.

The isolated phone server uses host port 3001. After any USB/ADB reconnect, restore and check each phone before an OTP attempt:

```powershell
adb -s DEVICE_SERIAL reverse tcp:3000 tcp:3001
adb -s DEVICE_SERIAL reverse --list
# These tested devices include curl; the response must identify nightshift-api.
adb -s DEVICE_SERIAL shell curl --silent --show-error --max-time 5 --noproxy 127.0.0.1 http://127.0.0.1:3000/v1/health
```

For the Redmi investigation, an explicit ignored `FIREBASE_FORCE_RECAPTCHA=true` build definition selects Firebase's supported browser-verification route **only in a debug build**. Profile/release ignore it. The SDK setting keeps `appVerificationDisabledForTesting=false`; it adds no test number/code and performs no automatic SMS retry. Consent/attempt validity is checked before and after the asynchronous settings call. The owner must complete any browser challenge. Seven new settings regressions and the adjacent native/UI suite pass (28 focused checks); the complete discovery-compatible Flutter suite passes 286/286, with a clean analyzer and independent review. See [Firebase Auth settings](https://firebase.google.com/docs/reference/android/com/google/firebase/auth/FirebaseAuthSettings). Actual Redmi delivery and exchange are still awaiting the separate diagnostic build test.

The diagnostic ARM64 APK was built from `900c1ab` plus only the native Firebase settings change, preserving the baseline dependency lock and Android build configuration. Its SHA-256 is `7d6bc736b4fa17d78735083ef08e0eeac93f97cfa05c1b83df77baedfd4820a7` (162,020,935 bytes). Package, debug signature and reCAPTCHA callback manifest checks passed. It was installed successfully on the Redmi without clearing app storage; the phone-local health request again returned `status: ok` after USB forwarding was restored. The owner was asked to perform one consented attempt and complete any browser challenge. This installation and connectivity check do not establish a successful Redmi sign-in.

The owner reported a 255-second resend cooldown after installation. No further code request was made by the agent; the countdown must expire before another owner attempt. A cooldown is not evidence that the new browser-verification route succeeded or failed.

The reported 255-second wait was respected before requesting another owner attempt; a read-only server aggregate also showed zero remaining retry time. Review found a separate UI defect: the expired `OTP_COOLDOWN`/`OTP_RATE_LIMITED` warning could remain after Send code became available. The source fix gives that warning its own deadline and clears it at expiry, while retaining provider limits, errors without a retry deadline and unrelated failures. Six fake-clock regressions verify the final fractional second, explicit retry, no automatic API/provider request and preservation of a later throttle; the adjacent 41-test mobile suite and analyzer pass, with independent review. This display fix follows the installed diagnostic APK recorded above and has not yet been installed on the phones.
