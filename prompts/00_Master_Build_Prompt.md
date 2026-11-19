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
