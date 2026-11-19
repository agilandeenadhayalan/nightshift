# GitHub backlog — 64 implementation issues

Prepared 28 October 2026. These are **local planning IDs**, not live GitHub issue numbers. No issues have been created remotely. FA-001–056 support the Android paid-audio MVP; FA-057–064 are expansion.

Sizes are relative: S = focused task, M = several connected changes, L = substantial subsystem or external verification. They are not calendar-day promises. Phase order is a dependency guide; policy, safety and test recruitment start early. A phase milestone is not an additional epic issue, so importing all phases creates exactly 64 issues and 8 milestones.

| ID | Phase | Issue | Size | Dependencies |
|---|---|---|---|---|
| FA-001 | P0 | Freeze adult audio MVP and decision register | S | — |
| FA-002 | P0 | Confirm store, payments and launch-policy route | M | FA-001 |
| FA-003 | P0 | Approve economic assumptions and spending envelope | S | FA-001, FA-002 |
| FA-004 | P0 | Create private monorepo and contributor conventions | S | FA-001 |
| FA-005 | P0 | Set up CI and meaningful merge checks | M | FA-004 |
| FA-006 | P0 | Prepare local stack and provider feasibility spike | M | FA-004 |
| FA-007 | P0 | Define database constraints and versioned API contracts | M | FA-001, FA-004 |
| FA-008 | P0 | Build Flutter navigation and accessible UI foundation | M | FA-004, FA-007 |
| FA-009 | P1 | Implement phone authentication with abuse controls | M | FA-006, FA-007, FA-008 |
| FA-010 | P1 | Implement sessions, devices and role authorization | M | FA-009 |
| FA-011 | P1 | Implement adult profile and avatar onboarding | M | FA-008, FA-010 |
| FA-012 | P1 | Implement language preferences and localization | S | FA-011 |
| FA-013 | P1 | Build private listener application flow | M | FA-010, FA-011, FA-012 |
| FA-014 | P1 | Build listener review and approval console | M | FA-010, FA-013 |
| FA-015 | P1 | Implement role switching and listener availability intent | S | FA-014 |
| FA-016 | P1 | Implement consent history and deletion workflow foundation | M | FA-010, FA-011 |
| FA-017 | P2 | Implement presence heartbeat and stale-status expiry | M | FA-010, FA-015 |
| FA-018 | P2 | Implement language-filtered discovery API and cards | M | FA-012, FA-017 |
| FA-019 | P2 | Implement stable cursor pagination and incremental updates | M | FA-018 |
| FA-020 | P2 | Implement favorites and presence-aware recents hooks | S | FA-018, FA-019 |
| FA-021 | P2 | Enforce pair eligibility and immediate blocking | M | FA-010, FA-018 |
| FA-022 | P2 | Implement atomic participant reservation | L | FA-007, FA-017, FA-021 |
| FA-023 | P2 | Implement invitations, acceptance and expiration | M | FA-022 |
| FA-024 | P2 | Implement bounded opt-in listener matching | M | FA-019, FA-021, FA-022, FA-023 |
| FA-025 | P3 | Implement scoped RTC token and provider adapter | M | FA-006, FA-010, FA-022 |
| FA-026 | P3 | Integrate real two-person Flutter audio calling | L | FA-023, FA-025 |
| FA-027 | P3 | Implement durable call lifecycle and idempotent transitions | L | FA-023, FA-026 |
| FA-028 | P3 | Implement reconnect, network loss and chargeable intervals | L | FA-027 |
| FA-029 | P3 | Implement background call notifications and Android lifecycle | L | FA-023, FA-026, FA-027 |
| FA-030 | P3 | Build call controls and remaining-time display | M | FA-026, FA-028, FA-029 |
| FA-031 | P3 | Implement call history, details and reconnect-safe recents | M | FA-020, FA-027 |
| FA-032 | P3 | Instrument media quality and zero-charge failure evidence | M | FA-028, FA-031 |
| FA-033 | P4 | Implement versioned rate and coin-pack catalogue | M | FA-002, FA-003, FA-007 |
| FA-034 | P4 | Implement append-only double-entry wallet journal | L | FA-007, FA-033 |
| FA-035 | P4 | Implement verified store purchases and receipt lifecycle | L | FA-002, FA-010, FA-033, FA-034 |
| FA-036 | P4 | Build wallet, purchase and pending-payment UX | M | FA-030, FA-033, FA-035 |
| FA-037 | P4 | Implement reservations, per-second charging and media cutoff | L | FA-022, FA-025, FA-028, FA-030, FA-034, FA-035 |
| FA-038 | P4 | Implement refunds, reversals and chargeback handling | L | FA-035, FA-037 |
| FA-039 | P4 | Implement secure transaction statements and receipts | M | FA-031, FA-035, FA-037, FA-038 |
| FA-040 | P4 | Implement payment reconciliation and finance exception queue | L | FA-035, FA-037, FA-038, FA-039 |
| FA-041 | P5 | Implement listener earnings accrual and statement | M | FA-014, FA-033, FA-034, FA-037 |
| FA-042 | P5 | Implement approved payout identity and bank verification | M | FA-002, FA-010, FA-014, FA-041 |
| FA-043 | P5 | Implement payout requests, approval and reconciliation | L | FA-040, FA-041, FA-042 |
| FA-044 | P5 | Implement trial, collusion and payment-abuse controls | M | FA-003, FA-035, FA-037, FA-043 |
| FA-045 | P5 | Implement reports, safety triage and child-safety workflow | L | FA-021, FA-030, FA-031 |
| FA-046 | P5 | Build audited admin operations and configuration | L | FA-014, FA-040, FA-043, FA-045 |
| FA-047 | P5 | Implement support center and ticket lifecycle | M | FA-031, FA-039, FA-045 |
| FA-048 | P5 | Build public website and reviewed policy pages | M | FA-001, FA-002, FA-016, FA-045, FA-047 |
| FA-049 | P6 | Harden privacy, permissions and capture protections | L | FA-016, FA-025, FA-035, FA-042, FA-045, FA-048 |
| FA-050 | P6 | Verify financial concurrency and failure recovery | L | FA-027, FA-034, FA-037, FA-038, FA-040, FA-043 |
| FA-051 | P6 | Complete two-device and network/device QA matrix | L | FA-029, FA-030, FA-031, FA-036, FA-045, FA-049 |
| FA-052 | P6 | Run load, capacity and fairness verification | M | FA-019, FA-024, FA-032, FA-037, FA-050 |
| FA-053 | P6 | Deploy observability, cost alarms and incident runbooks | M | FA-032, FA-040, FA-043, FA-046 |
| FA-054 | P6 | Prepare production IaC, backups and deployment recovery | L | FA-005, FA-006, FA-049, FA-053 |
| FA-055 | P6 | Complete Google Play test track and submission evidence | L | FA-002, FA-048, FA-049, FA-051, FA-054 |
| FA-056 | P6 | Review paid launch readiness and record the release decision | L | FA-044, FA-045, FA-046, FA-047, FA-050, FA-051, FA-052, FA-053, FA-054, FA-055 |
| FA-057 | P7 | Add opt-in one-to-one video calling | L | FA-026, FA-028, FA-037, FA-056 |
| FA-058 | P7 | Add video moderation and camera privacy safeguards | L | FA-045, FA-049, FA-057 |
| FA-059 | P7 | Add consent-based one-to-one text messaging | L | FA-021, FA-045, FA-056 |
| FA-060 | P7 | Add transparent coupons and capped referrals | M | FA-003, FA-035, FA-038, FA-044, FA-056 |
| FA-061 | P7 | Resolve iOS product review and implement approved iOS scope | L | FA-002, FA-049, FA-056 |
| FA-062 | P7 | Build privacy-aware product and financial analytics | M | FA-040, FA-041, FA-056 |
| FA-063 | P7 | Plan service extraction and higher-scale capacity from evidence | L | FA-052, FA-053, FA-056, FA-062 |
| FA-064 | P7 | Evaluate optional clearly labelled AI companion | M | FA-045, FA-049, FA-056, FA-062 |

