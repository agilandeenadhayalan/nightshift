# NightShift product scope

Issue: [FA-001 / #1](https://github.com/agilandeenadhayalan/nightshift/issues/1)
Recorded: 20 November 2026
Decision source: owner instructions in the implementation request and `NightShift_Master_Plan.md` (20 November 2026 revision).

## Agreed engineering scope

NightShift is one Android application, built in one Flutter project with one Android application ID. It has exactly two user-facing modes: **Customer** and **Listener**. Both modes use one shared NestJS backend and PostgreSQL database. Staff review, finance and moderation retain separate authorization. The owner requested their web pages inside the mobile app's built-in browser; this does not add a customer-facing mode. Listener entitlement is a server decision; switching a screen does not grant it.

The product is adult, one-to-one paid conversation with approved listeners, initially in Tamil and English. It is not a professional care service and does not promise romance, friendship, income or listener availability. The current implementation milestone uses fictional test identities and test credits only. No purchase, payout or public launch is authorized by completing a development demo.

The first Android milestone requires two real Android devices running the same application:

1. An approved test Listener goes online.
2. A Customer discovers that Listener and initiates a call.
3. The Listener accepts; both people hear each other.
4. Either participant can end the call.
5. Both participants see the same completed call in their history.

Ringing, failed joins and reconnect gaps do not count as delivered conversation. A completed API test or a built APK does not establish two-way audio; the real-device result is recorded separately in `Two_Phone_Test.md`.

## Feature disposition

This table covers the features recorded from the transcript in the master plan and the screen specification. The original 53,987-character transcript is not present in this repository, so a verbatim transcript audit remains an owner review item.

| Feature | First Android test milestone | Paid audio release / later disposition |
|---|---|---|
| One app, Customer and Listener modes | Required | Remains one app; staff tools separate |
| Android, Tamil and English | Required | More languages and iOS follow independent gates |
| Adult onboarding, consent, OTP | Fictional adult test identities; explicit development access | MSG91 branded OTP, Firebase session verification, age assurance and consent required before public use |
| Nickname, avatar, language | Safe test profiles and language selection | Editable moderated profile; never expose phone number or birth date |
| Listener application and approval | Manually seeded approved fictional Listener | Private application, verification, consented voice sample and human review |
| Availability and discovery sorting | Online/offline/busy, stale-presence expiry and language filter | Stable pagination, eligibility checks and accessible states |
| Direct calls | Required: invite, accept, decline, cancel, timeout and end | Same guarded durable session lifecycle |
| Opt-in Find a listener | Follow direct-call reliability | Explicit consent, cancellation, bounded attempts and fair matching |
| One-to-one audio | Required through managed RTC | Device/network reliability, media enforcement and quality evidence |
| Rates, coins and billing | Clearly labelled test credits; server-controlled test rate | Owner-approved price catalogue, store route, receipts and balanced ledger |
| Wallet, transactions and invoices | Test balance and session charges only | Verified top-ups, refunds, secure receipts and accounting review |
| Call history | Required for both participants | Pagination, retention, anonymization and support linkage |
| Favorites and feedback | Follow core call flow | Part of audio release; avoid stale availability |
| Listener earnings | Test estimate only; no payable entitlement | Proposed ₹500 per 3,600 paid connected seconds, versioned and reconciled; owner approval pending |
| Payouts | Disabled | Verified payout accounts, review, idempotency and reconciliation before real payouts |
| Reports, blocking and safety | Engineering foundations; consenting test cohort only | In-call controls, staffed escalation, appeals and child-safety process before public launch |
| Help and support tickets | Developer diagnostics and manual test report | Named support owner, support hours and private evidence workflow |
| Account deletion | No real personal identities in demo | Authenticated deletion and external request path with documented retention |
| Public website and internal admin | Separate repository paths; no third mobile mode | Public policies and protected permissioned operations required for launch |
| Monitoring and backups | Local diagnostics and repeatable tests | Restore drills, incident runbooks and monitored capped rollout |
| Video | Deferred from audio milestone | FA-057/#57 and FA-058/#58 after audio release and privacy/economics gates |
| Consent-based text chat | Deferred | FA-059/#59; moderation and retention must be designed |
| Coupons, referrals and offers | Deferred | FA-060/#60; capped subsidy and distinct promo accounting |
| iOS | Deferred | FA-061/#61; actual product review and two-iPhone testing |
| Rich analytics and large-scale architecture | Deferred | FA-062/#62 and FA-063/#63, justified by observed demand |
| AI companion | Deferred and disabled | FA-064/#64; explicitly labelled AI, never fake human supply |
| Group rooms, games, gifts, subscriptions | Deferred beyond planned audio release | Require a separate scope decision |
| Personality matching, social feed, location matching | Deferred | No need for the first one-to-one conversation proof |
| Automated voice/facial identity and complex recommendation ML | Deferred | A voice sample is not proof of age, gender or identity |

## Ownership and unresolved decisions

Agilan Deenadhayalan is the requesting repository/product owner and the decision contact. The proposed accountable owner for product, finance and safety is Agilan until named delegates accept those roles. Finance and safety appointment, competence and operational coverage are **not confirmed** by this document; no public launch depends on an inferred appointment. The decision register records these unresolved assignments, budget, brand, support hours and listener supply explicitly.

The owner asked engineering to continue independent work while decisions are pending. This allows local development with test credits; it does not turn missing provider approvals, real-device results, specialist reviews or release gates into completed acceptance criteria.

## Independence and evidence

The repository remote is `agilandeenadhayalan/nightshift`; the current source consists of this project's planning pack and local `audio/` reference. The agreed architecture has no dependency on employer source code, data, credentials or accounts. New provider projects must belong to the owner's personal business. Repository inspection cannot attest to the legal ownership of future external accounts; the owner must confirm those when provisioning them.

FA-001 evidence: this scope matches the master plan's core and deferred feature lists, identifies the two modes and first milestone, and records unresolved decisions. Owner confirmation of finance/safety responsibility and review against the original transcript remain explicit follow-ups rather than completed approvals.
