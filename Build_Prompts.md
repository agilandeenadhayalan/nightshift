# NightShift — seven ready-to-use build prompts

Prepared 28 October 2026. Use the master prompt after putting the full pack in the intended new repository. Replace placeholders before use. These are instructions for future work, not evidence that work is complete.

---

# Master prompt — paste into Cursor, Copilot or Codex in the new repository

```text
You are implementing an independent adult conversation platform from this planning pack.

Apply the November launch requirements for OTP and connected-time earnings.
Read NightShift_Master_Plan.md, docs/Engineering_Contracts.md,
docs/UI_Screen_Specification.md, docs/Test_and_Launch_Plan.md,
docs/Sources_and_Research.md and github/issues.json before changing code.
Treat these as a proposed specification, not evidence that the product already exists.

Product: one Flutter app with customer and approved-listener roles; Android first;
Tamil and English; discover eligible listeners, opt-in matching, paid one-to-one audio,
credits, recents, favorites, reports, support and listener earnings/payouts.
Separate Next.js public website and protected admin. NestJS modular monolith,
PostgreSQL authoritative data and journal, Redis presence, worker/outbox, managed Agora
media, MSG91 branded OTP verified by NestJS, Firebase custom-token sign-in and FCM, approved store/payment channel.
No employer resources. No microservice decomposition or Kubernetes without a measured need.

First inspect the repository, applicable AGENTS.md, toolchains and existing code.
Report what exists and which prerequisites are missing. Preserve unrelated work.
If the repository is empty, execute FA-001 through FA-008 in dependency order.
After the foundation, select the next dependency-ready issue and complete a small
coherent change with its acceptance evidence. Do not claim all 64 are done at once.
Track FA IDs separately from actual GitHub issue numbers.

Start a minimal two-real-phone audio spike early using test credentials and scoped
server tokens. Do not wait for finished visual design to prove media feasibility.
Mocks and synthetic balances may enable local development, but cannot be silently
used as production payment, KYC, media or earnings implementations.

Invariants: one active call claim per participant across roles/devices; no ring charge;
server-owned rates/timers; no charge for disconnect gaps; integer units; append-only
balanced journals per currency/unit; unique purchase/event/billing/payout keys;
bounded credit reservation; tested provider-side media cutoff at exhaustion;
correct refund/reconciliation; approved listener required; immediate block enforcement.
Never let a frontend balance, timer, role or payment-success callback decide money.

Age/privacy/reporting/support are core. Publicly private aliases do not remove backend
verification. Do not promise zero fake profiles, guaranteed income, therapeutic care,
total recording prevention or readiness for millions without evidence.

Keep video, chat, coupons, iOS, analytics expansion, service extraction and AI behind
their later gates FA-057–064. Do not hide features from store review or claim an
unverified store/payment exemption. Consult dated primary vendor docs for SDK/API changes.

For each change provide: issue ID; concrete behavior delivered; changed files;
meaningful checks actually run; real-device/provider checks still needed;
migration/recovery notes; unresolved decisions; next dependency-ready issue.
Mark acceptance criteria complete only from observed evidence. Do not invent credentials,
approvals, deployments, test results or live user counts. No paid infrastructure purchase
or public launch is implied by this implementation prompt alone.
```

---

# Repository and issue setup prompt

Replace the owner before use. Suggested repository name is technical and not a cleared consumer brand.

```text
Create the planning foundation for OWNER/nightshift as a private independent
GitHub repository. OWNER is: <INSERT_EXACT_OWNER>.

Inspect the current workspace and authenticated GitHub account first. If that exact
repo already exists, inspect it and preserve its content. Do not use any employer repo.
If OWNER is still a placeholder, ask for the owner rather than choosing an organization.

Copy the supplied plan, docs, prompts, github issue specifications and scripts into
the chosen repo. Add a README that describes the project as planning/implementation
work and does not claim a live working app. Do not commit credentials, test customer
data or provider secrets. Preserve actual Markdown newlines.

Run the importer in dry-run mode and validate the 64 local IDs, dependency graph,
8 phase milestones, and 56-core/8-expansion split. Then, within this explicit setup
request, create the private repository if needed and import only P0 (FA-001–008)
using scripts/import_github_issues.py with --apply. Reuse existing markers on retry.
Do not create duplicate epics in addition to the phase milestones.

Commit the planning foundation on a dedicated branch and push it; open a draft PR
where the existing repository supports that workflow. For a brand-new empty repo,
create its initial planning branch/commit without fabricating a comparison base.
Do not overwrite a populated default branch or merge implementation changes.

Return actual repository/branch/PR URLs as applicable, issue URLs, completed checks,
and anything that could not be created. Never say issues exist based only on local JSON.
```

To import all phases instead, explicitly change “only P0” to “P0–P7, all 64 issues”. The script defaults to P0 and dry-run for reviewability.

---

# One-issue implementation prompt