## Complete issue bodies

<!-- nightshift-id: FA-001 -->
## FA-001 — Freeze adult audio MVP and decision register

Phase: **P0** · Area: **product** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Define one product with customer/listener roles, Tamil/English, Android first and a paid conversation service.

### Dependencies

None

### Acceptance criteria

- [ ] Core and deferred features match the master plan
- [ ] Record unresolved owner, brand, budget, support hours and listener-supply decisions
- [ ] Name an accountable owner for product, finance and safety even if one person fills several roles

### Verification

- [ ] Review every transcript feature against core/deferred scope
- [ ] Confirm no employer accounts, code or data are dependencies

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-002 -->
## FA-002 — Confirm store, payments and launch-policy route

Phase: **P0** · Area: **policy** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Decide the actual commercial and store billing route before integrating real-money purchases.

### Dependencies

FA-001

### Acceptance criteria

- [ ] Record Play account type and closed-testing applicability
- [ ] Document coin versus 1:1 service treatment and India alternative-billing conditions with source dates
- [ ] Track CA/legal review of entity, GST/TDS, contracts, funds flow, privacy and minor protection as unresolved launch gates until completed

### Verification

- [ ] Review a purchase/payout funds-flow diagram with the responsible specialists
- [ ] Recheck current primary policies before release

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-003 -->
## FA-003 — Approve economic assumptions and spending envelope

Phase: **P0** · Area: **product** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Make price, listener compensation, promo cost and unit contribution explicit.

### Dependencies

FA-001, FA-002

### Acceptance criteria

- [ ] Separate observed transcript values from model assumptions
- [ ] Model audio/video participant-minutes, channel fees, tax assumption, host cost, OTP and fixed costs
- [ ] Set proposed spend, trial, top-up and payout caps with an owner and revision date

- [ ] Model ₹500 per paid connected hour at ₹12, ₹15 and ₹20 per minute and compare 15% and 30% channel fees.

### Verification

- [ ] Reproduce the ₹17/30-minute example without claiming competitor profit
- [ ] Run low-price and high-fee cases and reject negative contribution unless a capped subsidy is authorized

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-004 -->
## FA-004 — Create private monorepo and contributor conventions

Phase: **P0** · Area: **platform** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Initialize the agreed repository layout with no app deployment or secrets.

### Dependencies

FA-001

### Acceptance criteria

- [ ] Create mobile, web, admin, API, worker, contracts, migrations, infra and docs paths
- [ ] Add README, ADR template, PR template, ignores and secure environment examples
- [ ] Pin supported toolchain versions after compatibility checks

### Verification

- [ ] Fresh checkout follows documented setup
- [ ] Secret scan is clean and generated artifacts are ignored appropriately

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-005 -->
## FA-005 — Set up CI and meaningful merge checks

Phase: **P0** · Area: **platform** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Make code and contract quality reproducible before feature work.

### Dependencies

FA-004

### Acceptance criteria

- [ ] CI runs TypeScript/Flutter static checks and relevant builds
- [ ] Test jobs use isolated PostgreSQL/Redis and publish failures
- [ ] Add secret/dependency scan and protected-branch guidance without assuming GitHub plan support

### Verification

- [ ] Demonstrate one deliberate failing check blocks the validation gate
- [ ] Restore green checks on the starter commit

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-006 -->
## FA-006 — Prepare local stack and provider feasibility spike

Phase: **P0** · Area: **platform** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Prove managed RTC and OTP integration feasibility on real devices while preparing isolated environments.

### Dependencies

FA-004

### Acceptance criteria

- [ ] Docker Compose starts PostgreSQL/Redis and documented health checks
- [ ] Use own test projects, secret injection and Firebase test numbers
- [ ] Two phones join a throwaway server-token RTC channel and validate Android media cutoff API feasibility before full integration

- [ ] Use fictional test identities locally and verify an approved branded OTP on real Indian SIMs in staging.

### Verification

- [ ] Record device/SDK/network versions and two-way audio result
- [ ] Confirm token secrets stay server-side and test adapters cannot run in production

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-007 -->
## FA-007 — Define database constraints and versioned API contracts

