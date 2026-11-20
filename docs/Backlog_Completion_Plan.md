# Backlog completion plan

Prepared 20 November 2026 (Asia/Calcutta). Scope: all 64 product issues, FA-001 through FA-064 / GitHub #1–64. GitHub #65 is a pull request, not an additional product issue. This plan maps remaining work; it does not mark acceptance criteria complete or replace [Issue_Status.md](Issue_Status.md).

Sources reviewed: every issue's acceptance and verification arrays in [github/issues.json](../github/issues.json), [master plan](../NightShift_Master_Plan.md), [engineering contracts](Engineering_Contracts.md), current decision/evidence documents and the preserved owner edits in the original checkout. Individual issue files linked below remain the acceptance authority. New results must be recorded against the exact code/build tested.

NightShift remains one mobile application with exactly Customer and Listener modes, one shared backend/domain and separate staff tooling. The authorized implementation work can continue using test credits and controlled fixtures. No production unlock, spending, provider approval, legal conclusion, issue closure or merge is inferred from this plan.

## Starting evidence and limits

Repository/CI/schema foundations have recorded engineering evidence for #4/#5/#7. Scope and economics documents exist for #1/#3 but do not supply missing owner decisions. Generated Dart contracts, the Android app and durable shared test backend are implemented. The first two-phone foreground audio path passed, including both-party hangup and persistent history; subsequent reconnect behavior and build-specific audible results must retain their documented qualifications. See [device evidence](Device_Debug_2026-11-20.md).

Private video is implemented by the owner's later instruction, with proposed test pricing, explicit camera consent and feature gating. The recorded two-phone result includes user-confirmed video/voice, camera switching, camera-off capture shutdown, Listener hangup and matching histories. Reconnect causes, camera re-enable, the remaining interruption/fallback/device cases and provider cost reconciliation remain open. That subset does not close #57/#58's public-release dependencies. See [Video_Calling.md](Video_Calling.md). Authentication provider foundations exist; subsequent #9–12 work is an active continuation, not presumed completed by this planning document.

The live issue register and latest implementation evidence determine current status. Counts in an earlier audit are snapshots and must not be reused as a completion percentage. A subset may be useful and tested while the broader issue remains open.

## How to execute while dependencies remain open

For each issue, separate (1) locally executable code/contract/test work, (2) integration with completed upstream engineering, and (3) owner, provider, device or operational evidence. Build and test independent parts now; retain the named dependency on the integration/acceptance checklist. A fixture is never an implicit substitute for a missing production dependency.

An issue can be presented as fully verified only when every acceptance and verification item has attributable evidence, its required dependency evidence exists and no material failure remains. Record PR review/merge and GitHub closure separately. Do not use closing keywords on a partial implementation.

| Work lane | Work that can proceed now | Prerequisite before its downstream acceptance passes |
|---|---|---|
| Identity and mobile onboarding | Finish #9 server/client token exchange and failure UX; then #10 device/session authorization, #11 adult profile checks and #12 localized preferences in that order. Use local fixtures for regression tests. | #6 branded SMS/provider evidence; #8 real-phone accessibility; actual staging identity exchange; separately protected staff authorization for the full #10 scope. |
| Governance and provider preparation | Resolve the concrete questions in [Launch_Decisions_Required.md](Launch_Decisions_Required.md); prepare account-specific evidence and sandbox checklists. | Actual named owners, approved scopes and provider/Console status, not assumptions. |
| Commerce design and domain | Review #33 rate/quote contracts and #34 unit/lot/hold invariants with synthetic values after #7; prepare property/concurrency tests. | #2/#3 route, catalogue and economics decisions before approved real prices; #35 provider sandbox before purchases can be called verified. |
| Current media defects | Instrument and reproduce reconnect/readiness failures; retain passing local regression cases for #26–28. Prepare #25 enforcement probe using already authorized test scope. | Exact-build physical results, verified provider-event/termination behavior and later financial dependencies for paid cutoff. |
| Review/safety/operations preparation | Draft private upload contracts, staff permission matrix, consent/retention choices and synthetic escalation cases. | Integrate #13/#14 only after identity/profile/languages; #45 after its call/history dependencies; real reviewers, approved retention and staffed coverage before external use. |

