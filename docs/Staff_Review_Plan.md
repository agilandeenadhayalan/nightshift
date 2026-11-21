# Staff authentication and Listener review plan

Prepared 20 November 2026; updated 21 November after the owner's explicit decisions and selected-account enrollment. The owner replaced #10's earlier MFA requirement with SMS OTP-only staff authentication, appointed themself initial reviewer and access administrator, selected the Redmi account, and requested staff pages inside NightShift's built-in browser. These decisions are recorded in D26 and the amended FA-010 specification. Staff remains a separate authorization boundary; Customer and Listener remain the only customer-facing modes. Enrollment and the authenticated Redmi binding were pending at the initial planning checkpoint. On 21 November, exact owner-supplied references were explicitly provisioned, and the owner confirmed the embedded workspace opens after fresh SMS sign-in. See [the dated device evidence](Embedded_Staff_Verification.md).

## Acceptance and existing evidence

| Issue | Required outcome | Current implementation and remaining gap |
| --- | --- | --- |
| [#10 / FA-010](../github/issues/FA-010.md), depends on #9 | Opaque identity/device mapping; logout, revocation and suspension; owner-approved staff SMS OTP and separate permission grants. Verify forged roles, cross-user access and revoked API/socket sessions. | Customer session races are verified in PR #75. Separate staff authority, cookie/CSRF protocol and a Next.js session shell have synthetic verification. The real Firebase adapter/native browser have engineering evidence, followed on 21 November by explicit Redmi provisioning and the owner's confirmation of an embedded session after fresh SMS sign-in. A scoped server read corroborated the bound principal, exact grants and session/audits. Physical revocation, logout/reopen, background/expiry and recovery checks remain. See [embedded verification](Embedded_Staff_Verification.md). OTP-only is not MFA. |
| [#14 / FA-014](../github/issues/FA-014.md), depends on #10 and #13 | Minimum-access review queue; reviewer, time, checks and reason; durable entitlement and notification effects. Unprivileged applicants cannot approve themselves; duplicate events cannot duplicate effects. | The [protected read slice](Staff_Review_Read_Verification.md) adds submitted queue, separately permissioned detail/sample playback and immutable access audit. Draft and editable needs-information evidence stay excluded. The [decision continuation](Staff_Review_Decisions_Verification.md) implements policy-versioned immutable decisions, recoverable receipts and durable entitlement/in-app notification effects. Missing approved policy keeps decisions disabled. The initial reviewer now has explicit grants and has opened the workspace; nonempty live queue/playback, approved human review criteria and actual review/effect evidence remain. |

Relevant code boundaries:

- `apps/admin/` provides the staff session shell and protected submitted-application reads, with separate permission checks and synthetic browser tests. Staff access defaults off; explicit configuration selects the real adapter and source-app binding. The Flutter embedded browser and native cookie installer are implemented. The decision form requires an explicitly approved policy; normal configuration remains unable to approve applications while that policy is absent.
- `apps/api/src/listener-applications.ts` already owns application drafts, submission, consent, private PCM WAV access and cleanup. Reuse those records and storage checks. A submitted application does not grant Listener entitlement.
- Migration003 provides the `draft → submitted → needs_information/approved/rejected/withdrawn` state machine and application/review ownership linkage. Migration008 provides sample metadata and consent history.
- At initial planning, legacy `listener_reviews` recorded a free-text reviewer, approval boolean, reason and timestamp without the structured staff-decision boundary. The decision continuation adds separate immutable policy/checklist/material-bound records; existing local-seed rows remain fictional legacy fixtures.
- Legacy `audit_events.actor_id` references ordinary app users. The staff continuation uses separate immutable staff auditing; it does not manufacture an ordinary user to represent an operator.
- Legacy `outbox_events.event_id` references `call_events`. The decision continuation adds separate review effects with stable identities; it does not insert pretend call events to reuse delivery.
- The customer Firebase verifier deliberately strips role/email claims and rejects tenant identities. Preserve that boundary; do not relax it to make staff authentication work.

## Minimal implementation sequence (recorded design)

The engineering continuations linked above implement this sequence. The original design below remains the boundary for further work; implementation and synthetic checks do not substitute for approved human criteria or actual review/device evidence.

### 1. Separate staff authority for #10

Create a provider adapter that returns the verified issuer, opaque subject binding, authentication time, expiry and provider-attested phone authentication method. Pin the configured issuer, audience and, if applicable, tenant. The owner selected single-factor SMS OTP; do not describe it as MFA. A newly issued token must not turn an old authentication time into a recent sign-in. Customer phone authentication can establish identity only after server verification; staff privileges must come from separately provisioned records.

Add staff principals, explicit permission grants and revocable staff sessions. Review permissions are `listener.review.read`, `listener.review.evidence.read` and `listener.review.decide`; the owner separately authorized `staff.access.manage` for the initial access administrator. These are the four explicitly provisioned permissions. Do not grant finance, support, safety or configuration powers implicitly. A provider claim or an email address is not a database permission grant. Disabled staff, changed grants and revoked sessions must fail sensitive actions after the transaction takes its staff-authority lock.

Protect `/v1/admin/...` with a separate guard. Reject customer development tokens and customer Firebase phone sessions even if they contain role-looking fields. Keep browser credentials in secure HttpOnly cookies, use same-origin administration with CSRF/origin checks, and avoid token-bearing URLs or browser local storage. Session lifetime, reauthentication and recovery policy must be explicit before activation.

Use the existing verification library and error-handling patterns where appropriate, but do not route staff through customer enrollment, devices, wallet grants or Customer/Listener mode selection. No first-login administrator, shared development access key, default staff seed or production-configurable fixture bypass is permitted.

### 2. Restricted review console for #14

Implement only staff OTP sign-in, a bounded submitted/needs-information queue, application detail, explicitly authorized sample playback, and a reasoned review form. Queue summaries should contain only the application identifier, public alias, requested languages, state and submission time. Detail access may reveal the submitted bio, topics, consented review sample and necessary review facts. Do not expose phone numbers, DOB, financial information or unrelated evidence by default. Audit evidence access without copying audio, credentials or private content into logs.

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
| Staff identity and recovery | SMS OTP-only, the fixed private staff origin, native handoff and bounded session/recent-authentication configuration are implemented. The selected Redmi opening is verified; define the recovery procedure and backup owner, and exercise physical revocation/logout/expiry behavior. | Unconfigured deployments stay disabled. The private positive opening does not establish recovery. Do not enable an additional MFA service or infer another spending approval. |
| People and permission grants | The owner is the initial reviewer and access administrator. The selected Redmi identity was explicitly bound and provisioned with exactly four approved permissions on 21 November. Name a recovery delegate and record known linked app accounts/conflicts. Separate provider identities alone do not prove two different human people. | Other accounts receive no implicit grant. Continue using isolated synthetic principals for adversarial tests; known self-review remains prohibited. No backup administrator is inferred from the initial enrollment. |
| Review criteria and evidence policy | Approve a versioned age/identity/communication/content checklist, minimal accepted evidence, reviewer training/escalation, consent and retention rules, needs-information/rejection/appeal reasons, and notification channel/copy. Record the responsible safety/privacy owner. | Use a clearly labeled fixture checklist with synthetic applicants. No real applicant approval, verified badge, evidence-retention duration or professional sign-off is inferred. |

## Owner-selected authentication boundary

The earlier workforce/TOTP proposal is superseded by D26. The owner-selected phone factor does not confer staff authority by itself. Keep verified identity, explicit staff grants and the short-lived staff cookie separate. The current core verifies provider-attested methods through an adapter and rechecks both the current provider identity and local authority. Unconfigured deployments remain unavailable; the private runtime has the real adapter and explicit staff-authentication configuration. The actual Redmi enrollment used the reviewed operator preview/apply flow, not a fixture or self-grant. Test fixtures are neither live OTP evidence nor an enrollment mechanism.

The in-app browser integration must keep proof/cookie material out of navigation URLs and browser storage, allow only the configured staff origin, and avoid a generic JavaScript bridge that could disclose app credentials. The native-only proxy and dedicated cookie installer implement this boundary. The owner-confirmed Redmi opening and bound server session provide positive device-session evidence; physical negative/recovery cases remain. Firebase controls its phone-verification challenge flow; embedding staff pages does not imply an embedded replacement for Firebase's verification challenge.

## Verification boundary

Local engineering can verify signed proof rejection for wrong issuer/audience, absent required phone method, stale authentication and revoked identities; forged roles and cross-user/evidence access; staff permission changes during a pending decision; CSRF/session isolation; known self-review rejection; conflicting reviewer decisions; withdrawal/deletion versus approval races; private-sample cleanup; immutable decision/audit records; and duplicate-event/worker-restart recovery with one entitlement and one notification effect. Use isolated PostgreSQL schemas and synthetic files/identities. Preserve all existing account, call, presence, financial and deletion regression checks.

The authenticated Redmi binding, explicit four-permission provisioning and owner-confirmed opening after fresh SMS sign-in now have actual evidence. Physical revocation, staff logout followed by manual fresh sign-in and reopening, background/session-expiry cleanup and recovery remain separate checks. A nonempty live review queue, private sample playback, approved human criteria, actual decisions/effects, evidence retention/appeal rules and external notification delivery remain unverified or unresolved. The initial reviewer/access-administrator appointment and enrollment do not supply a backup or approve a Listener. Neither fixture success nor the positive opening closes #10/#14. This documentation update performs no grant or provider change.