Phase: **P0** · Area: **backend** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Create the durable data model and contracts used across Flutter, admin and backend.

### Dependencies

FA-001, FA-004

### Acceptance criteria

- [ ] Schema covers identity, listener review, calls, claims, ledger, purchases, payouts, reports and outbox
- [ ] Specify state transitions, unique keys, UTC timestamps and fixed-point units
- [ ] Publish OpenAPI/event schemas and generated-client workflow

### Verification

- [ ] Apply migrations to empty and representative test databases
- [ ] Contract checks reject an incompatible client/server change

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-008 -->
## FA-008 — Build Flutter navigation and accessible UI foundation

Phase: **P0** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Implement Discover, Recents and Profile navigation with listener-mode placeholders and original design tokens.

### Dependencies

FA-004, FA-007

### Acceptance criteria

- [ ] Riverpod/GoRouter structure isolates feature state and API clients
- [ ] Tamil/English strings, readable typography and accessible control labels work
- [ ] Loading, empty, error and offline components are reusable with no fake production activity

### Verification

- [ ] Widget tests verify navigation and restoration
- [ ] Check large text and screen-reader order on a real phone

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-009 -->
## FA-009 — Implement phone authentication with abuse controls

Phase: **P1** · Area: **security** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Authenticate through server-verified branded OTP and use Firebase ID tokens for API sessions.

### Dependencies

FA-006, FA-007, FA-008

### Acceptance criteria

- [ ] Verify token issuer, audience, signature and expiry
- [ ] OTP resend/rate/quota controls and error UX are explicit
- [ ] Never log OTPs or full phone numbers and record provider consent

- [ ] Verify MSG91 challenge on the server, bind the verified phone to one UID, exchange a Firebase custom token and reject reused OTPs.

### Verification

- [ ] Test expired/invalid tokens and wrong/expired OTP UX
- [ ] Verify repeated requests respect limits and test bypass cannot enable production access

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-010 -->
## FA-010 — Implement sessions, devices and role authorization

Phase: **P1** · Area: **security** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Enforce customer/listener/admin permissions and session lifecycle on every endpoint and socket action.

### Dependencies

FA-009

### Acceptance criteria

- [ ] Backend maps provider identity to opaque user and device records
- [ ] Logout/revocation and suspension invalidate sensitive actions
- [ ] Admin access uses MFA and role permissions distinct from ordinary app users

### Verification

- [ ] Attempt forged role claims and cross-user resource access
- [ ] Test revoked socket and API session behavior

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-011 -->
## FA-011 — Implement adult profile and avatar onboarding

Phase: **P1** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Collect only necessary onboarding data with a meaningful age gate and moderated public profile.

### Dependencies

FA-008, FA-010

### Acceptance criteria

- [ ] Underage users cannot enter the adult service
- [ ] Nickname/avatar and optional preference fields validate safely
- [ ] DOB and phone remain private and self-declared age is not labelled verified identity

### Verification

- [ ] Test age boundaries and inconsistent DOB updates
- [ ] Verify public APIs exclude sensitive fields

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-012 -->
## FA-012 — Implement language preferences and localization

Phase: **P1** · Area: **mobile** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Separate interface language from conversation language filters.

### Dependencies

FA-011

### Acceptance criteria

- [ ] Tamil and English UI resources exist with fallback behavior
- [ ] Speaking languages are stored as controlled codes
- [ ] Changing filter language updates discovery without changing identity

### Verification

- [ ] Test long Tamil strings and persisted selections
- [ ] Verify filtering never uses device location as an undisclosed language proxy

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-013 -->
## FA-013 — Build private listener application flow

Phase: **P1** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Allow eligible adults to apply with bio, topics and consented review materials.

### Dependencies

FA-010, FA-011, FA-012

### Acceptance criteria

- [ ] Application has draft/submitted/needs-information/rejected states
- [ ] Uploads are private, size/type validated and time-limited
- [ ] Voice sample is described as a review sample rather than proof of gender or age

### Verification

- [ ] Attempt to read another applicant upload
- [ ] Test interrupted upload and duplicate submission without duplicating applications

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-014 -->
## FA-014 — Build listener review and approval console

Phase: **P1** · Area: **admin** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Enable a human reviewer to complete required checks before a listener becomes callable.

### Dependencies

FA-010, FA-013

### Acceptance criteria

- [ ] Review queue includes submitted evidence with minimum required access
- [ ] Approval/rejection records reviewer, time, checks performed and reason
- [ ] Approval triggers role entitlement and notification through durable events

### Verification

- [ ] Unprivileged user cannot approve themselves
- [ ] Duplicate approval event does not duplicate entitlement or notifications

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-015 -->
## FA-015 — Implement role switching and listener availability intent

Phase: **P1** · Area: **mobile** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Provide customer/listener modes while preserving one account and active-call constraints.

### Dependencies

FA-014

### Acceptance criteria

- [ ] Only approved listeners see operational earning controls
- [ ] Switching is blocked while reserved or in a call
- [ ] Desired availability is separate from current reachability

### Verification

- [ ] Try switching roles on two devices concurrently
- [ ] Confirm unapproved listeners cannot enable availability through direct API calls

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-016 -->
## FA-016 — Implement consent history and deletion workflow foundation

Phase: **P1** · Area: **security** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Make privacy choices and account deletion executable, with lawful retention boundaries.

### Dependencies

FA-010, FA-011

### Acceptance criteria

- [ ] Versioned consent events identify purpose and notice version
- [ ] Deletion request uses step-up authentication and published effect on credits/earnings
- [ ] Workflow distinguishes removable profile data from restricted financial/dispute retention

### Verification

- [ ] Verify deletion cannot target another account
- [ ] Test retention hold and eventual deletion using synthetic records

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-017 -->
## FA-017 — Implement presence heartbeat and stale-status expiry

Phase: **P2** · Area: **backend** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Track actual listener reachability without treating an app toggle as proof of availability.

### Dependencies

FA-010, FA-015

### Acceptance criteria

