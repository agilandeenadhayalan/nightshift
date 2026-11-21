# Embedded staff access

Continuation of #10, recorded 21 November 2026. The owner selected SMS OTP-only, the Redmi account for reviewer/access-administrator permissions, and staff pages inside NightShift. Customer and Listener remain the two app modes. This slice does not approve a Listener application or implement the review workflow in #14.

Current private-device evidence: the selected Redmi account was explicitly provisioned on 21 November 2026, and the owner confirmed that the staff workspace opens inside NightShift after fresh SMS sign-in. The enrollment and server corroboration are recorded below; physical revocation/recovery and actual review-workflow evidence remain separate.

## Identity and authorization

The real Firebase Admin adapter verifies the existing registered phone identity and its current provider state. Native challenge/exchange require the exact current app bearer; a customer identity alone receives no staff privileges. A provisioned staff principal must match the provider subject and canonical app user. Staff sessions carry the source app user, device, phone binding and authentication lineage. Every authorization rechecks that lineage under the staff-principal lock followed by all involved app-user locks in sorted order. Logout, device replacement, suspension and deletion therefore invalidate the source authority; refreshed tokens in the same active lineage do not manufacture a new phone verification.

The initial private engineering policy uses a 30-minute maximum staff session, phone authentication no older than one hour, and two-minute single-use challenges. Opening staff access refreshes the native ID token and registers it through the existing app session path. It never sends an SMS automatically. Expired authentication or explicit staff sign-out requires the owner to complete phone sign-in again; refreshing a token does not manufacture a new phone authentication time. The native screen explains this for both fresh-authentication and staff-session rejection codes. Recovery/backup and production policy approval remain separate owner decisions.

An authenticated access request returns only an opaque request reference and canonical account reference. It does not create a principal or grant. The offline provisioning command requires both exact references and explicit permissions, defaults to a read-only preview, and rechecks provider identity and live source lineage before applying. Initial allowed permissions are `listener.review.read`, `listener.review.evidence.read`, `listener.review.decide` and `staff.access.manage`; this slice has no browser grant/revoke UI. Pending enrollment data expires after one hour, is removed by bounded cleanup, and is erased when its app owner is suspended or loses adulthood eligibility. Separate staff authority/audit history follows the still-unresolved retention policy.

## Native and browser boundary

Firebase proof stays in the native HTTP client. It reaches only four allowlisted native proxy operations over the fixed HTTPS staff origin. That transport refuses redirects, bounds bodies and deadlines, and forwards the app bearer only on those operations. The browser session routes remain cookie-only.

Android receives only the validated opaque session capability, bounded expiry and account generation. Its dedicated MethodChannel reconstructs the fixed-name host-only Secure/HttpOnly/SameSite=Strict cookie; it is not callable from web JavaScript. Cookie writes and cleanup are serialized through actual native callbacks. A callback timeout does not free the operation slot, and stale generations cannot install after newer cleanup. The WebView then opens a credential-free fixed URL. Account changes, backgrounding and logout hide the page and invalidate outstanding work. Native restrictions deny external navigation, file/content access, browser permissions and TLS-error bypasses.

