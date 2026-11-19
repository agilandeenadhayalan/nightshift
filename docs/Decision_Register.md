# NightShift decision register

Recorded: 20 November 2026. Decision contact: Agilan Deenadhayalan.
Related issue: [FA-001 / #1](https://github.com/agilandeenadhayalan/nightshift/issues/1).

**Confirmed** below means explicitly requested by the owner. **Proposed** means an engineering default or planning assumption. **Pending** means owner, provider, professional or real-device evidence is still required. Development can continue on independent work; pending items do not authorize a real-money or public release.

| ID | Decision / accountable contact | Status and current working position | Required input or evidence | Gate |
|---|---|---|---|---|
| D01 | Product shape — Agilan | Confirmed: one Android Flutter app, exactly Customer and Listener modes, one application ID, shared NestJS/PostgreSQL backend | None for the local milestone | Architecture |
| D02 | First milestone — Agilan | Confirmed: online Listener, Customer discovery, invite/accept, real two-way audio, either-party end and both histories | Two consenting adult Android testers and recorded real-device result | Milestone completion |
| D03 | Development funds — Agilan | Confirmed: test credits only; credentials outside Git | No live purchases or payouts enabled | All development |
| D04 | Product owner — Agilan | Agilan is the requesting product decision contact | Confirm who can approve future product changes and delegate if needed | Launch governance |
| D05 | Finance accountability — Agilan | Proposed: Agilan until a named finance owner accepts; appointment unconfirmed | Name accountable owner and CA/bookkeeping support; approve reconciliation and payout controls | Real money |
| D06 | Safety accountability — Agilan | Proposed: Agilan until a named safety owner accepts; appointment and coverage unconfirmed | Name escalation owner and backup, staffed hours, response process and child-safety contact | Public testers / launch |
| D07 | Brand and entity — Agilan | Working brand NightShift; commercial entity and brand clearance pending | Entity name, trademarks/domain checks, publisher identity and contracts | Public distribution |
| D08 | Android application ID — Agilan | Proposed `com.nightshift.app` for the single development app | Confirm permanent publisher-owned identifier before Play registration; changing after release is disruptive | Store registration |
| D09 | Budget and caps — Agilan | Provider/cloud spending not approved; local test credits create no monetary promise | Monthly budget, provider spend alerts, trial cap, top-up cap, payout cap and subsidized test spend owner | Provisioning / paid use |
| D10 | Listener supply — Agilan | Fictional approved local listeners only | Consenting adult cohort, verification process, languages, staffed shifts and expected availability | External pilot |
| D11 | Support hours — Agilan | No 24/7 support promise | Named support owner, channel, hours, response targets and emergency escalation wording | External pilot |
| D12 | Customer pricing — Agilan / finance owner | No production price approved; test-credit rate is a fixture | Price/minute, pack quantities, channel fees, tax treatment and economics sign-off | Paid calls |
| D13 | Listener pay — Agilan / finance owner | Proposed ₹500 per 3,600 paid connected seconds; not a guarantee of earnings | Contract, paid-time evidence, rounding, holds, disputes and approval of subsidy risk | Real earnings |
| D14 | Store/payment route — Agilan / specialist | Provisional plan is Play Billing for coins; no policy exception claimed | Play account type; current billing policy review; India alternative billing eligibility; actual funds-flow review | Purchases |
| D15 | Legal, tax and privacy — Agilan / specialists | Pending; no legal or CA review recorded | Entity, GST/TDS, listener contracts, funds flow, minor protection, privacy, retention and refunds | Public launch |
| D16 | Agora RTC project — Agilan | Selected for development integration; feasibility still needs real devices | Own test project credentials supplied outside Git, quota/budget, two-way audio and provider-side cutoff proof | Live media / paid media |
| D17 | Identity providers — Agilan | Local fictional identities allowed; production plan MSG91 OTP + Firebase sessions + FCM | Owner projects, approved sender/template/chain, real Indian SIM delivery and abuse controls | Production sign-in |
| D18 | Adult assurance and listener review — safety owner | Local test identities only; typed age is not strong assurance | Review process, storage/provider choice, consent, reviewer access and escalation | Public enrollment |
| D19 | Call privacy and retention — safety/privacy owner | Do not record private call audio; logs use opaque IDs | Approved retention schedule, processor inventory, deletion exceptions and policy copy | Public launch |
| D20 | Background incoming calls — Agilan / engineering | Foreground two-phone proof first; full FCM/background behavior remains device-dependent | Notification configuration and Android screen-lock/background/device matrix | Reliable release |
| D21 | App and infrastructure release — Agilan | Local debug development only; no production deployment approval inferred | Hosting ownership, budgets, production secrets, signed builds, staffed canary and rollback approval | Public deployment |
| D22 | Expansion — Agilan | Video, chat, offers, iOS, analytics/scale and AI follow their dependency gates | Separate scope, economics, privacy, provider and store decisions | FA-057–064 |
| D23 | Test tariff versus launch tariff — Agilan / finance owner | Browser reference has a 40-second free threshold, then a 60-coin minimum; master plan proposes cumulative per-second charging | Preserve browser behavior and tests; approve a versioned production tariff separately. Android development tariff must be stated in its contract and must not imply parity until verified | Pricing / production billing |

## Owner review requested after the development run

1. Confirm or nominate the accountable product, finance and safety owners; provide staffed support hours and the intended adult listener cohort.
2. Confirm brand/entity and the permanent Android identifier before any store registration.
3. Supply an owner-controlled Agora test project through local environment configuration and schedule two real Android phones; do not put credentials into an issue, PR, chat or Git.
4. Approve production pricing, budget/caps and payment route only after the documented specialist and store checks.

Until then, continue local engineering with fictional identities, test credits and explicit unmet gates. No issue is closed solely because an external dependency has been deferred.