- [ ] Authenticated heartbeats refresh a proposed 45-second Redis TTL
- [ ] Busy/approval/block state override apparent online status
- [ ] Reconnect and multi-device policy have explicit server behavior

### Verification

- [ ] Kill the process/remove network and measure offline propagation
- [ ] Redis restart does not reopen a database-owned active call

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-018 -->
## FA-018 — Implement language-filtered discovery API and cards

Phase: **P2** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Show real eligible listeners with current availability and clear call affordances.

### Dependencies

FA-012, FA-017

### Acceptance criteria

- [ ] Available/busy/offline ordering follows the UI specification
- [ ] Blocked, unapproved and ineligible accounts are excluded
- [ ] Empty/no-language-supply states are useful and do not create fake profiles

### Verification

- [ ] Test all eligibility combinations
- [ ] Verify busy state immediately disables call while reordering is deferred

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-019 -->
## FA-019 — Implement stable cursor pagination and incremental updates

Phase: **P2** · Area: **backend** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Keep directory scrolling stable as availability changes.

### Dependencies

FA-018

### Acceptance criteria

- [ ] First page uses a 20-item limit and stable IDs/tie-breakers
- [ ] Cursor/view epoch policy prevents uncontrolled duplicates and skips
- [ ] Socket updates only affect relevant visible/subscribed directory slices

### Verification

- [ ] Change listener states during pagination and compare unique IDs
- [ ] Measure event fan-out with multiple language segments

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-020 -->
## FA-020 — Implement favorites and presence-aware recents hooks

Phase: **P2** · Area: **mobile** · Size: **S** · Release: **android-audio-mvp**

### Outcome

Let a customer save preferred listeners without implying guaranteed availability.

### Dependencies

FA-018, FA-019

### Acceptance criteria

- [ ] Favorite add/remove is idempotent
- [ ] Favorites respect blocks, deletion and listener approval
- [ ] Current availability is separate from historical call status

### Verification

- [ ] Retry favorite mutation and verify one record
- [ ] Blocked listener never reappears as callable from favorites

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-021 -->
## FA-021 — Enforce pair eligibility and immediate blocking

Phase: **P2** · Area: **security** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Apply one eligibility function to discovery, direct calls, matching and reconnection.

### Dependencies

FA-010, FA-018

### Acceptance criteria

- [ ] Either-side block and suspension prevent new pair contact
- [ ] Server revalidates approval, age gate, media type and language rules
- [ ] Safety block ends an active encounter according to documented behavior

### Verification

- [ ] Attempt direct API call to a hidden/blocked listener
- [ ] Confirm a stale directory response cannot bypass the block

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-022 -->
## FA-022 — Implement atomic participant reservation

Phase: **P2** · Area: **calls** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Prevent two callers or devices from acquiring the same participant simultaneously.

### Dependencies

FA-007, FA-017, FA-021

### Acceptance criteria

- [ ] Unique active participant claims cover both roles and both parties
- [ ] Transaction creates session, claims, quote snapshot and spend authorization atomically
- [ ] Timeout release and cancellation use versioned compare-and-set with durable recovery

### Verification

- [ ] Race 100 requests against one listener and prove only one valid claim
- [ ] Inject transaction/process failure and verify no orphaned claim; real-money integration waits for FA-034/037

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-023 -->
## FA-023 — Implement invitations, acceptance and expiration

Phase: **P2** · Area: **calls** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Deliver scoped invitations through sockets and notifications and resolve acceptance races.

### Dependencies

FA-022

### Acceptance criteria

- [ ] Only the addressed listener can accept an unexpired invitation
- [ ] Decline/cancel/timeout release claims and reservation
- [ ] Repeated invitation/accept events do not create a second session

### Verification

- [ ] Test accept vs cancel and accept after timeout
- [ ] Test notification delivery while foregrounded and resumed

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-024 -->
## FA-024 — Implement bounded opt-in listener matching

Phase: **P2** · Area: **calls** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Select eligible listeners using language, availability, fairness and controlled random tie-breaking.

### Dependencies

FA-019, FA-021, FA-022, FA-023

### Acceptance criteria

- [ ] One active matching request per customer with explicit cancel
- [ ] Try at most three candidates sequentially within a disclosed wait budget
- [ ] Record selection reasons without leaking private scores or implying romantic compatibility

### Verification

- [ ] No-supply and all-decline tests end without charge
- [ ] Fairness simulation demonstrates that new eligible listeners can receive requests

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-025 -->
## FA-025 — Implement scoped RTC token and provider adapter

Phase: **P3** · Area: **calls** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Issue server-generated media credentials bound to the authorized call and participant.

### Dependencies

FA-006, FA-010, FA-022

### Acceptance criteria

- [ ] Tokens bind channel, UID, permissions and short expiry
- [ ] No token for unapproved, unrelated, ended or unfunded session
- [ ] Provider adapter exposes join evidence, renewal and tested server-side termination capability

### Verification

- [ ] Try cross-channel/UID token reuse and unauthorized renewal
- [ ] Document SDK-specific enforcement limits and block real-money launch if cutoff is unproven

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-026 -->
## FA-026 — Integrate real two-person Flutter audio calling

Phase: **P3** · Area: **calls** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Connect accepted sessions through Agora and expose actual audio controls.

### Dependencies

FA-023, FA-025

### Acceptance criteria

- [ ] Two phones have working two-way audio and documented permissions
- [ ] Join failure and denied permission return to a recoverable state
- [ ] Microphone capture and channel connection stop on session end

### Verification

- [ ] Run Wi-Fi/mobile real-device call and audio routing tests
- [ ] Measure post-accept join time and distinguish it from ringing time

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-027 -->
## FA-027 — Implement durable call lifecycle and idempotent transitions

Phase: **P3** · Area: **calls** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Make every call state recoverable across client/server retries and restarts.

### Dependencies

FA-023, FA-026

### Acceptance criteria

- [ ] Requested through ended states follow an explicit allowed-transition table
- [ ] Provider events are verified, deduplicated and timestamped
- [ ] Terminal states cannot regress and history records a stable end reason

### Verification

- [ ] Replay and reorder provider/client events
- [ ] Restart API mid-call and verify one session and no duplicated terminal effect

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-028 -->
## FA-028 — Implement reconnect, network loss and chargeable intervals

