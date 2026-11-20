# Staff authentication and Listener review plan

Prepared 20 November 2026; updated 21 November after the owner's explicit decisions. The owner replaced #10's earlier MFA requirement with SMS OTP-only staff authentication, appointed themself initial reviewer and access administrator, selected the Redmi account, and requested staff pages inside NightShift's built-in browser. These decisions are recorded in D26 and the amended FA-010 specification. Staff remains a separate authorization boundary; Customer and Listener remain the only customer-facing modes. Live enrollment and the authenticated Redmi identity binding have not yet been performed.

## Acceptance and existing evidence

| Issue | Required outcome | Current implementation and remaining gap |
| --- | --- | --- |
| [#10 / FA-010](../github/issues/FA-010.md), depends on #9 | Opaque identity/device mapping; logout, revocation and suspension; owner-approved staff SMS OTP and separate permission grants. Verify forged roles, cross-user access and revoked API/socket sessions. | Customer session races are verified in PR #75. Separate staff authority, cookie/CSRF protocol and a Next.js session shell now have synthetic verification. The real phone verifier, in-app handoff and approved Redmi account binding remain to be integrated. OTP-only is not MFA. |
| [#14 / FA-014](../github/issues/FA-014.md), depends on #10 and #13 | Minimum-access review queue; reviewer, time, checks and reason; durable entitlement and notification effects. Unprivileged applicants cannot approve themselves; duplicate events cannot duplicate effects. | Private applications, consented samples and submission/withdrawal exist. No staff review service or runnable console exists. Human review criteria and reviewers remain unapproved. |

Relevant code boundaries:

- `apps/admin/` is now a runnable Next.js staff session shell with a protected proxy and synthetic browser tests. The normal API bootstrap keeps staff access unavailable. The Flutter embedded-browser entry and authenticated handoff are the next integration boundary; the session shell is not a Listener approval console.
- `apps/api/src/listener-applications.ts` already owns application drafts, submission, consent, private PCM WAV access and cleanup. Reuse those records and storage checks. A submitted application does not grant Listener entitlement.
- Migration003 provides the `draft → submitted → needs_information/approved/rejected/withdrawn` state machine and application/review ownership linkage. Migration008 provides sample metadata and consent history.
- `listener_reviews` currently records a free-text reviewer, approval boolean, reason and timestamp. It lacks a verified staff principal, structured checklist, evidence revision, deduplication boundary and append-only enforcement. Existing local-seed rows must remain identifiable as fictional legacy fixtures.
- `audit_events.actor_id` references ordinary app users. Staff auditing needs a distinct staff actor reference and immutable records; it must not manufacture an ordinary user to represent an operator.
- Existing `outbox_events.event_id` references `call_events`. Approval events need a separate domain outbox or an explicit generalization with compatibility tests. Do not insert pretend call events to reuse delivery.
- The customer Firebase verifier deliberately strips role/email claims and rejects tenant identities. Preserve that boundary; do not relax it to make staff authentication work.

## Minimal implementation sequence

### 1. Separate staff authority for #10

Create a provider adapter that returns the verified issuer, opaque subject binding, authentication time, expiry and provider-attested phone authentication method. Pin the configured issuer, audience and, if applicable, tenant. The owner selected single-factor SMS OTP; do not describe it as MFA. A newly issued token must not turn an old authentication time into a recent sign-in. Customer phone authentication can establish identity only after server verification; staff privileges must come from separately provisioned records.

Add staff principals, explicit permission grants and revocable staff sessions. Start with `listener.review.read`, `listener.review.evidence.read` and `listener.review.decide`; do not grant finance, support, safety or configuration powers implicitly. A provider claim or an email address is not a database permission grant. Disabled staff, changed grants and revoked sessions must fail sensitive actions after the transaction takes its staff-authority lock.

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
| Staff identity and recovery | SMS OTP-only and an in-app browser were selected. Define the fixed staff origin, authenticated native handoff, recent-sign-in/session limits and recovery/backup owner; integrate the real Firebase phone verifier. | Keep live staff authentication disabled until configured. Do not enable an additional MFA service or infer another spending approval. |
| People and permission grants | The owner is the initial reviewer and access administrator, using the Redmi account. Establish its authenticated identity binding; name a recovery delegate and record known linked app accounts/conflicts. Separate provider identities alone do not prove two different human people. | No live staff rows or grants yet. Use synthetic principals and explicit fixture permissions in isolated tests; known self-review must remain prohibited. |
| Review criteria and evidence policy | Approve a versioned age/identity/communication/content checklist, minimal accepted evidence, reviewer training/escalation, consent and retention rules, needs-information/rejection/appeal reasons, and notification channel/copy. Record the responsible safety/privacy owner. | Use a clearly labeled fixture checklist with synthetic applicants. No real applicant approval, verified badge, evidence-retention duration or professional sign-off is inferred. |

## Owner-selected authentication boundary

The earlier workforce/TOTP proposal is superseded by D26. The owner-selected phone factor does not confer staff authority by itself. Keep verified identity, explicit staff grants and the short-lived staff cookie separate. The current core verifies provider-attested methods through an adapter and rechecks both the current provider identity and local authority; its normal bootstrap remains unavailable until a real adapter and private policy are wired. Test fixtures are neither live OTP evidence nor an enrollment mechanism.

The in-app browser integration must keep proof/cookie material out of navigation URLs and browser storage, allow only the configured staff origin, and avoid a generic JavaScript bridge that could disclose app credentials. The exact native handoff is a remaining implementation task. Firebase controls its phone-verification challenge flow; embedding staff pages does not imply an embedded replacement for Firebase's verification challenge.

## Verification boundary

Local engineering can verify signed proof rejection for wrong issuer/audience, absent required phone method, stale authentication and revoked identities; forged roles and cross-user/evidence access; staff permission changes during a pending decision; CSRF/session isolation; known self-review rejection; conflicting reviewer decisions; withdrawal/deletion versus approval races; private-sample cleanup; immutable decision/audit records; and duplicate-event/worker-restart recovery with one entitlement and one notification effect. Use isolated PostgreSQL schemas and synthetic files/identities. Preserve all existing account, call, presence, financial and deletion regression checks.

Actual staff OTP sign-in, the authenticated Redmi binding, revocation/recovery, approved review criteria, real evidence handling and external notification delivery remain separate acceptance evidence. The initial reviewer/access-administrator appointment is confirmed; a backup and evidence policy remain open. Fixture success does not complete those gates or close #10/#14. This plan activates no staff access and changes no provider settings.
