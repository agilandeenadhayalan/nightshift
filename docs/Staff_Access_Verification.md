# Staff access foundation

Recorded 21 November 2026 for the #10 prerequisite to #14. The owner explicitly replaced the earlier MFA requirement with SMS OTP-only authentication, appointed themself initial reviewer and access administrator, selected the Redmi account, and requested staff pages inside NightShift's built-in browser. D26, FA-010 and the GitHub issue record that amendment. Customer and Listener remain the only app modes. Live staff access has not been provisioned.

## Implemented

Migration012 adds separate staff principals, permission grants, opaque-cookie sessions, short-lived challenges and immutable audits, with no live seed. Provider subject identifiers stay private; HMAC bindings and token/proof hashes support lookup and replay protection. The optional immutable linked app-account reference prepares known self-review checks without trusting client role claims.

The authority pins issuer/audience/tenant and provider-attested methods, checks recent authentication, queries current provider identity state, and revalidates local sessions/grants under a principal lock before sensitive actions. Grant changes, disablement and logout invalidate prior authority. Logout revokes all sessions for that staff principal; customer authentication stays separate. Signed synthetic SMS proofs exercise the provider interface. The normal application bootstrap always constructs unavailable staff authority, with no environment-selectable fixture, default administrator or self-enrollment route.

Challenge/exchange/logout require exact-origin and CSRF checks. Credentials use host-only Secure/HttpOnly/SameSite=Strict cookies; response CSRF tokens are for memory-only use. Provider work is bounded, including capacity retained until a timed-out underlying operation settles. The five staff routes have a separate public `@nightshift/contracts/staff.openapi.json`, checked for drift and excluded from the Customer/Listener Dart client. Error request IDs now match their response headers after a reproduced correlation regression was corrected.

The runnable Next.js session shell has a fixed-origin, bounded proxy that rejects redirects, unapproved Host/Origin values and non-staff credentials. It handles unavailable access, denied/expired sessions, permission display and logout. Lifecycle/expiry remove private state before revalidation. An uncertain logout retains that intent and cannot silently restore the previous view. Browser tests include stale responses, 360-pixel layout and 200% text/keyboard access.

The review entry is unavailable because this slice has no review/evidence/decision endpoints. There is no real OTP adapter or Flutter embedded-browser entry yet. Active-session screenshots use an isolated synthetic upstream, not the owner's account.

## Verification

| Check | Result and ignored artifact |
| --- | --- |
| Full backend regression | 214/214, zero failures/skips/cancellations; `staff-integration-final.log` |
| Final request-ID correction | Mismatch reproduced; all 18 staff checks pass afterward; `staff-request-id-before.log`, `staff-request-id-after.log`. Only this diagnostics change followed the full 214 run. |
| API units/build | 43/43 and clean compile; `staff-api-unit-final.log` |
| Fresh/upgrade schemas | 10/10 including migration012; `staff-authority-schema-tests.log` |
| Independent staff/schema review | 27/27 before the final contract assertion; `staff-schema-independent.log` |
| Admin transport/contracts/build | 15/15, typecheck and production build; `staff-admin-final.log` |
| Chromium | 6/6 with schema-validated synthetic responses; `staff-admin-browser.log` |
| Repository guards/tooling | Secret/contract/boundary checks and 11/11 tooling tests; `staff-repo-final.log` |
| Dependency audit | Zero reported vulnerabilities; `staff-dependency-audit.log` |

All artifacts are under ignored `artifacts/`. Tests use dedicated PostgreSQL test databases, random schemas and isolated Redis keys. The live phone database, Redis13 and private Firebase runtime remain unchanged. No real grant, provider/billing change, notification or production deployment occurred. The earlier phone/session [PR #75](https://github.com/agilandeenadhayalan/nightshift/pull/75) passed exact-head CI; this foundation needs its own CI result.

## Remaining acceptance

Integrate the real Firebase phone verifier, trusted native browser handoff, approved origin/session/recovery configuration and authenticated Redmi identity binding before enabling staff access. Then implement minimum-access queue/detail/evidence, owner-approved versioned review criteria, immutable decisions and durable entitlement/notification effects. The appointment does not approve a Listener application or permit known self-review. Backup/recovery and evidence/retention/appeal policy remain open. Neither #10 nor #14 is closed by this foundation. See [review plan](Staff_Review_Plan.md).