Phase: **P3** · Area: **calls** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Determine healthy connected intervals conservatively and reconnect the same session.

### Dependencies

FA-027

### Acceptance criteria

- [ ] Store server-owned connected intervals corroborated by provider/client evidence
- [ ] Disconnect gaps and ringing are not billable
- [ ] Bounded free reconnect grace ends with clear final reason

### Verification

- [ ] Switch networks, kill one client and resume
- [ ] Verify an offline client cannot forge elapsed time to change billable duration

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-029 -->
## FA-029 — Implement background call notifications and Android lifecycle

Phase: **P3** · Area: **mobile** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Handle incoming and ongoing calls under actual Android background restrictions.

### Dependencies

FA-023, FA-026, FA-027

### Acceptance criteria

- [ ] Foreground/background notification permission and ongoing-call behavior are explicit
- [ ] Expired invitations cannot be answered from an old notification
- [ ] Phone interruption, audio focus and process restoration do not leave phantom calls

### Verification

- [ ] Test locked screen, denied notifications and battery restrictions on selected Android devices
- [ ] Confirm user-visible foreground behavior follows current platform rules

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-030 -->
## FA-030 — Build call controls and remaining-time display

Phase: **P3** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Provide clear mute/speaker/end controls and server-authoritative session display.

### Dependencies

FA-026, FA-028, FA-029

### Acceptance criteria

- [ ] Elapsed billable time and displayed price derive from server state
- [ ] Low-balance warning and disconnect grace copy are clear
- [ ] Report/block accessible during call without obscure navigation

### Verification

- [ ] Test screen reader/large text and headset changes
- [ ] Client clock changes do not change monetary calculation

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-031 -->
## FA-031 — Implement call history, details and reconnect-safe recents

Phase: **P3** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Show consistent completed/missed calls and secure details.

### Dependencies

FA-020, FA-027

### Acceptance criteria

- [ ] History uses cursor pagination and stable session IDs
- [ ] Today/yesterday grouping uses user locale/time zone
- [ ] Failed calls show zero charge and history data belongs only to participants

### Verification

- [ ] Test cross-midnight/time-zone cases
- [ ] Attempt another user session ID and verify denial

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-032 -->
## FA-032 — Instrument media quality and zero-charge failure evidence

Phase: **P3** · Area: **calls** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Record the evidence needed to distinguish technical failures, host declines and billing disputes.

### Dependencies

FA-028, FA-031

### Acceptance criteria

- [ ] Collect allowed QoS metrics and diagnostic IDs without recording conversations
- [ ] Separate invitation acceptance from media join success
- [ ] Report one-way audio and failed connection with actionable support context

### Verification

- [ ] Simulate loss/jitter and join failure
- [ ] Confirm logs contain no raw audio, private text, secrets or full phone numbers

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-033 -->
## FA-033 — Implement versioned rate and coin-pack catalogue

Phase: **P4** · Area: **money** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Make rates transparent, channel-aware and immutable for an active session.

### Dependencies

FA-002, FA-003, FA-007

### Acceptance criteria

- [ ] Audio/host rates, paid/promo units and catalogue versions are explicit
- [ ] Pre-call quote shows coin/minute, affordable time and relevant currency explanation
- [ ] Server ignores client price and honors only nonexpired approved quote

### Verification

- [ ] Change catalogue during a call and preserve original rate
- [ ] Test unavailable store SKU and manipulated price payload

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-034 -->
## FA-034 — Implement append-only double-entry wallet journal

Phase: **P4** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Build the financial source of truth with fixed-point units and reconciliation constraints.

### Dependencies

FA-007, FA-033

### Acceptance criteria

- [ ] Balanced journal separately accounts for INR and service-credit units
- [ ] Paid/promo lots, allocations, holds and earnings accounts are distinct
- [ ] All monetary events have deterministic idempotency keys and corrective reversal references

### Verification

- [ ] Property tests prove conservation, no overspend and deterministic rounding
- [ ] Concurrent real-database tests prove no negative spendable balance

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-035 -->
## FA-035 — Implement verified store purchases and receipt lifecycle

Phase: **P4** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Credit approved Android purchases only after authoritative provider verification.

### Dependencies

FA-002, FA-010, FA-033, FA-034

### Acceptance criteria

- [ ] Validate purchase owner/SKU/status/token and store transaction uniqueness
- [ ] Handle pending/cancelled/acknowledgement or consumption lifecycle using current provider rules
- [ ] Webhook verification and missed-event reconciliation are designed together

### Verification

- [ ] Use store sandbox for success/pending/cancelled/replayed receipts
- [ ] A copied token or client success callback cannot credit a second account

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-036 -->
## FA-036 — Build wallet, purchase and pending-payment UX

Phase: **P4** · Area: **mobile** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Show real balances and approved purchase options without hidden recurring payments.

### Dependencies

FA-030, FA-033, FA-035

### Acceptance criteria

- [ ] Purchased/promo balances and pack totals are clear
- [ ] Pending/failed/success states agree with backend verification
- [ ] Top-up return resumes safely without a duplicate call or accidental purchase

### Verification

- [ ] Interrupt app during purchase and restore state
- [ ] Verify no production build exposes unapproved external payment steering

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-037 -->
## FA-037 — Implement reservations, per-second charging and media cutoff

Phase: **P4** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Charge authorized connected intervals exactly once and stop media when credit ends.

### Dependencies

FA-022, FA-025, FA-028, FA-030, FA-034, FA-035

### Acceptance criteria

- [ ] Reserve next bounded interval atomically before authorizing it
- [ ] Meter cumulative healthy seconds with fixed-point arithmetic and deterministic interval IDs
- [ ] Release unused hold and enforce provider-side media stop despite client ignoring hang-up

- [ ] Replaying reconnect and duplicate events preserves the same paid intervals and settlement.

### Verification

- [ ] Test 0/1/59/60/61 seconds, duplicate jobs and reconnection gaps
- [ ] Exhaust balance, replay old tokens and prove no unauthorized paid continuation

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-038 -->
## FA-038 — Implement refunds, reversals and chargeback handling

