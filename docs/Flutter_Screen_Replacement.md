# Native Flutter screen replacement

Date: 23 November 2026. The owner supplied the complete 54-document HTML collection, requested native Flutter with state management, clarified that it should replace the existing screens, and explicitly asked to create all screens.

## Implementation plan and boundaries

1. Extract the existing widget library into disjoint parts, preserving its public constructors and shared guarded actions.
2. Replace the application theme and live authentication, discovery, matching, call, profile and history presentation with the supplied dark violet/cyan design family.
3. Build all 54 native screen variants from reusable entry, home, commerce and call families. Preserve alternative designs in an in-app development collection. HTML is a reference, not a WebView implementation.
4. Keep Riverpod 2.6.1 and GoRouter 14.8.1. The existing AppController remains the sole authority for account identity, Customer/Listener mode, eligibility, balances, calls and server results. Add auto-disposed feature presentation state for local selections, searches and design interactions.
5. Reuse existing permission, consent, OTP cooldown, account ownership, call End/reconnect, diagnostics, report/block and staff boundaries. Phone and OTP remain one retained flow; changing screens must not dispose a live challenge.
6. Verify all 54 variants at small phone sizes and enlarged text, real route integration, account/device regressions, audio reference checks and Android compilation. Record exact results below.

The production release gate remains. No app installation, live server migration, real payment, SMS send or staff-role change is part of this UI replacement.

## Product mappings

- The app still has exactly Customer and Listener. Source labels Host/Creator mean Listener; gendered sample personas do not determine permission or eligibility.
- Alternative versions are preserved as explicit design variants. The live app chooses presentation according to its actual state rather than creating a third mode or a second business-state store.
- Existing test credit balances, frozen rates, elapsed time and estimated earnings remain server-derived. Source prices, coin/diamond conversion, promotion claims, cash withdrawal thresholds and guaranteed earnings are not approved policy.
- Payment/card/bank, withdrawals, ratings, tickets and synchronized Ludo have no existing backend workflows. Their complete layouts are available for design review; live actions explain unavailability. Real card/CVV entry, fake transaction success, invented ticket references and remote game synchronization are not implemented.
- System permission examples are explanatory Flutter views. Only the real platform permission flow can grant access; app-rendered Allow text cannot manufacture a grant.
- Real profiles use actual account names and neutral avatars. Sample portraits, availability and history in a design preview are not presented as real people or activity in discovery.
- Training content, final offers/payment route, review/retention policy, payout terms and any unsupported privacy/security promises still require owner decisions under D28 and existing finance/safety decisions.

## Source-to-widget coverage

Source SHA-256: `6c48fb1786c2e52d264ad0fc4b2a07f3f29e048d4defa996ead5e6e9ce77ae29`.

