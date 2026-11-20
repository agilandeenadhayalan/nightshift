# FA-009: phone identity validation foundation

Related issue: [#9](https://github.com/agilandeenadhayalan/nightshift/issues/9). This implements the server challenge/proof lifecycle, provider boundaries, HTTP contracts and Flutter client/error handling. **The issue remains partially implemented.** A phone sign-in screen, Firebase client token exchange/refresh, app-session integration, owner provider configuration and real Indian SIM delivery still require work/evidence. The existing fictional Customer/Listener sign-in and test-credit call milestone remain available.

The backend still refuses production startup. All three new identity endpoints return `PHONE_AUTH_UNAVAILABLE` unless phone validation is explicitly configured. A verified identity does not create an app session, wallet, adult approval or Listener entitlement. New users are explicitly `customer`, `adult_confirmed=false` and `listener_approved=false`; existing account permissions are preserved. Staff access remains separate.

## Protocol and guarantees

1. `POST /v1/auth/otp/request` accepts `phone`, `deviceId`, `consentVersion` and an `Idempotency-Key` header. It returns an opaque challenge ID, current state, expiry and retry time. The public contract uses canonical `+91` mobile numbers. The database stores keyed digests, consent version, timestamps and an opaque provider request reference; it never stores the phone, OTP, provider access token or Firebase custom/ID token.
2. A challenge expires after five minutes. A new send can supersede an unanswered challenge after a 60-second cooldown. Repeating an idempotency key does not send again. Consumed, locked and unknown-outcome challenges prevent another send until the original expiry. Five wrong attempts lock a challenge. Parallel requests and verification are serialized through PostgreSQL transactions; external provider calls run outside those transactions.
3. MSG91 Widget uses fixed HTTPS POST endpoints. Send returns a request ID; code verification returns a provider access token. A separate server request verifies that token, and its returned identifier must exactly match the expected phone. HTTP 200 or decoded JWT claims alone cannot establish success. Timeouts, malformed responses, changed identifiers and ambiguous token consumption fail closed. No automatic provider retry occurs.
4. `POST /v1/auth/otp/verify` accepts the challenge ID, phone, device ID and six-digit code. Valid proof is consumed transactionally and binds one opaque user through `auth_identities` before Firebase custom-token creation. Revoked identities and suspended users cannot obtain a custom token. If signing fails or its result is lost, the proof stays consumed; start a new challenge after its original expiry instead of replaying it.
5. Firebase custom tokens must be exchanged by a Firebase client for ID tokens. `POST /v1/auth/firebase/verify` validates an ID token through Firebase Admin, including signature, issuer, audience, expiry, revocation and disabled-user checks; the wrapper also checks required timestamps, UID consistency and tenant scope. It returns an identity receipt only when an existing verified MSG91 binding matches that UID and configured project. Firebase emulator bypass is rejected. The current app endpoints still require existing development sessions; the identity receipt is not a substitute.

The MSG91 adapter caps each HTTP operation at three seconds, including body reads, rejects redirects and bounds response size. Firebase ID verification has a six-second deadline and at most 16 underlying operations in flight; timed-out work stays counted until the SDK settles because its public API has no cancellation signal. The Flutter facade gives OTP/Firebase verification a separate 20-second deadline with cancellation, while ordinary requests retain their eight-second deadline. Safe errors include bounded retry hints; diagnostics omit input/provider prose.

References checked on 20 November 2026: [MSG91 Widget protocol](https://docs.msg91.com/otp-widget), [MSG91 widget configuration](https://msg91.com/help/sendotp/how-to-integrate-the-new-login-with-otp-widget), [Firebase ID-token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [Firebase revocation](https://firebase.google.com/docs/auth/admin/manage-sessions). Firebase Admin is pinned to 14.5.1. The Android app still uses its existing dependency set and one application ID.

## Limits and owner decisions

These are conservative engineering defaults, not an approved SMS budget. PostgreSQL applies fixed UTC windows: request IP 120/five minutes; verification IP 60/five minutes; send phone 3/hour; send device 10/hour; send IP 20/hour. The global send cap is **daily** and must be explicitly configured by the owner. A request reserves quota before making a provider call; uncertain delivery still consumes that reservation. Fixed windows are not sliding windows and can permit adjacent-window bursts. Changing the device ID cannot bypass phone, IP or global limits. The separate Firebase ID-check endpoint has an IP rate limit through Redis.

Outstanding input/evidence, supplementing [Decision_Register.md](Decision_Register.md):

| Decision | Still required |
|---|---|
| D17 provider projects | Owner-controlled Firebase project/credentials and MSG91 widget/authkey, with approved SMS sender/template/provider chain |
| D09 spending | Owner-approved `PHONE_AUTH_DAILY_SEND_LIMIT`, provider spending controls/alerts and test recipients; no spending was authorized or performed during implementation |
| D17 widget behavior | SMS as primary channel, six-digit codes, demo credentials disabled, captcha/invisible OTP disabled for this server API; verify account/template settings and real branded delivery. The widget's longer provider expiry does not extend our five-minute local expiry |
| Consent and privacy | Approved phone-sign-in notice and version, provider/data-processing review, retention/deletion schedule, and protected deployment logging that never captures request bodies or credentials |
| Identity key custody | Store/backup `PHONE_AUTH_DIGEST_KEY` securely. The persisted namespace fingerprint rejects accidental key changes; planned key rotation/account migration is separate work |
| Adult onboarding | Production age assurance, profile/consent completion and reviewed app-session/device policy before granting call access |

Rate-limit rows and challenge evidence currently persist for review. Before a shared deployment, define retention and a cleanup job that preserves active quotas, unknown outcomes and the required replay window. This change does not claim to implement the later account-deletion/retention issue.

## Local WSL 2 / Windows use

The standard [local runbook](Local_Development.md) still runs the backend in WSL 2 and Flutter from Windows. Ordinary development and Compose keep phone validation disabled; no identity-provider credentials are needed to build or use the test-credit APK.

Provider validation, when the owner is ready, uses the native backend process in WSL 2 with the ignored local `.env`. Configure the following names without committing values:

```dotenv
PHONE_AUTH_ENABLED=true
FIREBASE_PROJECT_ID=
GOOGLE_APPLICATION_CREDENTIALS=/absolute/private/path/service-account.json
PHONE_AUTH_DIGEST_KEY=
PHONE_AUTH_CONSENT_VERSION=
PHONE_AUTH_DAILY_SEND_LIMIT=
MSG91_WIDGET_ID=
MSG91_AUTH_KEY=
```

`PHONE_AUTH_DIGEST_KEY` needs at least 32 bytes of unpredictable secret material; keep it stable for the configured project. Use Application Default Credentials owned by that project. The daily send cap must be an integer from 1 to 1000. The standard Compose file deliberately does not forward these optional SMS credentials; use the native WSL backend for this controlled check. Only use loopback/USB forwarding or a deliberately configured HTTPS test endpoint for sensitive identity traffic. Do not paste credentials, phone numbers, codes or tokens into shell history, screenshots, logs or PRs.

Run migrations and start the API using the existing runbook. The new endpoints are a provider-validation interface, not a finished phone sign-in UI. A real provider check must record the actual SMS sender and delivery, correct/wrong/expired/reused codes, consent, quota behavior, Firebase client exchange and ID-token rejection/revocation. Use opaque IDs in evidence. An actual phone/Firebase flow was not executed during this implementation.

## Migration, verification and rollback

Migration `004_otp_challenges.sql` adds challenge, quota and digest-key namespace tables. Migrations 001–003 are unchanged. There is no automatic new-user credit grant. Run tests against a separate `TEST_DATABASE_URL`; each database suite creates and drops only its own random schema. Provider tests use synthetic transport; Firebase signature tests use real SDK verification with in-memory RSA keys and mocked network boundaries.

The PR records the executed test counts, generated-client comparison, debug APK and CI result. Coverage includes concurrent request/verify/quota races, malformed and delayed provider responses, replay and expiry, wrong codes, custom-token failure, unsafe identity state, production/test-adapter gates, secret redaction, actual HTTP response schemas and Flutter transport/localized recovery copy. Passing those tests does not establish real sender delivery, Firebase project permissions or two-phone media.

Local verification on 20 November 2026: **209 tests passed** (39 API units/provider tests, 5 domain, 3 browser reference, 10 repository tooling, 60 PostgreSQL/Redis integration/schema/HTTP and 10 economics, plus 82 Flutter). TypeScript build/type checks, Flutter analysis, secret/boundary guards and exact regeneration of all 50 Dart SDK files passed. The new tests include actual Firebase SDK cryptographic verification with generated keys; they do not use an unsigned-token acceptance shortcut. The locked npm dependency audit reported no vulnerabilities when Firebase Admin was installed.

The ARM64 debug APK built successfully at `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`: 180,219,416 bytes, SHA-256 `b9199813871c61ba209fefd9e7c9752909674780a2f148d8b9f77c30f228ebfc`. It contains no provider credentials or phone sign-in screen. The PR's CI artifact is a separate clean-runner build of the committed source.

The Linux API image also built and started with the new dependency set and migration. PostgreSQL, Redis and API health checks passed. The actual generated Dart SDK HTTP smoke run completed online discovery, invite/replay, accept, end, zero charge without media, released claims and matching histories; safe call ID `16d0ace0-e667-4b69-9c4a-c1a51b3e7f14`. The packaged phone request endpoint returned HTTP 503 / `PHONE_AUTH_UNAVAILABLE` as intended with no provider configuration. No media readiness was fabricated. Only the project's local services were used; volumes are preserved.

To disable the new interface, set `PHONE_AUTH_ENABLED=false` and restart. The previous application version ignores the additive tables, so rollback requires no destructive database reversal. Preserve challenge/identity records and the digest key; deleting them to reset a quota or recover a token would defeat the replay protections. The subsequent [foreground two-phone audio milestone passed](Device_Debug_2026-11-20.md); the broader [device matrix](Two_Phone_Test.md) and [physical accessibility](FA008_Verification.md) checks remain open.