Phase: **P4** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Correct failed/contested transactions without editing ledger history.

### Dependencies

FA-035, FA-037

### Acceptance criteria

- [ ] Refund references original purchase/consumption and preserves an audit trail
- [ ] Define handling of spent credits and host earnings already released
- [ ] Unknown provider outcome remains pending until reconciled

### Verification

- [ ] Replay refund webhook and verify one reversal
- [ ] Test partial refund, chargeback after spend and failure after an external refund request

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-039 -->
## FA-039 — Implement secure transaction statements and receipts

Phase: **P4** · Area: **money** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Expose traceable payment/session history and the correct receipt document.

### Dependencies

FA-031, FA-035, FA-037, FA-038

### Acceptance criteria

- [ ] Order/session/refund records reconcile with ledger entries
- [ ] Determine whether the store or company issues tax documentation before generating invoices
- [ ] Downloads are owner-authorized, masked and include appropriate time zone/tax context

### Verification

- [ ] Reconcile sample statements to source transactions
- [ ] Expired link and cross-user download attempts fail

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-040 -->
## FA-040 — Implement payment reconciliation and finance exception queue

Phase: **P4** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Detect missed/duplicate/unknown transactions before balances or payouts drift.

### Dependencies

FA-035, FA-037, FA-038, FA-039

### Acceptance criteria

- [ ] Scheduled reconciler compares provider records, purchases and journal
- [ ] Exceptions have severity, owner, age and resolution evidence
- [ ] Repair commands append idempotent events and never directly overwrite balance

### Verification

- [ ] Drop selected webhooks and prove eventual recovery
- [ ] Rerun reconciliation and show unchanged settled totals

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-041 -->
## FA-041 — Implement listener earnings accrual and statement

Phase: **P5** · Area: **money** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Accrue listener compensation from validated delivered service using versioned rates.

### Dependencies

FA-014, FA-033, FA-034, FA-037

### Acceptance criteria

- [ ] Pending/available/held/paid balances remain separate
- [ ] Promo-funded calls identify company subsidy liability
- [ ] Statements expose rate, billable time, corrections and hold reasons

- [ ] At the proposed rate, six paid minutes earn ₹50. Exclude idle and reconnect gaps and round once at settlement.

### Verification

- [ ] Recompute a call earning from source interval/rate
- [ ] Refund/dispute adjustments preserve journal consistency

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-042 -->
## FA-042 — Implement approved payout identity and bank verification

Phase: **P5** · Area: **money** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Integrate the required provider KYC/bank flow without spreading identity documents across the system.

### Dependencies

FA-002, FA-010, FA-014, FA-041

### Acceptance criteria

- [ ] Required checks and tax fields follow provider/legal decision
- [ ] Store masked references with restricted access rather than unnecessary raw documents
- [ ] Bank changes require step-up authentication and fraud cooldown policy

### Verification

- [ ] Test pending/rejected verification and account mismatch
- [ ] Confirm ordinary support roles cannot view sensitive banking data

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-043 -->
## FA-043 — Implement payout requests, approval and reconciliation

Phase: **P5** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Pay only available approved earnings and safely handle uncertain external outcomes.

### Dependencies

FA-040, FA-041, FA-042

### Acceptance criteria

- [ ] Request reserves payable INR atomically and uses one provider reference
- [ ] Approval thresholds, deductions and processing states are disclosed
- [ ] Unknown/failed/reversed payouts are reconciled before retry or fund release

### Verification

- [ ] Replay requests/webhooks and prove exactly one payout effect
- [ ] Simulate provider timeout after success and verify no blind second transfer

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-044 -->
## FA-044 — Implement trial, collusion and payment-abuse controls

Phase: **P5** · Area: **security** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Limit self-calls, circular calling, payment fraud and promo farming.

### Dependencies

FA-003, FA-035, FA-037, FA-043

### Acceptance criteria

- [ ] Block self-pairing across roles and cap trial-funded earning exposure
- [ ] Risk rules combine relevant signals with data minimization and appeal
- [ ] Payout holds and risk decisions are audited and never presented as confirmed guilt without review

### Verification

- [ ] Exercise synthetic multi-account and replay scenarios
- [ ] Check legitimate shared-network users are not automatically permanently banned

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-045 -->
## FA-045 — Implement reports, safety triage and child-safety workflow

Phase: **P5** · Area: **security** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Give users immediate protection and operators a workable response process.

### Dependencies

FA-021, FA-030, FA-031

### Acceptance criteria

- [ ] Report and block are accessible in-call and from history
- [ ] Triage supports severe harm/child-safety escalation and a named contact
- [ ] Evidence access, retention, action reasons and appeals are restricted and auditable

### Verification

- [ ] Report an active call and verify immediate pair exclusion
- [ ] Run a tabletop escalation using synthetic data and documented staffed coverage

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-046 -->
## FA-046 — Build audited admin operations and configuration

Phase: **P5** · Area: **admin** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Unify operational controls without allowing unrestricted finance or identity access.

### Dependencies

FA-014, FA-040, FA-043, FA-045

### Acceptance criteria

- [ ] RBAC separates review, support, safety, finance and configuration
- [ ] Rate changes, account actions and payout approvals require reasons and audit records
- [ ] Provide feature/call/purchase kill switches with controlled rollout

### Verification

- [ ] Test every admin role against allowed/denied actions
- [ ] Audit search reconstructs a sample incident and money correction

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-047 -->
## FA-047 — Implement support center and ticket lifecycle

Phase: **P5** · Area: **admin** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Provide support that is tied to actual call/payment/payout records.

### Dependencies

FA-031, FA-039, FA-045

### Acceptance criteria

- [ ] FAQs cover media, payment, listener, safety and account problems
- [ ] Ticket attachments are validated/scanned and internal notes stay private
- [ ] Ticket status, ownership, response expectations and reopen path are clear

### Verification

- [ ] Submit/retry an interrupted ticket and prevent duplicates
- [ ] Support can find a call via safe reference without accessing raw secrets

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-048 -->
## FA-048 — Build public website and reviewed policy pages

