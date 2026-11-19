# FA issue implementation and evidence register

Audit date: 20 November 2026. Source: all 64 specifications in `github/issues.json`, individual FA files, `github/import_map.json`, master plan, engineering contracts and the existing `audio/` code. All 64 GitHub issues were confirmed open during this implementation run. This is an engineering evidence register, not a request to close every issue.

The first unblocked issue is [#1](https://github.com/agilandeenadhayalan/nightshift/issues/1). Its scope and decision records are the starting deliverable. Foundation work follows #4, then #5/#6/#7 and #8. The first call path then uses test substitutes for unresolved production identity/review dependencies while implementing the shared #10/#15/#17/#18/#21/#22/#23/#25–#31 mechanisms. These substitutes do not satisfy the full production acceptance criteria for OTP, listener verification, provider callbacks, media cutoff or financial systems.

Status meanings:

- **Documented**: a reviewable document exists; required external approvals may remain.
- **Milestone work**: code/configuration is being implemented for the test-credit slice. Only the run's recorded checks establish verification; the full issue remains open where listed criteria are unmet.
- **Pending**: required work or evidence is not yet delivered. A foundation or placeholder is not completion.
- **Deferred by dependency**: expansion is not activated before the required release gates.

No real-device result, store approval, production safety coverage, financial approval or provider account is inferred from a passing automated test. See `Decision_Register.md` and `Two_Phone_Test.md`.

| Actual GitHub issue | Dependencies (FA numbers) | Status | Remaining acceptance or verification evidence |
|---|---|---|---|
| [#1 / FA-001](https://github.com/agilandeenadhayalan/nightshift/issues/1) Scope and decision register | None | Documented | `Product_Scope.md`, `Decision_Register.md`; owner confirmation of finance/safety appointments and original-transcript review remain |
| [#2 / FA-002](https://github.com/agilandeenadhayalan/nightshift/issues/2) Store and payment route | 001 | Pending | Play account type, dated policy decision, specialist funds-flow review and unresolved legal gates |
| [#3 / FA-003](https://github.com/agilandeenadhayalan/nightshift/issues/3) Economics and spending | 001, 002 | Documented | `Economics_Scenarios.md` and tested Decimal calculator cover historical and 12 audio/video scenarios with OTP; owner-approved spending/trial/top-up/payout caps and policy dependency remain |
| [#4 / FA-004](https://github.com/agilandeenadhayalan/nightshift/issues/4) Monorepo conventions | 001 | Milestone work | Paths, environment examples, ADR/PR conventions, compatible pins, clean checkout and secret scan |
| [#5 / FA-005](https://github.com/agilandeenadhayalan/nightshift/issues/5) CI and merge checks | 004 | Milestone work | TypeScript/Flutter and PostgreSQL/Redis jobs, scans, deliberate failure evidence and actual remote CI result |
| [#6 / FA-006](https://github.com/agilandeenadhayalan/nightshift/issues/6) Local stack and provider spike | 004 | Milestone work | Real two-phone RTC/cutoff evidence, owner test projects, approved branded OTP delivery on Indian SIMs |
| [#7 / FA-007](https://github.com/agilandeenadhayalan/nightshift/issues/7) Schema and contracts | 001, 004 | Milestone work | Full production entity coverage, migration evidence and incompatible-contract rejection beyond the slice |
| [#8 / FA-008](https://github.com/agilandeenadhayalan/nightshift/issues/8) Flutter foundation | 004, 007 | Milestone work | Widget navigation/restoration plus real-phone Tamil, large-text and screen-reader evidence |
| [#9 / FA-009](https://github.com/agilandeenadhayalan/nightshift/issues/9) Phone authentication | 006, 007, 008 | Pending | MSG91/Firebase flow, token verification, abuse controls, OTP consent and real delivery; fictional login is test-only |
| [#10 / FA-010](https://github.com/agilandeenadhayalan/nightshift/issues/10) Sessions and roles | 009 | Milestone work | Production identity/device revocation, suspension/socket tests and separate staff MFA/RBAC |
| [#11 / FA-011](https://github.com/agilandeenadhayalan/nightshift/issues/11) Adult profile onboarding | 008, 010 | Milestone work | Real onboarding, age-boundary/DOB change tests and moderated profile controls beyond adult test fixtures |
| [#12 / FA-012](https://github.com/agilandeenadhayalan/nightshift/issues/12) Languages | 011 | Milestone work | Tamil/English resources, persisted controlled codes and long-text/filter evidence |
| [#13 / FA-013](https://github.com/agilandeenadhayalan/nightshift/issues/13) Listener applications | 010, 011, 012 | Pending | Private uploads and draft/submitted/review states; seeded approval is not application review |
| [#14 / FA-014](https://github.com/agilandeenadhayalan/nightshift/issues/14) Listener review console | 010, 013 | Pending | Separate protected console, reviewer evidence and durable entitlement/notification workflow |
| [#15 / FA-015](https://github.com/agilandeenadhayalan/nightshift/issues/15) Mode and availability intent | 014 | Milestone work | Verify approved-only controls, server role guard, active-call mode lock and two-device concurrency |
| [#16 / FA-016](https://github.com/agilandeenadhayalan/nightshift/issues/16) Consent and deletion | 010, 011 | Pending | Versioned consent, step-up deletion, retention holds and synthetic eventual deletion evidence |
| [#17 / FA-017](https://github.com/agilandeenadhayalan/nightshift/issues/17) Presence | 010, 015 | Milestone work | Measure stale expiry and Redis restart behavior, explicit device policy and durable busy override |
| [#18 / FA-018](https://github.com/agilandeenadhayalan/nightshift/issues/18) Discovery | 012, 017 | Milestone work | All eligibility combinations, stale/busy UI and no fake production supply |
| [#19 / FA-019](https://github.com/agilandeenadhayalan/nightshift/issues/19) Pagination and updates | 018 | Milestone work | API has a bounded ID cursor; full view-epoch/live-state behavior, mobile paging and segmented fan-out measurement remain |
| [#20 / FA-020](https://github.com/agilandeenadhayalan/nightshift/issues/20) Favorites | 018, 019 | Milestone work | Add/remove API groundwork exists; favorites UI, complete block/deletion tests and presence-aware recents remain |
| [#21 / FA-021](https://github.com/agilandeenadhayalan/nightshift/issues/21) Pair eligibility | 010, 018 | Milestone work | Either-side block, suspension, language/media/age checks and immediate active-call block termination |
| [#22 / FA-022](https://github.com/agilandeenadhayalan/nightshift/issues/22) Atomic reservation | 007, 017, 021 | Milestone work | 100-way real-DB race, interrupted transaction recovery, versioned timeout/hold release evidence |
| [#23 / FA-023](https://github.com/agilandeenadhayalan/nightshift/issues/23) Invitations | 022 | Milestone work | Accept/cancel/expiry races, repeated requests and foreground/resume invitation delivery |
| [#24 / FA-024](https://github.com/agilandeenadhayalan/nightshift/issues/24) Opt-in matching | 019, 021, 022, 023 | Pending | At-most-three sequential attempts, cancellation, no-supply/all-decline tests and fairness simulation |
| [#25 / FA-025](https://github.com/agilandeenadhayalan/nightshift/issues/25) Scoped RTC adapter | 006, 010, 022 | Milestone work | Actual cross-UID/channel misuse tests, provider join evidence and tested server-side media termination |
| [#26 / FA-026](https://github.com/agilandeenadhayalan/nightshift/issues/26) Real Flutter audio | 023, 025 | Milestone work | Two physical phones with audible bidirectional voice, routing, denied microphone recovery and post-accept timing |
| [#27 / FA-027](https://github.com/agilandeenadhayalan/nightshift/issues/27) Durable lifecycle | 023, 026 | Milestone work | Verified/deduplicated provider events, replay/reordering and real restart recovery evidence |
| [#28 / FA-028](https://github.com/agilandeenadhayalan/nightshift/issues/28) Reconnect and intervals | 027 | Milestone work | Provider-correlated healthy intervals, real network switch/process kill and no forged elapsed-time billing |
| [#29 / FA-029](https://github.com/agilandeenadhayalan/nightshift/issues/29) Android background calls | 023, 026, 027 | Pending | FCM, locked screen, permissions, battery restrictions, phone/audio-focus interruptions and stale notification rejection |
| [#30 / FA-030](https://github.com/agilandeenadhayalan/nightshift/issues/30) Call controls | 026, 028, 029 | Milestone work | Server-derived amounts, low-balance/grace UI, in-call safety controls and real headset/accessibility tests |
| [#31 / FA-031](https://github.com/agilandeenadhayalan/nightshift/issues/31) Call history | 020, 027 | Milestone work | Both-participant history, owner authorization, cursor/grouping/time-zone cases and reconnect-safe recents |
| [#32 / FA-032](https://github.com/agilandeenadhayalan/nightshift/issues/32) Media quality | 028, 031 | Pending | QoS metrics, loss/jitter/one-way audio evidence and reviewed diagnostic redaction |
| [#33 / FA-033](https://github.com/agilandeenadhayalan/nightshift/issues/33) Rate and pack catalogue | 002, 003, 007 | Milestone work | Test-rate snapshot only; production price/pack/quote expiry and approved store SKU remain |
| [#34 / FA-034](https://github.com/agilandeenadhayalan/nightshift/issues/34) Financial journal | 007, 033 | Milestone work | Balanced append-only test-unit journal exists; real INR/credits, paid/promo lots, allocations, reversals and full financial property tests remain |
| [#35 / FA-035](https://github.com/agilandeenadhayalan/nightshift/issues/35) Store purchases | 002, 010, 033, 034 | Pending | Provider sandbox owner/SKU/receipt verification, webhook lifecycle and recovery |
| [#36 / FA-036](https://github.com/agilandeenadhayalan/nightshift/issues/36) Wallet and purchase UX | 030, 033, 035 | Milestone work | Test balance only; paid/promo distinction, real pending purchase states and restore tests remain |
| [#37 / FA-037](https://github.com/agilandeenadhayalan/nightshift/issues/37) Charging and cutoff | 022, 025, 028, 030, 034, 035 | Milestone work | Test tariff boundary/replay checks; production rolling holds and hostile-client provider cutoff are unproven |
| [#38 / FA-038](https://github.com/agilandeenadhayalan/nightshift/issues/38) Refunds | 035, 037 | Pending | Original-event reversals, partial refund/chargeback, spent credit/earnings policy and provider ambiguity recovery |
| [#39 / FA-039](https://github.com/agilandeenadhayalan/nightshift/issues/39) Statements and receipts | 031, 035, 037, 038 | Pending | Ledger-reconciled receipts, issuer/tax decision, owner-only expiring downloads and time-zone context |
| [#40 / FA-040](https://github.com/agilandeenadhayalan/nightshift/issues/40) Reconciliation | 035, 037, 038, 039 | Pending | Provider/purchase/journal reconciler, exception queue and lost-webhook replay evidence |
| [#41 / FA-041](https://github.com/agilandeenadhayalan/nightshift/issues/41) Listener earnings | 014, 033, 034, 037 | Milestone work | Non-payable test estimate only; payable state separation, promo liability and refund journal consistency remain |
| [#42 / FA-042](https://github.com/agilandeenadhayalan/nightshift/issues/42) Payout verification | 002, 010, 014, 041 | Pending | Approved provider/legal identity fields, masked bank references, step-up and cooldown controls |
| [#43 / FA-043](https://github.com/agilandeenadhayalan/nightshift/issues/43) Payout workflow | 040, 041, 042 | Pending | Atomic payable reservation, approval limits, provider reconciliation and timeout-after-success test |
| [#44 / FA-044](https://github.com/agilandeenadhayalan/nightshift/issues/44) Abuse and collusion | 003, 035, 037, 043 | Pending | Cross-account risk controls, capped trial-funded pay exposure, appeal and synthetic fairness tests |
| [#45 / FA-045](https://github.com/agilandeenadhayalan/nightshift/issues/45) Safety triage | 021, 030, 031 | Milestone work | Participant-only report and immediate-block APIs exist; in-call/history UX, restricted evidence, staffed contact and escalation tabletop remain |
| [#46 / FA-046](https://github.com/agilandeenadhayalan/nightshift/issues/46) Admin operations | 014, 040, 043, 045 | Pending | Separate staff MFA/RBAC, reason-coded audits, configuration/kill switches and permission matrix |
| [#47 / FA-047](https://github.com/agilandeenadhayalan/nightshift/issues/47) Support | 031, 039, 045 | Pending | FAQs, safe attachments, private notes, idempotent ticket lifecycle and staffed response expectations |
| [#48 / FA-048](https://github.com/agilandeenadhayalan/nightshift/issues/48) Public website | 001, 002, 016, 045, 047 | Pending | Actual accessible pages, reviewed policies, real download state and traced deletion request |
| [#49 / FA-049](https://github.com/agilandeenadhayalan/nightshift/issues/49) Privacy hardening | 016, 025, 035, 042, 045, 048 | Pending | Full data/retention/provider review, TLS/upload tests and on-device native capture-protection evidence |
| [#50 / FA-050](https://github.com/agilandeenadhayalan/nightshift/issues/50) Financial recovery QA | 027, 034, 037, 038, 040, 043 | Pending | Slice call races are preliminary; complete financial failure/property tests and provider reconciliation remain |
| [#51 / FA-051](https://github.com/agilandeenadhayalan/nightshift/issues/51) Device matrix | 029, 030, 031, 036, 045, 049 | Pending | Physical-device pass/fail evidence across network, audio, lifecycle, Tamil/accessibility and full journeys |
| [#52 / FA-052](https://github.com/agilandeenadhayalan/nightshift/issues/52) Load and fairness | 019, 024, 032, 037, 050 | Pending | Sustained 1,000 sockets/100 sessions, hardware/latency/lock/fan-out results and separate RTC quota sample |
| [#53 / FA-053](https://github.com/agilandeenadhayalan/nightshift/issues/53) Observability | 032, 040, 043, 046 | Pending | Deployed dashboards/alarms, named coverage, tested alert destination and incident runbooks |
| [#54 / FA-054](https://github.com/agilandeenadhayalan/nightshift/issues/54) Production recovery | 005, 006, 049, 053 | Pending | Reviewed IaC, separated environments, actual backup restore/RPO/RTO and rolling-call reconciliation |
| [#55 / FA-055](https://github.com/agilandeenadhayalan/nightshift/issues/55) Play testing | 002, 048, 049, 051, 054 | Pending | Account-specific closed test, accurate listing/declarations, pre-launch report, billing and store approval |
| [#56 / FA-056](https://github.com/agilandeenadhayalan/nightshift/issues/56) Paid launch | 044–047, 050–055 | Pending | All predecessor evidence, trained coverage, approved small payment/refund/payout and first 48-hour review |
| [#57 / FA-057](https://github.com/agilandeenadhayalan/nightshift/issues/57) Video | 026, 028, 037, 056 | Deferred by dependency | Explicit camera consent, video rates, device/quality tests and reconciled economics after audio launch |
| [#58 / FA-058](https://github.com/agilandeenadhayalan/nightshift/issues/58) Video safety | 045, 049, 057 | Deferred by dependency | Privacy/moderation review, immediate stop/report, synthetic triggers/appeals and capture limits |
| [#59 / FA-059](https://github.com/agilandeenadhayalan/nightshift/issues/59) Text | 021, 045, 056 | Deferred by dependency | Both-party consent, idempotent messages, block races, privacy, retention and spam controls |
| [#60 / FA-060](https://github.com/agilandeenadhayalan/nightshift/issues/60) Offers | 003, 035, 038, 044, 056 | Deferred by dependency | Approved campaign cap, paid/promo accounting, anti-farming and expiry/refund tests |
| [#61 / FA-061](https://github.com/agilandeenadhayalan/nightshift/issues/61) iOS | 002, 049, 056 | Deferred by dependency | Actual product-review decision, native billing/permissions, TestFlight and iPhone matrix |
| [#62 / FA-062](https://github.com/agilandeenadhayalan/nightshift/issues/62) Analytics | 040, 041, 056 | Deferred by dependency | Reconciled finance/funnel metrics, minimized exports, retention and opt-out tests |
| [#63 / FA-063](https://github.com/agilandeenadhayalan/nightshift/issues/63) Capacity evolution | 052, 053, 056, 062 | Deferred by dependency | Measured bottleneck, migration/rollback invariants and cross-region reservation evidence |
| [#64 / FA-064](https://github.com/agilandeenadhayalan/nightshift/issues/64) AI feasibility | 045, 049, 056, 062 | Deferred by dependency | Disclosure/consent/memory/deletion evaluation, synthetic safety checks and privacy approval; feature stays disabled |

## Evidence boundaries

The browser reference is a single-pair SQLite implementation, separate from the Android NestJS/PostgreSQL app. Preserving its tests is a regression check; it does not verify Android permissions, Agora audio, multi-device identity, production metering or payouts.

Implemented automated-check sources include `apps/api/test/unit.test.ts`, `apps/api/test/integration.test.ts`, `apps/mobile/test/` and `tests/test_unit_economics.py`. The economics suite passed all 10 tests during this run. Backend integration tests use isolated PostgreSQL schemas and Redis with synthetic readiness, and Flutter tests substitute media interfaces; neither proves audible media. The final `Verification.md` records commands, results and toolchain limitations after integration.

At initial inspection, no Android phones were connected, Agora configuration was not supplied, and Android SDK license acceptance was pending. Record any later toolchain progress in the run's validation report; do not silently change the real-device status.

Use PR descriptions to link actual issue numbers and report the implemented subset. Use automatic closing keywords only when every required acceptance and verification item for that issue has evidence. The request to keep moving past blockers does not supply provider approvals or waive the defined milestone.