Parallel lanes may prepare designs or isolated tested components, but cannot activate a dependent feature or claim full acceptance early. Shared API/schema/client changes must be coordinated so all app consumers use the same versioned contract. Keep credentials, local databases, build outputs and provider evidence containing personal data out of Git.

## Exact acceptance dependency waves

These are topological layers computed from the checked-in dependency arrays, not calendar days and not a claim that all work in an earlier layer is unfinished. Items in a row can pass their dependency gate in parallel once their own listed predecessors are satisfied. Existing verified evidence can be reused when still applicable. Local preparatory work above may advance without falsely passing the gate.

| Wave | Issues eligible together after predecessor evidence |
|---|---|
| W00 | #1 |
| W01 | #2, #4 |
| W02 | #3, #5, #6, #7 |
| W03 | #8, #33 |
| W04 | #9, #34 |
| W05 | #10 |
| W06 | #11, #35 |
| W07 | #12, #16 |
| W08 | #13 |
| W09 | #14 |
| W10 | #15 |
| W11 | #17 |
| W12 | #18 |
| W13 | #19, #21 |
| W14 | #20, #22 |
| W15 | #23, #25 |
| W16 | #24, #26 |
| W17 | #27 |
| W18 | #28, #29, #31 |
| W19 | #30, #32 |
| W20 | #36, #37, #45 |
| W21 | #38, #41 |
| W22 | #39, #42 |
| W23 | #40, #47 |
| W24 | #43, #48 |
| W25 | #44, #46, #49, #50 |
| W26 | #51, #52, #53 |
| W27 | #54 |
| W28 | #55 |
| W29 | #56 |
| W30 | #57, #59, #60, #61, #62 |
| W31 | #58, #63, #64 |

## Remaining work by issue

“Engineering” below means work that can be implemented or prepared locally, then integrated in the dependency order. “External/exit” identifies evidence beyond that work or the decisive full-issue check. It does not imply an external approval is required for ordinary reversible coding. Read each linked issue for all acceptance criteria; these rows identify the next completion target without weakening them.

### Foundation and identity