Phase: **P5** · Area: **web** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Publish an original site explaining the service and providing required help and deletion entry points.

### Dependencies

FA-001, FA-002, FA-016, FA-045, FA-047

### Acceptance criteria

- [ ] Home, how-it-works, listener info, contact and real download state exist
- [ ] Privacy/terms/refund/community/child-safety/listener pages have reviewed content
- [ ] External deletion request works and no false safety/earnings/user-count claims appear

### Verification

- [ ] Check responsive accessibility and policy links
- [ ] Submit a deletion request and trace it to authenticated processing

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-049 -->
## FA-049 — Harden privacy, permissions and capture protections

Phase: **P6** · Area: **security** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Complete threat modelling and platform privacy controls before a paid launch.

### Dependencies

FA-016, FA-025, FA-035, FA-042, FA-045, FA-048

### Acceptance criteria

- [ ] Review data inventory, retention, vendor processing and log redaction
- [ ] Apply FLAG_SECURE where needed and test native media surfaces
- [ ] Validate upload isolation, secrets, TLS, authorization and child/minor controls; no 100% recording-prevention promise

### Verification

- [ ] Security review attempts token, object-ID and upload abuse
- [ ] Run on-device capture tests and document limits honestly

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-050 -->
## FA-050 — Verify financial concurrency and failure recovery

Phase: **P6** · Area: **money** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Establish release-blocking evidence for money and active-call invariants.

### Dependencies

FA-027, FA-034, FA-037, FA-038, FA-040, FA-043

### Acceptance criteria

- [ ] Automated suite covers duplicate/out-of-order events and accept/cancel races
- [ ] DB/API/worker failures preserve claims and journal correctness
- [ ] Every unexplained monetary discrepancy is a blocker with reproducible evidence

### Verification

- [ ] Run real-database concurrency/property tests
- [ ] Restore from injected partial failure and reconcile with provider sandbox

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-051 -->
## FA-051 — Complete two-device and network/device QA matrix

Phase: **P6** · Area: **mobile** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Exercise the complete customer and listener journey on realistic Android devices and networks.

### Dependencies

FA-029, FA-030, FA-031, FA-036, FA-045, FA-049

### Acceptance criteria

- [ ] Test onboarding through call, top-up, report, payout visibility and deletion
- [ ] Cover low bandwidth, network switch, permissions, backgrounding and cellular interruptions
- [ ] Tamil, large text, accessibility and empty/error states are verified

### Verification

- [ ] Capture anonymized pass/fail evidence with build/device/network versions
- [ ] Fix one-way audio, ghost calls and charge-after-disconnect before release

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-052 -->
## FA-052 — Run load, capacity and fairness verification

Phase: **P6** · Area: **platform** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Measure control-plane capacity and establish honest rollout caps.

### Dependencies

FA-019, FA-024, FA-032, FA-037, FA-050

### Acceptance criteria

- [ ] Target 1,000 sockets and 100 synthetic concurrent sessions with documented hardware
- [ ] Measure heartbeat/fan-out, DB locks, queue lag and rate-limit behavior
- [ ] Validate real RTC quota/media sample separately from bots

### Verification

- [ ] Run a sustained load and spike with recovery
- [ ] Publish observed limits and configure launch cap below proven safe capacity

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-053 -->
## FA-053 — Deploy observability, cost alarms and incident runbooks

Phase: **P6** · Area: **platform** · Size: **M** · Release: **android-audio-mvp**

### Outcome

Make failed calls, money mismatches and runaway costs visible to a responsible operator.

### Dependencies

FA-032, FA-040, FA-043, FA-046

### Acceptance criteria

- [ ] Dashboards cover media joins, drops, presence, ledger exceptions, payouts, support and spend
- [ ] Alerts have named owner, severity and realistic coverage hours
- [ ] Runbooks include RTC, OTP, payment, DB, Redis and safety incidents

### Verification

- [ ] Trigger synthetic alerts and confirm delivery to test destination
- [ ] Verify logs redact credentials and metrics distinguish host absence from technical failure

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-054 -->
## FA-054 — Prepare production IaC, backups and deployment recovery

Phase: **P6** · Area: **platform** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Provision a reviewed environment only after current costs and scope are accepted.

### Dependencies

FA-005, FA-006, FA-049, FA-053

### Acceptance criteria

- [ ] Separate staging/prod secrets, data, provider projects and permissions
- [ ] Use reviewed Terraform plan, migrations, health checks and canary-compatible rollout
- [ ] Backups, point-in-time recovery where supported and non-destructive rollback are documented

### Verification

- [ ] Restore a backup and measure RPO/RTO against targets
- [ ] Roll an API version during test calls and reconcile in-flight money

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-055 -->
## FA-055 — Complete Google Play test track and submission evidence

Phase: **P6** · Area: **policy** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Prepare truthful store metadata and satisfy account-specific testing and policy requirements.

### Dependencies

FA-002, FA-048, FA-049, FA-051, FA-054

### Acceptance criteria

- [ ] Accurate listing, content rating, Data Safety, app-access review steps and child-safety declarations
- [ ] Run required closed test with actual eligible testers and engagement evidence
- [ ] Verify production billing configuration, current target requirements and deletion URL

### Verification

- [ ] Use Play pre-launch report and sandbox purchase evidence
- [ ] Record production-access/review status separately from build completion

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-056 -->
## FA-056 — Review paid launch readiness and record the release decision

Phase: **P6** · Area: **product** · Size: **L** · Release: **android-audio-mvp**

### Outcome

Launch only the validated Android audio service to a controlled cohort.

### Dependencies

FA-044, FA-045, FA-046, FA-047, FA-050, FA-051, FA-052, FA-053, FA-054, FA-055

### Acceptance criteria

- [ ] All release blockers have evidence, named support and trained listener coverage
- [ ] Configure invitation/concurrency/spend/payout limits and rollback switches
- [ ] Review first 48-hour call, money, quality, fraud and support metrics before expansion

- [ ] Record branded OTP delivery, repeat paid calls, listener occupancy and contribution against the approved launch budget.

