# ADR-0001: One Android application and an isolated test-credit milestone

Date: 20 November 2026
Status: Accepted for development by the owner's implementation request
Related issues: [#1](https://github.com/agilandeenadhayalan/nightshift/issues/1), [#4](https://github.com/agilandeenadhayalan/nightshift/issues/4), [#6](https://github.com/agilandeenadhayalan/nightshift/issues/6), [#7](https://github.com/agilandeenadhayalan/nightshift/issues/7), [#8](https://github.com/agilandeenadhayalan/nightshift/issues/8)

## Context

The repository has a runnable single-pair browser audio reference and 64 ordered issue specifications. The owner requested the first Android milestone while continuing independent engineering work when external decisions are unavailable. The acceptance condition includes real two-way audio on two Android phones, so local automation alone cannot complete the milestone.

## Decision

Use one Flutter project at `apps/mobile/`, one Android application ID and exactly two user-facing modes, Customer and Listener. Use one modular NestJS backend at `apps/api/` and PostgreSQL for durable identities, calls, participant claims and history. Separate staff tooling under `apps/admin/`; it is never a third mobile mode. Agora carries media, while the backend authorizes and records the call. No provider certificate or privileged credential is bundled into Flutter.

Develop with explicitly fictional identities, approved test listeners and test credits. Test access must be disabled in production configuration. Development engineering may proceed using those substitutes while the corresponding full production issue remains open. A local seed is not an identity-verification system, and a test credit ledger is not a payment provider.

Preserve `audio/` and run its tests. Use its existing customer tariff for Android test credits: at most 40 cumulative healthy connected seconds costs zero; crossing 40 seconds costs 60 test coins through 60 seconds; after that charge one coin per started cumulative second. Record the test rate version in call records. Production pricing requires decision D23 and does not inherit a competitor price or the reference's marketing label.

The Android Listener illustration deliberately uses healthy connected milliseconds at ₹500 per 3,600 seconds, rounded once, including the free test window. Its balanced counterpart is a fictional subsidy account; `availablePaise` stays zero and there is no real liability or payout. This differs from the browser's charged-coin-based earnings calculation, which also inherits the customer's minimum-charge floor. Healthy-time illustration follows the revised master-plan compensation basis without overstating delivered time. This development choice is not approval to fund free production calls; D09/D13/D23 remain pending.

Use the actual issue mapping in `github/import_map.json` for PRs. Describe implemented criteria and remaining evidence; do not close all related issues through a single broad completion claim. Later expansion work retains its FA dependencies, especially the paid-launch gate before video, chat, offers and iOS release.

## Consequences and verification

The first demonstrable path can be built without purchases, payouts, public listener onboarding or a paid deployment. Real-device verification still needs two consenting adults, Android devices, an owner-controlled RTC test project and network access. Production identity, provider-side media cutoff, store billing, legal review, support coverage and release approval remain separate gates.

The proposed development identifier is `com.nightshift.app`; owner confirmation is recorded in D08 before Play registration. Test rate and credentials are environment/configuration concerns and do not introduce another mode or Android application.

## Follow-up

See `Decision_Register.md`, `Issue_Status.md` and `Two_Phone_Test.md`. Revisit this ADR before enabling non-test identities, real payments, background call delivery or public distribution.
