# Staff access foundation

Recorded 21 November 2026 for the #10 prerequisite to #14. This document records the PR #76 foundation; see the subsequent [embedded integration](Embedded_Staff_Verification.md) for the real adapter and native browser. The owner explicitly replaced the earlier MFA requirement with SMS OTP-only authentication, appointed themself initial reviewer and access administrator, selected the Redmi account, and requested staff pages inside NightShift's built-in browser. D26, FA-010 and the GitHub issue record that amendment. Customer and Listener remain the only app modes. At the PR #76 foundation checkpoint, live staff access had not been provisioned. Later on 21 November, the selected Redmi account was explicitly provisioned and the owner confirmed that the embedded workspace opens after fresh SMS sign-in; that actual result is recorded in the continuation.

## Implemented

Migration012 adds separate staff principals, permission grants, opaque-cookie sessions, short-lived challenges and immutable audits, with no live seed. Provider subject identifiers stay private; HMAC bindings and token/proof hashes support lookup and replay protection. The optional immutable linked app-account reference prepares known self-review checks without trusting client role claims.

The authority pins issuer/audience/tenant and provider-attested methods, checks recent authentication, queries current provider identity state, and revalidates local sessions/grants under a principal lock before sensitive actions. Grant changes, disablement and logout invalidate prior authority. Logout revokes all sessions for that staff principal; customer authentication stays separate. Signed synthetic SMS proofs exercise the provider interface. In the PR #76 foundation, the normal application bootstrap always constructed unavailable staff authority, with no environment-selectable fixture, default administrator or self-enrollment route. The subsequent embedded integration added explicit private configuration of the real adapter; configuration alone grants no staff permissions.

Challenge/exchange/logout require exact-origin and CSRF checks. Credentials use host-only Secure/HttpOnly/SameSite=Strict cookies; response CSRF tokens are for memory-only use. Provider work is bounded, including capacity retained until a timed-out underlying operation settles. The five staff routes have a separate public `@nightshift/contracts/staff.openapi.json`, checked for drift and excluded from the Customer/Listener Dart client. Error request IDs now match their response headers after a reproduced correlation regression was corrected.

The runnable Next.js session shell has a fixed-origin, bounded proxy that rejects redirects, unapproved Host/Origin values and non-staff credentials. It handles unavailable access, denied/expired sessions, permission display and logout. Lifecycle/expiry remove private state before revalidation. An uncertain logout retains that intent and cannot silently restore the previous view. Browser tests include stale responses, 360-pixel layout and 200% text/keyboard access.

At the PR #76 foundation checkpoint, the review entry was unavailable because that slice had no review/evidence/decision endpoints, real OTP adapter or Flutter embedded-browser entry. Active-session screenshots from that checkpoint use an isolated synthetic upstream, not the owner's account. Later implementation and actual enrollment evidence are linked below; the original fixture results remain historical evidence.

## Verification

| Check | Result and ignored artifact |
| --- | --- |
| Full backend regression | 214/214, zero failures/skips/cancellations; `staff-integration-final.log` |
| Final request-ID correction | Mismatch reproduced; all 18 staff checks pass afterward; `staff-request-id-before.log`, `staff-request-id-after.log`. Only this diagnostics change followed the full 214 run. |
| API units/build | 43/43 and clean compile; `staff-api-unit-final.log` |
| Fresh/upgrade schemas | 10/10 including migration012; `staff-authority-schema-tests.log` |
| Independent staff/schema review | 27/27 before the final contract assertion; `staff-schema-independent.log` |
| Admin transport/contracts/build | 15/15, typecheck and production build; `staff-admin-final.log` |
| Chromium | Initial local 6/6 passed, then Linux CI exposed a fallback-font overflow at 200% text. The layout fix reproduces and covers that case: 7/7 pass locally with strict document/element width checks; `staff-overflow-fix-browser.log`. |
| Repository guards/tooling | Secret/contract/boundary checks and 11/11 tooling tests; `staff-repo-final.log` |
| Dependency audit | Zero reported vulnerabilities; `staff-dependency-audit.log` |

All artifacts are under ignored `artifacts/`. Tests use dedicated PostgreSQL test databases, random schemas and isolated Redis keys. No real grant, provider/billing change, notification or production deployment occurred in this foundation. The earlier phone/session [PR #75](https://github.com/agilandeenadhayalan/nightshift/pull/75) passed exact-head CI. Foundation [PR #76](https://github.com/agilandeenadhayalan/nightshift/pull/76) subsequently passed all three jobs at `b37378549507717cb4f5706704aca876ba59a1ea`, run44797495100. Besides the font fix, that run corrects an hourly quota test: the old timing failure was reproduced, then all11 phone checks passed with a deterministic clock and reset-boundary coverage. Live phone database/runtime changes belong to the separately recorded continuation.

## Remaining acceptance

The [embedded continuation](Embedded_Staff_Verification.md) implements the real Firebase verifier and fixed-origin native browser handoff. On 21 November 2026, exact owner-supplied references bound the selected Redmi account through preview, explicit provisioning and a fresh no-additions verification. The four approved permissions were granted, and the owner confirmed the staff workspace opens inside NightShift after fresh SMS sign-in. A read-only server check corroborated the bound principal, permissions, session and audits. This completes that positive access path, not every #10 acceptance check.

Physical revocation, logout/reopen, background/expiry cleanup and recovery still need device evidence. A backup administrator and recovery procedure remain open. The [review plan](Staff_Review_Plan.md) links the implemented restricted reads and policy-gated decision workflow; a nonempty live queue and private playback, approved human review criteria, actual review effects, and evidence/retention/appeal policy remain separate gates. The appointment and grants do not approve a Listener application or permit known self-review. Neither #10 nor #14 is closed by this foundation or the positive opening alone.