### Verification

- [ ] Execute the full go/no-go checklist with actual provider approvals
- [ ] Complete a small approved payment, call, refund and host payout reconciliation

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-057 -->
## FA-057 — Add opt-in one-to-one video calling

Phase: **P7** · Area: **calls** · Size: **L** · Release: **expansion**

### Outcome

Extend the same session and money model to camera-based communication after audio stability.

### Dependencies

FA-026, FA-028, FA-037, FA-056

### Acceptance criteria

- [ ] Separate video rate, explicit preview/consent and permissions
- [ ] Quality adaptation and disclosed audio fallback do not silently change charging
- [ ] Same claim, timeout, end and privacy invariants apply

### Verification

- [ ] Test camera switching, denial, backgrounding and bandwidth degradation
- [ ] Reconcile video participant-minute cost and delivered-session charges

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-058 -->
## FA-058 — Add video moderation and camera privacy safeguards

Phase: **P7** · Area: **security** · Size: **L** · Release: **expansion**

### Outcome

Define a workable non-recording-default video safety model before public video rollout.

### Dependencies

FA-045, FA-049, FA-057

### Acceptance criteria

- [ ] Document moderation techniques, consent, privacy and human response limits
- [ ] No claim that face presence proves identity or prevents prohibited behavior
- [ ] Test capture deterrence and immediate stop/report without covert recording

### Verification

- [ ] Use synthetic benign test material to validate triggers and appeals
- [ ] Run privacy/safety review; keep public video disabled until this gate passes

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-059 -->
## FA-059 — Add consent-based one-to-one text messaging

Phase: **P7** · Area: **mobile** · Size: **L** · Release: **expansion**

### Outcome

Support optional persistent text conversations without sending messages automatically.

### Dependencies

FA-021, FA-045, FA-056

### Acceptance criteria

- [ ] Both-party permissions, block/report, retention and notification privacy apply
- [ ] Rate limits, spam controls and content moderation are implemented
- [ ] Message retries are idempotent and delivery state is accurate

### Verification

- [ ] Test block races, deleted accounts and duplicate sends
- [ ] Verify notifications hide private message content by user preference

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-060 -->
## FA-060 — Add transparent coupons and capped referrals

Phase: **P7** · Area: **money** · Size: **M** · Release: **expansion**

### Outcome

Introduce acquisition offers only when full-price contribution and abuse controls are understood.

### Dependencies

FA-003, FA-035, FA-038, FA-044, FA-056

### Acceptance criteria

- [ ] Show eligibility, expiry, actual final price and service minutes
- [ ] Keep paid/promo accounting and company-funded host payout explicit
- [ ] Referral awards require a defined verified event and cannot be farmed through self-referrals

### Verification

- [ ] Test repeated redemption, expiry and refund after offer use
- [ ] Check promotional spend never exceeds approved campaign budget

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-061 -->
## FA-061 — Resolve iOS product review and implement approved iOS scope

Phase: **P7** · Area: **policy** · Size: **L** · Release: **expansion**

### Outcome

Assess whether the real product model fits App Review before a costly iOS launch effort.

### Dependencies

FA-002, FA-049, FA-056

### Acceptance criteria

- [ ] Document random/anonymous-chat risk and a genuinely compliant scope decision
- [ ] If proceeding, implement native audio/call/permission and approved billing flows
- [ ] Do not hide features for review; publish accurate privacy and purchase disclosures

### Verification

- [ ] Run two-iPhone and Android/iPhone tests plus TestFlight
- [ ] Track review decision as external dependency; stop release if product is rejected

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-062 -->
## FA-062 — Build privacy-aware product and financial analytics

Phase: **P7** · Area: **backend** · Size: **M** · Release: **expansion**

### Outcome

Measure healthy marketplace performance rather than only recharge totals.

### Dependencies

FA-040, FA-041, FA-056

### Acceptance criteria

- [ ] Metrics separate GMV, consumed value, earned revenue treatment, host liability and contribution
- [ ] Funnels cover supply by language/hour, acceptance, technical join, retention and reports
- [ ] Use minimized event payloads and controlled exports without private conversation content

### Verification

- [ ] Reconcile dashboards with ledger and call records
- [ ] Demonstrate opt-out/retention handling and no double-counted session events

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-063 -->
## FA-063 — Plan service extraction and higher-scale capacity from evidence

Phase: **P7** · Area: **platform** · Size: **L** · Release: **expansion**

### Outcome

Evolve architecture only when measured bottlenecks justify it.

### Dependencies

FA-052, FA-053, FA-056, FA-062

### Acceptance criteria

- [ ] Capture current CPU/DB/queue/fan-out bottleneck and target demand
- [ ] Assess regional presence, replica strategy, finance isolation and RTC volume contract
- [ ] Provide migration, backfill, rollback and invariants before extracting services

### Verification

- [ ] Load-test the proposed change against an existing baseline
- [ ] Prove no cross-region double reservation or split financial authority

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

<!-- nightshift-id: FA-064 -->
## FA-064 — Evaluate optional clearly labelled AI companion

Phase: **P7** · Area: **product** · Size: **M** · Release: **expansion**

### Outcome

Explore AI as a separate future experience only after the human service is stable.

### Dependencies

FA-045, FA-049, FA-056, FA-062

### Acceptance criteria

- [ ] AI is visibly distinguished from human listeners and never used to fake supply
- [ ] Define consent, memory controls, deletion, cost caps, abuse handling and no professional-care promises
- [ ] Write an evaluation plan before selecting a model or shipping personalized memory

### Verification

- [ ] Test disclosure, safety escalation and sensitive-data handling with synthetic scenarios
- [ ] Keep feature disabled until evaluation and privacy review pass

### Implementation handoff

Read `NightShift_Master_Plan.md`, `docs/Engineering_Contracts.md`, `docs/UI_Screen_Specification.md` and the relevant source/policy records. Use `prompts/02_Single_Issue_Implementation.md` with this issue ID. Keep changes within this outcome. Record tests, provider limitations, migrations and unresolved decisions in the PR. Do not mark external approval or real-device checks complete from mocks.

---