The Next page uses a fresh server nonce for scripts/styles and restricts resources and connections to its own origin. This matters because cookies are host-scoped, not port-scoped. Production browser checks verify hydration, injected-script rejection and blocked requests to a second port, alongside expiry, logout and 200% text layout. The nonce implementation follows the [Next.js CSP guide](https://nextjs.org/docs/app/guides/content-security-policy).

## Private HTTPS device setup

`scripts/prepare-staff-local-https.ps1` generates a private development CA and seven-day localhost certificate under `%LOCALAPPDATA%/NightShift/staff-local-https`, with restricted filesystem access. It copies only the public CA into the ignored `apps/mobile/android/app/src/staffLocalDebug` overlay. The optional overlay is included only by the Android debug source set, scopes the extra trust anchor to `127.0.0.1`, and preserves the existing debug customer API loopback connection. It changes no OS trust store. Profile/release reject a loopback staff origin and do not include that resource source set.

The dedicated Dart HTTP client uses that public CA only in debug, with normal certificate-chain and hostname verification. It does not change the global trust context or accept invalid certificates. Android trust behavior is based on [Network Security Configuration](https://developer.android.com/privacy-and-security/security-config).

Use the repository's Node24 toolchain and these explicit local-only settings in a private environment:

```
STAFF_CONSOLE_ORIGIN=https://127.0.0.1:3443
STAFF_LOCAL_TLS_DIR=<absolute private certificate directory>
STAFF_API_BASE_URL=http://127.0.0.1:3001
```

After building the admin app, `npm run start:local-https --workspace @nightshift/admin` binds only `127.0.0.1:3443`. The wrapper rejects a different Host and uses existing certificate files. It does not call mkcert or install system trust. Phone testing additionally requires USB reverse for port3443 and an APK compiled with the same `STAFF_CONSOLE_ORIGIN`.

Backend activation separately requires `STAFF_AUTH_ENABLED=true`, native Firebase phone configuration, a private stable `STAFF_AUTH_DIGEST_KEY`, an explicit `STAFF_AUTH_POLICY_VERSION` and `STAFF_SESSION_SECONDS` between60 and1800. These values do not provision an account. Keep all private configuration, database snapshots and provider identifiers outside Git.

## Verification and remaining evidence

The preceding [PR #76](https://github.com/agilandeenadhayalan/nightshift/pull/76) passed all three CI jobs at `b37378549507717cb4f5706704aca876ba59a1ea`; its hourly quota regression now uses a deterministic clock and tests the reset boundary. This continuation has the following evidence; all artifacts are ignored and contain synthetic test output or non-sensitive build metadata.

| Check | Recorded result |
| --- | --- |
| Backend regression before final challenge cleanup | 230/230, zero failures/skips; `staff-native-integration-final.log` |
| Final challenge privacy/lock correction | A real PostgreSQL deadlock was reproduced, then47/47 native/foundation/schema checks passed; `staff-challenge-lock-before.log`, `staff-challenge-lock-after.log` |
| API units/build | 43/43 and TypeScript compile; native provider checks use signed synthetic SDK fixtures, not real SMS |
| Flutter | Analyzer clean, 316/316 tests; `embedded-staff-mobile.log` |
| Android cookie coordinator | 14 policy/callback/generation checks; Kotlin debug compilation passed; `staff-native-compile.log` |
| Admin build/contracts/transport | 22/22 plus production build/typecheck; `staff-native-admin-final.log` |
| Actual Chromium | 8/8, including enforced CSP and large-text font variants; `staff-native-admin-browser.log` |
| Repository validation | Secret/contract/boundary checks and11 tooling checks; `staff-embedded-repo-final.log` |
| Private TLS | Normal trust and hostname validation, exact Host and loopback listener; `staff-local-tls-evidence.json` |
| Configured Android APK | ARM64 debug build passed, signature/package verified and173 source inputs unchanged; `embedded-staff-build-record.json` |
| Release/profile exclusion | Both loopback build dry runs reject before app tasks; `embedded-staff-release-guard.log`, `embedded-staff-profile-guard.log` |

The final cleanup removes expired challenge identity bindings after two minutes while preserving anonymous rate-window accounting until one hour; deletion removes its owner's binding immediately. Owner locks now precede challenge rows consistently. The first230-test full run precedes these changes; the47 focused checks and subsequent exact-head CI supply their separate evidence. Independent native, backend and proxy/TLS source reviews found no remaining blocker in this slice.

The initial configured APK is `artifacts/nightshift-firebase-staff-arm64.apk`,162861624bytes, SHA256 `eb6de493e791c0c98c5eac8d7b53d25105e4dcbc1e602eac77caa0578bf289c4`. Its package is `com.nightshift.app`, ARM64 versionCode4002, minSDK23/target35. The merged manifest keeps backups disabled and includes only the debug network configuration; its public CA matches the generated overlay. A follow-up corrects the fresh-sign-in explanation after staff logout, with7 focused UI/controller checks and a clean analyzer. Its separate APK/build record must match the follow-up commit before installation; the initial APK was not installed. Installation and live staff results are separate from build evidence.

The local HTTPS check accepted the trusted certificate, rejected an untrusted CA and a wrong hostname, and returned421 for a wrong Host. The listener was confirmed bound to loopback and stopped after that check. No real staff grant or phone-runtime migration was used for those checks.

## Verified private device upgrade

[PR #77 validation](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44800979699) passed all three jobs on exact commit `2db1eb91a65b0f572987f2e5831e48704a16acfd`. The backend integration suite passed 233/233. Android passed 317 Flutter tests, clean analysis, 74 generated-contract files, 6 bounded audio-reader checks and 14 native cookie checks. Its account journey used synthetic Firebase fixtures (`realSms:false`); it is not a new live SMS result.

The corrected configured APK is `artifacts/nightshift-firebase-staff-logout-arm64.apk`, 162893173 bytes, SHA256 `6553f29d52bab9a9032337a906f468b115d5394d597a94f740a2bcaa1da1058e`. Its separate build record matches the exact commit, all 173 source inputs, the private client configuration and public debug CA overlay. It retains the existing application ID and signing certificate, versionCode 4002, ARM64, minSDK 23/target 35.

On 21 November (India time), the private phone runtime was rebuilt from that exact Git archive with byte-checked dependencies and restricted private configuration. A PostgreSQL backup was actually restored into a fresh isolated test database and removed after verification. With the old API stopped and no active calls, participant claims, spend holds or other database clients, a second snapshot was restored and all 42 public-table counts matched the quiescent source. No restore was performed against the live database.

Migrations 011–013 then applied successfully. Both existing users and adult onboardings, both Listener application records, and zero approved Listeners were preserved. At that upgrade checkpoint, staff principals, grants and sessions remained zero. Only the five reviewed staff configuration keys were added; existing phone/provider/admission settings were unchanged. The archived API and production staff HTTPS server ran on loopback. Health and configured-status checks passed; the active HTTPS endpoint again rejected an untrusted CA, wrong hostname and wrong Host.

The corrected APK was installed in place on both the Redmi and Motorola, preserving app data. Both reported versionCode 4002 and reached the upgraded API through USB forwarding. Both also reached the staff HTTPS endpoint using normal certificate validation. At that checkpoint, this verified installation and connectivity, not a successful embedded staff session. The owner was asked to create the authenticated access request from the selected Redmi account. No staff permission had yet been provisioned, no Listener approved, and no new SMS sent by those upgrade steps. The private snapshots, source/runtime manifests, install evidence and TLS checks remain outside Git.

The authenticated Redmi request, explicit provisioning and positive embedded-session opening were subsequently verified as recorded below. Physical revocation, logout/reopen, recovery and review criteria remain acceptance gates. A successful synthetic test or compiled APK does not establish those outcomes. See [staff review plan](Staff_Review_Plan.md) for the separate #14 work.

### USB connection recovery — 21 November 2026

The owner reported “cannot reach the server” while requesting staff access on the Redmi. The existing API health check passed on the computer, but the connected Redmi had no ADB reverse routes. Restoring phone port 3000 to host port 3001 and phone port 3443 to host port 3443 restored transport: an HTTP request from the Redmi returned 200 with the expected API health payload. A separate HTTPS reachability probe returned 200; that probe skipped certificate validation and is not new TLS-trust evidence. Motorola's existing routes were still present. No app installation, account reset, database migration or staff grant was performed. The owner was asked to retry the request and provide only its opaque references. USB reconnection can remove these development-only routes; this local build requires the cable and test server.

The error recurred after another Redmi USB reconnection: ADB assigned a new transport and both reverse routes were again absent. The saved backend address was verified as the intended local endpoint. A bounded, monitored local helper now restores only the two expected routes for the two known test phones when they reconnect. Phone-origin health returned 200 again, and the owner explicitly confirmed “Yes, Customer home opens.” At that recovery checkpoint, this confirmed home-screen recovery only. Staff enrollment still required a separate guided step; no access-request references or permission grant were inferred from reaching Customer home.

### Selected Redmi enrollment and embedded opening — 21 November 2026

After fresh SMS sign-in, the owner supplied the exact authenticated account and access-request references from the selected Redmi account. A reviewed offline operator wrapper used the archived private runtime at `f220aa5be0eab90dd18e48e0ec748756247e3128`. Its default read-only preview reported four permissions to add and `applied:false`. A separate explicit apply reported those four additions and `applied:true`; a subsequent fresh preview reported no remaining additions. The granted permissions are exactly `listener.review.read`, `listener.review.evidence.read`, `listener.review.decide` and `staff.access.manage`. No account/request references, phone numbers or provider identity values are recorded here.

The owner then confirmed: “Yes, the staff workspace opens.” This is a positive physical-device result for staff access inside NightShift on the Redmi, following fresh SMS authentication and explicit provisioning. It is distinct from the earlier synthetic browser tests and connectivity probes. Customer and Listener remain the only app modes; staff access uses its separate authority and embedded browser boundary.

A scoped read-only server check after provisioning corroborated a provisioned request, a principal bound to the selected account, exactly four active permissions, one current bound staff session, one provisioning audit and one session audit. The private runtime remained at migration 014 and the app account remained in Customer mode. No runtime migration or app installation accompanied this enrollment check. The private references and query evidence remain outside Git.

This verifies enrollment and the positive opening path only. Physical permission revocation, staff logout followed by manual fresh phone sign-in and reopening, background/session-expiry cleanup, and recovery remain to be exercised. A backup access administrator and recovery procedure remain unresolved. Nonempty review queue/detail/sample playback, approved versioned review criteria, actual decision/effect delivery, and evidence retention/appeal policy require their own acceptance evidence. These grants do not approve a Listener or enable decisions without the approved policy.