| Source | Supplied screen | Native family |
|---|---|---|
| 01 | Splash Screen | `entry` |
| 02 | NetBanking Bank Selection | `commerce` |
| 03 | Pure Onboarding Carousel | `entry` |
| 04 | Add Card (Debit/Credit) — Version 1 | `commerce` |
| 05 | Host Camera Permission Prompt | `entry` |
| 06 | Home Feed (Queue & Instant Match) | `home` |
| 07 | Notification Permission Dialog — Version 1 | `entry` |
| 08 | Host Nearby Devices Permission Prompt | `entry` |
| 09 | Notification Permission Dialog — Version 2 | `entry` |
| 10 | Host Earnings & Withdrawal History | `commerce` |
| 11 | Feed Loading (Skeleton State) — Version 1 | `home` |
| 12 | Add Card (Debit/Credit) — Version 2 | `commerce` |
| 13 | Host Audio Permission Prompt | `entry` |
| 14 | Almost Done & Verification Pending | `entry` |
| 15 | Scrollable Wallet & Coin Recharge | `commerce` |
| 16 | Payment Failed | `commerce` |
| 17 | Boy Customer Profile | `home` |
| 18 | Call Rating & Feedback | `call` |
| 19 | Getting Started & Training Video | `entry` |
| 20 | Girl Creator Profile | `home` |
| 21 | Payment Processing | `commerce` |
| 22 | Edit Profile (Girl Creator) | `home` |
| 23 | Earn While You Listen (Creator Onboarding) | `entry` |
| 24 | Host Call Logs & Earnings (Girl Creator) | `home` |
| 25 | All Payment Methods (Scrollable) | `commerce` |
| 26 | Community Guidelines & Agreement | `entry` |
| 27 | OTP Verification (Animated Success) | `entry` |
| 28 | Voice Verification (Girl or Boy) | `entry` |
| 29 | Host Audio & Video Dynamic Call Controls | `home` |
| 30 | Phone Login with Multi-Number Instant Selector | `entry` |
| 31 | Customer Recent Sessions | `home` |
| 32 | Feed Loading (Skeleton State) — Version 2 | `home` |
| 33 | Active Ludo Game Board on Call | `call` |
| 34 | Home Feed (Multi-Offer Coin Carousel) — Version 1 | `home` |
| 35 | Help & Support Category Selection | `commerce` |
| 36 | Live Video Call (Background Feed & Face Censor Box) | `call` |
| 37 | Call Conflict & End Call Alert | `call` |
| 38 | Host Video Call (Customer Face Hidden) | `call` |
| 39 | Home Feed (Multi-Offer Coin Carousel) — Version 2 | `home` |
| 40 | Host Active Ludo Game (Diamond Earnings) | `call` |
| 41 | Home Feed (Instant Match Filter Sheet) | `home` |
| 42 | Nearby Devices Permission Dialog | `entry` |
| 43 | Home with Flat ₹800 Off Offer Sheet | `home` |
| 44 | Home Feed - Nightshift | `home` |
| 45 | Home with Flat ₹2000 Off Offer Sheet | `home` |
| 46 | Host Video Call (Diamond Earnings) | `call` |
| 47 | Camera & Video Permission Dialog | `entry` |
| 48 | Host Audio Call (Diamond Earnings) | `call` |
| 49 | Host In-Call Ludo Invite (Host View) | `call` |
| 50 | Active Audio Call (Centered Companion) | `call` |
| 51 | Live Video Call & Ludo Game Board | `call` |
| 52 | Active Two-Way Video Call (Both Faces Visible) | `call` |
| 53 | Camera & Audio Permission Dialog | `entry` |
| 54 | Connecting & Finding Companion | `call` |

## Verification

- Full Flutter suite: **703 passed**, **24 existing explicit platform/time-zone skips**, zero failures, 28 seconds. No authorization/lifecycle assertions were removed or relaxed.
- All **54 native widget variants** render at **390 × 844** with **1× and 2× text scaling**. The 110-case catalogue run also checks exact source coverage and verifies that opening previews performs no API operation.
- Live integration checks cover wallet navigation, Customer denial from Listener earnings, unauthenticated review versus protected routes, active-call priority, and the native filter sheet with an account-fenced stale callback.
- Native commerce has 35 focused checks, including Tamil live wallet/earnings/support/bank/card/method layouts and interactions at 390 × 844 with 2× text. Design-review copy remains English; this is not a claim that every sample screen is translated.
- Focused entry checks pass (30 including existing flows); call designs add 31 checks and retain 36 matching/video/allowance regressions. Initial overflow failures in feed badges, coin-pack cards, call PIP and enlarged text were corrected. Primary mode/availability actions were moved above the fold on short screens.
- Final `flutter analyze`: **no issues found**. Repository/contracts/boundaries/secret guard and **27 tooling tests** pass. The required fresh audio reference run passes **3/3** under pinned Node 24.13.0; no audio tariff or runtime implementation changed.
- Independent reviews found no blocking authorization, live payment, permission, call-lifecycle or preview-mutation regression. Review also prompted full live Listener/Profile compositions and Tamil commerce copy, rather than relying on theme changes alone.

The ARM64 debug QA APK builds successfully as `com.agilandeenadhayalan.nightshift`, version code **6008**, with the existing private Firebase configuration and debug signer. The build verifies all **31 native libraries**, 16 KB ELF/ZIP alignment and official `zipalign`, and compares 254 source inputs plus private/tool/evidence hashes before and after compilation. The ignored build record is sealed against the final source commit after review.

Local APK: `artifacts/nightshift-native-designs-6008-arm64.apk` (163,511,997 bytes), SHA-256 `a30426cdb67a77ebb42b67bd56f62fa1d442536b6b7ec52c74cde76344141d8d`. Private configuration, APK, capture images and provenance records remain outside Git. This does not attest every external SDK/package-cache input.

Physical device/TalkBack/media verification, pixel-identical comparison to every supplied HTML image, installation and production readiness are not claimed. Neutral native avatars and the painted mascot replace external sample portraits; live discovery does not invent sample people.
