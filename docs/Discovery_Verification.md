# Discovery, live availability and favorites

Continuation of #18–20 on top of account checkpoint `900c1ab`. NightShift remains one application with Customer and Listener modes; staff tooling remains separate. This is an engineering slice using test credits, not a claim that all launch dependencies have passed.

## Implemented behavior

- Discover and Favorites load 20-card pages from an owner/language/filter-bound five-minute view. Membership and rank remain stable while scrolling; refresh starts a new view. Current eligibility is checked again for each page and update. Available, busy and offline cards are distinct; offline and busy cards cannot start calls.
- The mobile client maintains stable card IDs independently of live status. Busy, offline, removed and stale updates disable call actions and already-open audio/video confirmations. Order refresh waits for an idle list near its top or an explicit refresh. Pending results are fenced to the account, API origin, language and view.
- Socket updates are limited to the current subscribed visible slice, with at most 40 actually served IDs. A new subscription immediately invalidates the previous one. At most one validation plus the latest queued subscription is retained, preventing delayed requests from restoring old filters. Server updates recheck session authority and compare subscription revision before delivery.
- Favorites are private and idempotent. Adding a favorite and blocking a pair use sorted participant locks; either-direction block deletes both corresponding favorites. A saved favorite can still be removed after eligibility changes. Current Recents availability is fetched separately from the historical call outcome.
- Explicit local blocks persist as account-scoped tombstones so delayed pages, status responses or socket events cannot restore a blocked card. Confirmed favorite intent survives older payloads. Account/origin changes clear private directory state.

## Limits and data handling

A development view takes at most 2,000 UUID-ordered eligible candidates before availability ranking. The `truncated` flag is visible in the app. A refresh cannot promise access to candidates outside that fixed cap, and an empty truncated view does not establish no supply. Four live views per owner bound retained state; evicted or expired views require refresh. These limits remain engineering defaults pending production capacity review.

Migration 011 stores only view owner/filter/expiry, member IDs/ranks/served markers and opaque cursors. It copies no names, phone data, samples or balances. Expired views have bounded cleanup; suspension erases owned views and member references in the same transaction. Calls independently revalidate eligibility and never treat directory membership as authorization.

Directory updates use a separate bounded worker so they do not delay call recovery. It checks subscribed slices approximately once per second and emits changes or a 15-second freshness update. This is segmented polling and delivery, not an event-driven global presence service. The functional fan-out test uses three sockets; it is not the sustained load evidence required by #52.

## Verification

The complete npm/Turbo PostgreSQL/Redis/HTTP/socket suite passed **177/177** checks (155 existing plus 22 new directory cases). It covers stable unique pagination while statuses change, eligibility combinations, missing/evicted/expired or foreign cursors, real deletion, busy claims, favorite retries, block races, revoked owners, late subscription/update races and scoped delivery. In the simultaneous Tamil/English/unsubscribed test, a Tamil-only change produced event-count deltas **1/0/0**. No unrelated listener or language was sent to those subscribers.

The final migration-only member index was subsequently verified through **10/10** fresh/forward schema tests. API/provider unit tests passed **43/43**. Exact generation matched all **74** Dart SDK files. Repository secret/contract/boundary checks and **10/10** tooling tests passed. The generated Dart account journey also passed against a real isolated HTTP backend, including enrollment, private WAV upload/download, deletion receipt recovery and tombstone rejection; its Firebase verifier was synthetic.

`scripts/test-presence-restart.cjs` additionally passed against this directory runtime: a real isolated Redis process restart lost the lease and reconnected the same client in **1,335 ms**, while both database-owned call claims survived. Re-heartbeat did not reopen the busy Listener; another reservation returned `LISTENER_BUSY`, and ending the call produced one terminal event. This uses synthetic media readiness and does not prove physical RTC continuity.

The mobile analyzer is clean and all **279 Flutter tests pass**. Independent focused review passed **34/34** tests, including an actual two-origin socket redirect regression: the original adapter sent a synthetic auth value to a redirect target; the fixed adapter does not, while same-origin authentication still succeeds. The connector pins its origin, refuses redirects, bounds the complete handshake and closes late connections. Other corrections cover malformed/contradictory status, blocked-account restoration, delayed refresh expiry/freshness, call confirmations and account changes during safety teardown. No real token was used in redirect tests.

The Firebase-enabled ARM64 debug APK built successfully: `artifacts/nightshift-firebase-discovery-arm64.apk`, **180,964,742 bytes**, SHA-256 `c37cf61690dbe6945eed4a503ffa4ac9cdb09170d244b2dee90b363b1875d754`. Its ignored provenance record confirms unchanged source inputs during the build and records the exact patch above `900c1ab`. Previous APKs are preserved. This build has not been installed on the phones while the owner tests the earlier identity checkpoint.

## Remaining acceptance

Physical scrolling, device/lifecycle interruption, Tamil large-text and TalkBack evidence remain. Full staff approval, provider lifecycle, public supply and release decisions retain their upstream gates. The candidate cap and worker behavior require measured capacity work before production scale claims. All related GitHub issues remain open; no automatic closing keywords are used for this slice.