```text
Implement <FA-ID> in this repository. Read its body in github/issues/<FA-ID>.md
and use github/import_map.json, if present, to locate its actual GitHub issue.

Read applicable AGENTS.md plus the master plan and relevant contracts/UI/test documents.
Inspect existing behavior and dependency evidence before editing. Do not assume an
upstream issue is implemented merely because it is closed or has a placeholder file.
If a dependency is missing, implement a clearly scoped prerequisite only if authorized,
or report the exact dependency and continue independent work on this issue.

Use the agreed stack. Keep domain logic on the server and preserve wallet/call/privacy
invariants. Use current primary provider docs. Keep migrations backward compatible,
idempotent event handling explicit, and test-only providers impossible in production.
Do not refactor unrelated modules or add frameworks just to complete this task.

Build the end-to-end behavior needed for this issue: API, state, UI, error handling,
telemetry and migration where applicable. Include loading/empty/error/offline states.
Write and run meaningful tests for concurrency, security or money changes, and the
issue's acceptance cases. UI copy/styling alone needs proportionate visual validation.

Prepare a reviewable PR with the concrete problem and resulting behavior, verified
checks, migration/recovery steps and external checks still pending. Reference the
actual GitHub issue only when resolved from evidence. Do not auto-close unverified
criteria, auto-merge, publish or spend money as part of this issue prompt.

Finish with what works, what was actually tested, remaining blockers and the next
dependency-ready FA ID. A missing API key is a configuration blocker, not a reason
to replace real functionality with a fake success screen.
```

---

# First useful demonstration prompt

```text
Build and verify the smallest real two-phone audio path for nightshift.
Read the master plan, engineering contracts and FA-006,009–015,017,021–023,025–028.

Deliver an Android Flutter test build where account A is a customer, account B is a
manually approved test listener, both select Tamil, and B enables availability.
A sees B, starts one invitation, B accepts, and both hear one another through Agora.
Use server-generated per-session/UID RTC tokens, authenticated APIs and a durable
session record. One active claim per participant must be enforced in PostgreSQL.
Use only explicit sandbox balances; no live purchase or payout in this demo.

Cover accept, decline, timeout, cancel, microphone denial, app backgrounding,
network disconnect/reconnect and end from either party. Ringing and disconnected
time must remain distinct from connected time. Record the real session ID and
safe diagnostic events, never conversation audio or full phone numbers.

Test on two real Android devices, one Wi-Fi and one mobile network, if devices are
available. If they are not, finish the implementation and automated checks and provide
exact manual steps; state honestly that real-device verification is still pending.
Do not call emulator mocks a successful real two-phone test.

Provide build/setup commands, required environment-variable names without values,
test evidence, known device/SDK limits and a short video-call expansion note.
Prove media capability before spending time on coupons, games or polished animations.
```

---

# Design prompt for the later screenshot pass

```text
Design the approved Android audio MVP using docs/UI_Screen_Specification.md.
Use the supplied redacted screenshots only as interaction references. Build an original
visual identity and layout; do not copy FRND/Dostt logos, proprietary illustrations,
wording, trade dress or fabricated claims.

Start with U01–U10 and L04–L06: onboarding, language, directory, pre-call price,
matching, invitation and active call. Then wallet, receipts, recents, earnings,
support, report and deletion. Keep Customer navigation Discover/Recents/Profile
and Listener navigation Availability/Earnings/Profile.

For each screen provide normal/loading/empty/error/offline/permission-denied states.
Differentiate available, busy and offline with text and icons. Disable a busy card
immediately but avoid reordering under a finger. Show rate, balance and affordable
minutes before calling. No hidden upsell, false trust badges or automatic messages.
Support Tamil, English, screen readers, large text and comfortable tap targets.

Deliver design tokens, reusable components, screen map and a clickable flow or Flutter
implementation as requested in the design task. Label test data. Map each screen to
its FA issues and list new decisions, without treating a visual prototype as a working
payment or media system. Do not expand into games/AI/video until separately scheduled.
```

---

# Money and call correctness review prompt

```text
Review the implemented call/payment system against docs/Engineering_Contracts.md and
FA-022,027,028,033–043,050. Inspect code and execute appropriate tests; do not rely on
README claims. Do not perform a live payment or payout without that specific task scope.

Trace one purchase to verified receipt, credit lot, balanced journal, spend hold,
connected interval, customer debit, listener earning, payout and refund. Verify
integer units, rounding, per-unit journal conservation and deterministic idempotency.
Confirm the client cannot dictate money, roles, elapsed duration or purchase success.

Race two callers for one listener; race two calls from one customer; race accept/cancel.
Replay/reorder payment, RTC and payout notifications. Inject process/DB/Redis/provider
failure and verify recovery. Test unknown payout results without issuing a blind retry.

Verify that media cannot continue when credit authorization expires even if a modified
client ignores hang-up and reuses old tokens. A token expiry assumption alone is not
evidence. Verify no charge during ringing or disconnect gaps and a bounded, clearly
funded reconnect grace.

Return findings ordered by severity with file references and reproduction steps.
State which checks used real PostgreSQL, provider sandbox or actual devices, and which
remain untested. Treat duplicate money, negative spendable balance, unauthorized media
or unbounded unpaid continuation as paid-launch blockers. Propose small concrete fixes.
```

---

# Release-readiness prompt

```text
Assess the Android paid-audio MVP using docs/Test_and_Launch_Plan.md and FA-049–056.
This is a readiness review, not permission to publish or purchase infrastructure.

Verify actual implementations and evidence for every launch gate: adult/role controls,
call quality and concurrency, exact billing, receipt/payout reconciliation, refund flow,
privacy/deletion, child-safety/reporting, support coverage, credentials, backups,
restore, observability, cost controls, approved payment route and Play account testing.
Read current official store/provider rules and record date and account applicability.

Run allowed automated/security/load checks and document any real-device/provider
checks that cannot be executed. Verify a human listener roster and operational owner;
do not infer these from code. Check listing and policy copy for accurate functionality
and no guaranteed privacy, earnings or fake user claims.

Produce a concrete go/no-go report with evidence links, blockers, accountable owners,
the capped launch configuration and rollback procedure. Distinguish complete, tested,
externally approved and still pending. No fixed date overrides an unresolved money,
security, provider or store-review blocker.
```