| Issue | Depends on | Engineering completion target | External or decisive exit evidence |
|---|---|---|---|
| [#1 Scope](../github/issues/FA-001.md) | None | Reconcile core/deferred scope and preserve owner decisions. | Named product/finance/safety accountability; original-transcript review; confirm external account/source independence. |
| [#2 Store/payment route](../github/issues/FA-002.md) | #1 | Dated primary-policy comparison and concrete funds-flow packet. | Actual Play account/testing facts; chosen route; responsible specialist review and unresolved conditions recorded. |
| [#3 Economics](../github/issues/FA-003.md) | #1, #2 | Update scenario inputs and proposed spend/trial/top-up/payout limits; retain negative-contribution rejection. | Approved price/pay/caps and monitoring owner; actual fee/tax/provider assumptions. |
| [#4 Monorepo](../github/issues/FA-004.md) | #1 | Preserve verified layout, boundaries, pins and clean-checkout instructions. | Revalidate fresh checkout if setup changes; review/merge status stays separate. |
| [#5 CI](../github/issues/FA-005.md) | #4 | Preserve isolated checks, scans and deliberate-failure evidence on changed code. | Required checks green; do not claim branch protection configured from guidance alone. |
| [#6 Provider spike](../github/issues/FA-006.md) | #4 | Maintain local stack, secret injection and nonproduction-only adapters. | Branded real-SIM OTP, owner test projects, scoped-token two-device media and provider cutoff feasibility. |
| [#7 Contracts/schema](../github/issues/FA-007.md) | #1, #4 | Keep migrations, generated client and incompatibility checks valid through additions. | Empty/representative upgrades and drift checks; existing foundation evidence does not complete commerce workflows. |
| [#8 Flutter foundation](../github/issues/FA-008.md) | #4, #7 | Complete remaining reusable states and navigation/localization regressions. | Real-phone large text and TalkBack reading order. |
| [#9 Phone auth](../github/issues/FA-009.md) | #6, #7, #8 | Finish MSG91 server verification → one UID → Firebase custom/ID token exchange; replay/quota/error UX. | Owner staging configuration, real branded delivery and invalid/expired/reused-token results; no development bypass in production. |
| [#10 Sessions/roles](../github/issues/FA-010.md) | #9 | Bind identity/device sessions; revoke HTTP/sockets; separate staff MFA and role grants. | Forgery/cross-user/revocation checks; actual staff identity/MFA configuration before staff access. |
| [#11 Adult profile](../github/issues/FA-011.md) | #8, #10 | Private DOB/phone, safe avatar/nickname, age-boundary and inconsistent-update handling. | Approved adult-assurance policy; self-declaration never labeled verified identity. |
| [#12 Languages](../github/issues/FA-012.md) | #11 | Controlled speaking codes, fallback/localized resources and persisted discovery filters. | Long Tamil/device checks; no undisclosed location proxy. |
| [#13 Applications](../github/issues/FA-013.md) | #10, #11, #12 | Private validated/time-limited uploads and idempotent draft/submission/review states. | Approved evidence/retention choice; cross-user/interrupted-upload checks. |
| [#14 Review console](../github/issues/FA-014.md) | #10, #13 | Separate authorized review queue, reasoned audit and durable entitlement/notification. | Named reviewers; no self-approval; duplicate events create one entitlement/notification effect. |
| [#15 Mode/availability](../github/issues/FA-015.md) | #14 | Finish approval entitlement, reservation/call switching lock and desired/reachable split. | Two-device concurrent switching; direct unapproved API rejection. |
| [#16 Consent/deletion](../github/issues/FA-016.md) | #10, #11 | Versioned purpose consent, step-up deletion and synthetic retention-hold/eventual-erasure workflow. | Reviewed credit/earnings/deletion effect and retention policy; cross-account denial. |

### Discovery and reliable calls

| Issue | Depends on | Engineering completion target | External or decisive exit evidence |
|---|---|---|---|
| [#17 Presence](../github/issues/FA-017.md) | #10, #15 | Explicit multi-device policy; busy/approval/block precedence; Redis recovery. | Measure process/network-loss propagation; database-owned active calls survive Redis restart without reopening. |
| [#18 Discovery](../github/issues/FA-018.md) | #12, #17 | Full eligibility/sort/empty states and immediate busy disable with deferred reorder. | All eligibility combinations and stale-card behavior; real supply only. |
| [#19 Paging/updates](../github/issues/FA-019.md) | #18 | Stable 20-item cursor/view epoch and segment-scoped subscriptions; mobile paging. | Changing-state uniqueness/skip checks and measured segmented fan-out. |
| [#20 Favorites](../github/issues/FA-020.md) | #18, #19 | Idempotent UI/API and presence-aware recents honoring block/deletion/approval. | Retried mutation leaves one record; stale favorites never bypass pair eligibility. |
| [#21 Pair eligibility](../github/issues/FA-021.md) | #10, #18 | Complete age/language/media/approval/suspension revalidation and active block behavior. | Direct/stale-response bypass tests; blocked parties cannot establish new contact. |
| [#22 Reservations](../github/issues/FA-022.md) | #7, #17, #21 | Finish atomic session/claim/quote/authorization invariants and durable CAS recovery. | 100-way real-DB race and interrupted transaction/process evidence; money integration waits for #34/#37. |
| [#23 Invitations](../github/issues/FA-023.md) | #22 | Complete accept/cancel/expiry/replay races and foreground/resume delivery. | Only addressed unexpired invite can accept; every terminal invitation releases claims/holds. |
| [#24 Matching](../github/issues/FA-024.md) | #19, #21, #22, #23 | Explicit opt-in/cancel; one request; at most three sequential candidates and disclosed wait. | No-supply/all-decline zero-charge and new-listener fairness simulation. |
| [#25 RTC adapter](../github/issues/FA-025.md) | #6, #10, #22 | Scoped tokens, verified provider evidence, renewal and termination adapter. | Cross-channel/UID misuse and hostile-client server-side cutoff on actual provider; SDK limits documented. |
| [#26 Audio](../github/issues/FA-026.md) | #23, #25 | Close remaining recovery/readiness defects; preserve stopped capture on end. | Exact-build two-way audio, denied mic recovery, headset/Bluetooth and Wi-Fi/mobile route tests; separate post-accept timing. |
| [#27 Lifecycle](../github/issues/FA-027.md) | #23, #26 | Verified/deduplicated provider events; monotonic terminal states and stable reasons. | Replay/reorder provider/client events and restart API during actual active media; one terminal effect. |
| [#28 Reconnect](../github/issues/FA-028.md) | #27 | Correlate SDK/capture/remote readiness with control timing; corroborated intervals and bounded free grace. | Diagnose remaining physical reconnects; network switch/process kill/resume; forged elapsed time never bills. |
| [#29 Background calls](../github/issues/FA-029.md) | #23, #26, #27 | FCM/notification/session restoration, stale-invite rejection and audio-focus handling. | Configured notification project and locked-screen/permission/battery/interruption device matrix under current Android rules. |
| [#30 Controls](../github/issues/FA-030.md) | #26, #28, #29 | Server-derived remaining time, low-balance/grace copy and accessible safety controls. | Large text/TalkBack/headset changes; device clock cannot alter monetary calculation. |
| [#31 History](../github/issues/FA-031.md) | #20, #27 | Complete favorites integration, timezone/day grouping and failed-call zero amounts. | Cross-midnight/timezone/ownership cases and persistent exact-build histories. |
| [#32 Media quality](../github/issues/FA-032.md) | #28, #31 | Redacted QoS and diagnostic IDs separating acceptance from actual media success. | Loss/jitter/one-way/join-failure evidence; no raw media, private text, credentials or full phones in logs. |

### Money and operations

| Issue | Depends on | Engineering completion target | External or decisive exit evidence |
|---|---|---|---|
| [#33 Catalogue](../github/issues/FA-033.md) | #2, #3, #7 | Versioned approved rates/packs, paid/promo units and expiring server quotes. | Approved SKUs/prices; manipulated/unavailable/call-midpoint catalogue cases. |
| [#34 Journal](../github/issues/FA-034.md) | #7, #33 | Separate INR/credit books; lots/allocations/holds/earnings; referenced reversals. | Conservation/rounding/idempotency properties and real-DB no-overspend concurrency. |
| [#35 Purchases](../github/issues/FA-035.md) | #2, #10, #33, #34 | Owner/SKU/token verification, pending/cancel/acknowledge/consume lifecycle, verified events and reconciliation. | Actual store sandbox success/pending/cancel/replay/copied-token cases; no credit from client success alone. |
| [#36 Wallet UX](../github/issues/FA-036.md) | #30, #33, #35 | Distinguish paid/promo balances; server-backed pending/failed/success and safe purchase return. | Interrupted provider-sandbox restore without duplicate call/purchase; approved steering only. |
| [#37 Charging/cutoff](../github/issues/FA-037.md) | #22, #25, #28, #30, #34, #35 | Rolling bounded holds and deterministic healthy intervals; release unused authorization. | Boundary/replay/reconnect tests plus actual exhausted-balance/old-token hostile-client media cutoff. |
| [#38 Refunds](../github/issues/FA-038.md) | #35, #37 | Original-event reversals; partial/chargeback/unknown outcome workflow. | Finance-approved spent-credit/released-earning policy; provider failure-after-request and replay proof. |
| [#39 Receipts](../github/issues/FA-039.md) | #31, #35, #37, #38 | Reconciled statements and owner-only masked expiring downloads. | Reviewed document issuer/tax treatment; sample reconciliation, timezone and expired/cross-user denial. |
| [#40 Reconciliation](../github/issues/FA-040.md) | #35, #37, #38, #39 | Scheduled provider/purchase/journal comparison and reasoned exception repair. | Named finance owner; dropped-webhook recovery and rerun with unchanged settled totals. |
| [#41 Earnings](../github/issues/FA-041.md) | #14, #33, #34, #37 | Pending/available/held/paid books, subsidy liability and explained corrections/holds. | Approved listener terms; six paid minutes = ₹50 under proposed rate, only if approved; refund consistency. |
| [#42 Payout identity](../github/issues/FA-042.md) | #2, #10, #14, #41 | Restricted masked payout references, step-up bank changes and cooldown. | Actual provider/legal required fields and bank checks; support roles denied sensitive access. |
| [#43 Payouts](../github/issues/FA-043.md) | #40, #41, #42 | Atomic payable reservation, one provider reference and unknown/reversed reconciliation. | Approved limits/provider sandbox; timeout-after-success never causes a blind second transfer. |
| [#44 Abuse](../github/issues/FA-044.md) | #3, #35, #37, #43 | Cross-account trial/collusion controls, exposure cap, reasoned holds and appeal. | Approved subsidy/risk policy; synthetic farming/replay and legitimate shared-network cases. |
| [#45 Safety](../github/issues/FA-045.md) | #21, #30, #31 | Restricted evidence/triage/actions/appeals with accessible report/block. | Named staffed child-safety/escalation contact and synthetic tabletop; immediate pair exclusion. |
| [#46 Admin](../github/issues/FA-046.md) | #14, #40, #43, #45 | Separate review/support/safety/finance/configuration RBAC and reasoned kill switches. | Staff MFA/permission matrix; audit reconstructs incident and money correction. |
| [#47 Support](../github/issues/FA-047.md) | #31, #39, #45 | Safe FAQs, scanned private attachments/notes, idempotent tickets and reopen path. | Named staffed hours/response expectations; safe reference lookup and interrupted ticket retry. |
| [#48 Website](../github/issues/FA-048.md) | #1, #2, #16, #45, #47 | Accessible public pages, accurate download state and traceable deletion intake. | Reviewed policy/contact/entity copy; authorized publication; deletion reaches authenticated processing. |

### Verification, release and expansion

| Issue | Depends on | Engineering completion target | External or decisive exit evidence |
|---|---|---|---|
| [#49 Privacy/security](../github/issues/FA-049.md) | #16, #25, #35, #42, #45, #48 | Data/retention/vendor inventory; log/upload/token/object authorization and native capture controls. | Privacy/security review, TLS deployment and physical native-surface capture tests with honest limits. |
| [#50 Financial QA](../github/issues/FA-050.md) | #27, #34, #37, #38, #40, #43 | Real-DB properties/concurrency, out-of-order events and API/worker/database failure recovery. | Provider-sandbox reconciliation after partial failure; every unexplained monetary mismatch blocks release. |
| [#51 Device matrix](../github/issues/FA-051.md) | #29, #30, #31, #36, #45, #49 | Reproducible whole-journey scripts and anonymized build/device/network evidence template. | Real onboarding/top-up/report/payout visibility/deletion, networks, interruptions, Tamil and accessibility; no ghost/one-way/charge-after-loss defects. |
| [#52 Load/fairness](../github/issues/FA-052.md) | #19, #24, #32, #37, #50 | Sustained/spike 1,000-socket and 100 synthetic-session harness with locks/lag/fan-out metrics. | Documented hardware, approved test budget, actual RTC quota/media sample and cap below demonstrated capacity. |
| [#53 Observability](../github/issues/FA-053.md) | #32, #40, #43, #46 | Redacted dashboards, cost alerts and provider/DB/safety incident runbooks. | Authorized deployment, named coverage and synthetic alert delivered to an approved test destination. |
| [#54 Recovery/deploy](../github/issues/FA-054.md) | #5, #6, #49, #53 | Separate environment IaC, reviewed migrations/canary and non-destructive rollback design. | Approved costed plan, backup restore measuring agreed RPO/RTO, rolling-call reconciliation. |
| [#55 Play testing](../github/issues/FA-055.md) | #2, #48, #49, #51, #54 | Accurate listing/Data Safety/app access/deletion evidence and submission packet. | Actual account-specific test period/engagement, pre-launch report, billing sandbox, current target checks and distinct review/access result. |
| [#56 Paid launch](../github/issues/FA-056.md) | #44, #45, #46, #47, #50, #51, #52, #53, #54, #55 | Assemble evidence-linked go/no-go, caps and rollback/canary dashboard. | Owner release decision; staffed listeners/support; approved small payment/call/refund/payout; first 48-hour OTP/occupancy/repeat-call/contribution review. |
| [#57 Video](../github/issues/FA-057.md) | #26, #28, #37, #56 | Preserve authorized private implementation; complete camera/lifecycle/quality regressions. | Exact-build physical camera/audio/fallback results and participant-minute cost reconciliation; public activation waits for dependency evidence and #58. |
| [#58 Video safety](../github/issues/FA-058.md) | #45, #49, #57 | Consent/moderation limits, immediate stop/report, capture deterrence and benign synthetic trigger/appeal cases. | Human privacy/safety review and staffed response; no covert recording or face-as-identity claim; public video stays disabled. |
| [#59 Text](../github/issues/FA-059.md) | #21, #45, #56 | Both-party permission, idempotent delivery, block races, spam controls and private notifications. | Approved retention/moderation scope; deletion/duplicate-send/preference tests before activation. |
| [#60 Offers](../github/issues/FA-060.md) | #3, #35, #38, #44, #56 | Transparent price/expiry/eligibility and separately funded promo/referral accounting. | Approved campaign budget/verified event; replay/expiry/refund/farming cases never exceed cap. |
| [#61 iOS](../github/issues/FA-061.md) | #2, #49, #56 | Review actual product scope before native permissions/media/billing integration. | Owner Apple account/devices, genuine product-review decision, TestFlight and iPhone/cross-platform evidence; no hidden review features. |
| [#62 Analytics](../github/issues/FA-062.md) | #40, #41, #56 | Minimized supply/join/retention/report metrics and separated money/liability measures. | Approved accounting interpretation, opt-out/retention/export controls and ledger reconciliation. |
| [#63 Scale evolution](../github/issues/FA-063.md) | #52, #53, #56, #62 | Measured bottleneck/demand case and proposed migration/backfill/rollback invariants. | Baseline comparison, approved provider/region/cost decisions and no cross-region double reservation or split finance authority. |
| [#64 AI evaluation](../github/issues/FA-064.md) | #45, #49, #56, #62 | Evaluation plan before model/memory selection; clear AI label, consent/deletion/cost/safety cases. | Explicit scope/privacy review and passed synthetic evaluation; disabled until evidence exists; never fake human supply. |

## Evidence and handoff rules

Each implementation handoff should record issue IDs, exact upstream interfaces used, code/build revision, migration and rollback behavior, commands/results actually run, provider/environment type, unresolved acceptance rows and the next evidence owner. Use safe opaque diagnostic IDs; store sensitive provider/user evidence separately with restricted access.

Run checks appropriate to changed code: generated-client/schema drift and representative migrations for contracts; real PostgreSQL/Redis tests for shared state; Flutter analysis/tests and Android builds for mobile changes; `node --test` from `audio/` for audio-reference changes. Physical media, store sandbox, real SMS, payout, recovery and staffing evidence must be recorded separately. Existing reported test totals are historical evidence, not tests executed by this document.

The next concrete engineering package is #9–12 integration with reviewable local tests. In parallel, request only the account/provider/owner facts in the launch decision packet and finish isolated prerequisites. Continue down the exact dependency graph as evidence becomes available. Stop at a missing external action only for the dependent acceptance step, while continuing independent authorized work.
