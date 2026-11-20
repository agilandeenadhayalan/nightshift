# Staff authentication and Listener review plan

Prepared 20 November 2026. This is a proposed implementation boundary for #10 and #14, not staff enrollment, permission approval, verification of an applicant, or authorization to deploy. The [decision register](Decision_Register.md), especially D04–06, D10–11 and D18–19, remains authoritative. NightShift has exactly two customer-facing modes: Customer and Listener. Staff uses a separate console.

## Acceptance and existing evidence

| Issue | Required outcome | Current implementation and remaining gap |
| --- | --- | --- |
| [#10 / FA-010](../github/issues/FA-010.md), depends on #9 | Opaque identity/device mapping; logout, revocation and suspension; separate staff MFA and role permissions. Verify forged roles, cross-user access and revoked API/socket sessions. | Customer identity, device and revocation mechanisms already exist. No staff identity, session, grant or MFA authorization boundary exists. Live staff MFA evidence cannot be inferred from customer phone sign-in. |
| [#14 / FA-014](../github/issues/FA-014.md), depends on #10 and #13 | Minimum-access review queue; reviewer, time, checks and reason; durable entitlement and notification effects. Unprivileged applicants cannot approve themselves; duplicate events cannot duplicate effects. | Private applications, consented samples and submission/withdrawal exist. No staff review service or runnable console exists. Human review criteria and reviewers remain unapproved. |

Relevant code boundaries:

- `apps/admin/README.md` is a placeholder. The repository reserves a separate Next.js operator UI; register it as a workspace only when it becomes runnable.
- `apps/api/src/listener-applications.ts` already owns application drafts, submission, consent, private PCM WAV access and cleanup. Reuse those records and storage checks. A submitted application does not grant Listener entitlement.
- Migration003 provides the `draft → submitted → needs_information/approved/rejected/withdrawn` state machine and application/review ownership linkage. Migration008 provides sample metadata and consent history.
- `listener_reviews` currently records a free-text reviewer, approval boolean, reason and timestamp. It lacks a verified staff principal, structured checklist, evidence revision, deduplication boundary and append-only enforcement. Existing local-seed rows must remain identifiable as fictional legacy fixtures.
- `audit_events.actor_id` references ordinary app users. Staff auditing needs a distinct staff actor reference and immutable records; it must not manufacture an ordinary user to represent an operator.
- Existing `outbox_events.event_id` references `call_events`. Approval events need a separate domain outbox or an explicit generalization with compatibility tests. Do not insert pretend call events to reuse delivery.
- The customer Firebase verifier deliberately strips role/email claims and rejects tenant identities. Preserve that boundary; do not relax it to make staff authentication work.

## Minimal implementation sequence

### 1. Separate staff authority for #10

Create a provider adapter that returns a verified staff issuer, opaque subject binding, authentication time, expiry and evidence of MFA used for that sign-in. Pin the configured issuer, audience and, if applicable, tenant. Enrollment of an MFA factor alone is not evidence that the current session used it. A newly issued token must not turn an old authentication time into a recent step-up.

Add staff principals, explicit permission grants and revocable staff sessions. Start with `listener.review.read`, `listener.review.evidence.read` and `listener.review.decide`; do not grant finance, support, safety or configuration powers implicitly. A provider claim or an email address is not a database permission grant. Disabled staff, changed grants and revoked sessions must fail sensitive actions after the transaction takes its staff-authority lock.

Protect `/v1/admin/...` with a separate guard. Reject customer development tokens and customer Firebase phone sessions even if they contain role-looking fields. Keep browser credentials in secure HttpOnly cookies, use same-origin administration with CSRF/origin checks, and avoid token-bearing URLs or browser local storage. Session lifetime, reauthentication and recovery policy must be explicit before activation.

Use the existing verification library and error-handling patterns where appropriate, but do not route staff through customer enrollment, devices, wallet grants or Customer/Listener mode selection. No first-login administrator, shared development access key, default staff seed or production-configurable fixture bypass is permitted.

### 2. Restricted review console for #14

Implement only MFA sign-in, a bounded submitted/needs-information queue, application detail, explicitly authorized sample playback, and a reasoned review form. Queue summaries should contain only the application identifier, public alias, requested languages, state and submission time. Detail access may reveal the submitted bio, topics, consented review sample and necessary review facts. Do not expose phone numbers, DOB, financial information or unrelated evidence by default. Audit evidence access without copying audio, credentials or private content into logs.

Add application/evidence revisions and require an expected revision for a decision. An approval must name a versioned checklist, record each required check and its result, and cite minimal evidence references. The applicable checklist and actual human findings cannot be synthesized from an application's existence. A voice sample does not prove identity, age or gender, and self-declared adulthood must not be labeled verified adulthood.

Lock in a documented order: staff authority, applicant owner, application and relevant evidence. Recheck staff permission, application state/revision, current account restrictions and material consent before committing. Refuse stale evidence, withdrawn/deleted applications, missing required checks and known self-review. Preserve the existing applicant-owner lock order used by upload, withdrawal and deletion.

Record immutable decisions and reason codes. Preserve legacy fixture reviews without presenting them as staff-verified decisions. Do not copy the private proposed nickname into the public profile unless a distinct recorded moderation decision authorizes it. A request for more information should name the missing checks rather than create a partial approval.

### 3. Durable entitlement and notification effects

Commit the review decision and a minimal domain event together. Give entitlement processing and notification processing stable event identities and database uniqueness constraints. Retrying a decision or delivering an event twice must produce one effective grant and one notification record. Do not use delivery success as proof that an applicant was reviewed.

Revalidate current account deletion/suspension/adult restrictions before applying an entitlement. Keep `users.listener_approved` as the existing compatibility projection, with an auditable source decision, so the availability, discovery and call guards continue to work. Approval must not turn availability on or create money balances.

Consent withdrawn before a decision prevents using that sample. Existing code permits withdrawal of review materials after an approved/rejected outcome while preserving the outcome. Preserve that behavior unless an explicitly approved policy changes it; do not invent a requirement to retain audio indefinitely to keep an entitlement.

A locally verifiable first delivery target is a durable owner-only in-app notification/status record. External push delivery, templates and recovery require the selected notification channel and its own evidence; an outbox row alone is not delivered FCM evidence. No real notification is sent while building synthetic tests.

## Three owner decision bundles

| Decision | Concrete choices and information needed | Safe behavior while unresolved |
| --- | --- | --- |
| Staff identity and recovery | Identify an existing workforce MFA issuer, or authorize a dedicated Firebase/Identity Platform staff configuration using a supported first factor plus MFA. Specify the project/tenant or issuer, admin origin, enrollment process, factor policy, session/step-up limits and recovery/backup owner. | Implement the adapter contract and signed fixtures; keep live staff authentication disabled. Do not modify the customer project or purchase/enable a service. |
| People and permission grants | Name the initial reviewer(s), who may grant/revoke access, a recovery delegate, and which people may view evidence versus decide applications. Record any linked app accounts and conflicts of interest so known self-review is rejected. Separate provider identities alone do not prove two different human people. | No live staff rows or grants. Use synthetic principals and explicit fixture permissions in isolated tests only. |
| Review criteria and evidence policy | Approve a versioned age/identity/communication/content checklist, minimal accepted evidence, reviewer training/escalation, consent and retention rules, needs-information/rejection/appeal reasons, and notification channel/copy. Record the responsible safety/privacy owner. | Use a clearly labeled fixture checklist with synthetic applicants. No real applicant approval, verified badge, evidence-retention duration or professional sign-off is inferred. |

## Provider facts checked on 20 November 2026

Firebase's current documentation states that TOTP MFA requires Firebase Authentication with Identity Platform and a supported first factor; phone authentication and custom-token authentication are excluded as first factors. Verified email is also required. Consequently, the app's existing Firebase Phone Authentication flow is not itself the proposed staff MFA implementation. A dedicated staff project/tenant is an architectural option requiring an owner decision, not a provider prerequisite asserted by this plan. [Firebase TOTP MFA](https://firebase.google.com/docs/auth/web/totp-mfa).

Firebase exposes reserved second-factor information and `auth_time` in verified ID tokens. Refreshed tokens have newer issuance times but retain the authentication time of their sign-in session. Validate the provider proof server-side rather than accepting a client-provided `mfa: true`. [Decoded ID token reference](https://firebase.google.com/docs/reference/admin/node/firebase-admin.auth.decodedidtoken).

Firebase also documents server-side session cookies, revocation checking and recent-authentication checks at session establishment. These are available building blocks if that provider option is selected; they do not replace NightShift's explicit staff grants or CSRF protection. [Session-cookie guidance](https://firebase.google.com/docs/auth/admin/manage-cookies).

## Verification boundary

Local engineering can verify signed proof rejection for wrong issuer/audience, absent MFA, stale authentication and revoked identities; forged roles and cross-user/evidence access; staff permission changes during a pending decision; CSRF/session isolation; known self-review rejection; conflicting reviewer decisions; withdrawal/deletion versus approval races; private-sample cleanup; immutable decision/audit records; and duplicate-event/worker-restart recovery with one entitlement and one notification effect. Use isolated PostgreSQL schemas and synthetic files/identities. Preserve all existing account, call, presence, financial and deletion regression checks.

Actual staff MFA enrollment, sign-in, revocation and recovery; authorized reviewer appointments; approved review criteria; real evidence handling; and external notification delivery remain separate acceptance evidence. Fixture success does not complete those gates or close #10/#14. This plan activates no staff access and changes no provider settings.
