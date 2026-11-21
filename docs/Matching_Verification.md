# Bounded opt-in audio matching

Prepared 21 November 2026 for FA-024, using the existing FA-019/021/022/023 directory, pair checks, reservations and invitations. This branch implements the test-credit audio flow. Production review, payments, background delivery and physical-device acceptance remain their separate gates.

## User behavior

Customer mode offers **Find a Listener**. Before starting, the screen shows the selected speaking language, current server test-credit rate, maximum three sequential invitations and a 90-second total wait. Consent starts unchecked. Searching, ringing, declined and unanswered invitations do not charge. Each invitation lasts at most 30 seconds and cannot exceed the original deadline; less than one remaining second ends the search instead of starting an unusable invitation.

The active search shows its attempt count, remaining wait and Cancel. Only the current invitation exposes the ordinary Listener identity. Safe selection reasons describe language, current availability and fair rotation; private scores, rejected candidates and romantic-compatibility claims are absent. A no-supply result describes this bounded search, not a guarantee about the entire service.

Acceptance ends matching permanently, even if the accepted call ends before the coordinator sees it. Cancel losing to acceptance returns that accepted call; it does not turn into an unrequested hangup. After a finished match, an explicit new-search review step requires fresh unchecked consent. Matching never enables video, Listener availability or staff authority.

## Transactions and recovery

Migration016 adds Customer-owned requests, immutable attempt records, cancellation command fingerprints and committed-offer history. Database constraints permit one active request per Customer, at most three distinct sequential attempts, and one call per attempt. The source identity/device/authentication lineage and original 90-second deadline are fixed. Terminal history cannot regress.

The shared internal call-reservation primitive commits call, participant claims, test-credit hold, invitation event/outbox, matching attempt and fair-offer timestamp in one transaction. All participant user locks are acquired in sorted order before the matching request and call rows. Direct calls and mode switches respect matching ownership between attempts. Failed reservations do not consume a Listener's turn.

A separate non-overlapping worker processes at most 20 requests per pass. Durable processing order prevents a first batch of ringing requests from indefinitely starving later searches. A failed reservation rolls back its business state, rotates its scheduling timestamp separately and lets other selected requests progress before surfacing the error. Candidate scans use bounded pages and persisted continuation through stale presence entries; they do not reuse the directory's first 2,000 UUIDs. Eligibility, session expiry and the minimum usable invitation interval are rechecked after the final Redis wait. The worker reconciles prior claims/holds before choosing another Listener and cannot create a fourth invitation or extend the original deadline.

Fair rotation prioritizes time since a committed matching offer, falling back to eligibility time for a newcomer. A neutral prior handles missing acceptance history; a bounded recent-history factor and request-seeded random ties are secondary. Either-side blocks, already-tried Listeners and pair declines within ten minutes are excluded. The server does not publish the seed, ranking inputs or excluded roster.

Same-device Firebase token refresh preserves the originating canonical identity/device/authentication time. Logout, a new authentication lineage, device replacement, local identity revocation, deletion and account restrictions prevent continued search. These are local durable authority checks; they do not establish atomicity with remote Firebase revocation or prove that a remotely disabled identity was immediately observed by a background worker.

Public create/cancel operations use stable idempotency keys and current authorization before cached results. Owner-only reads restore authoritative status. Flutter freezes an uncertain mutation's key/body, performs a read before permitting an explicit identical retry, and never sends a new request from a timer. Account/origin changes fence late responses. Background/resume triggers recovery reads; it does not establish support for background media or FCM. The private existing call outbox remains the invitation mechanism.

## Verification record

The independent matching PostgreSQL/Redis/HTTP suite passed **47/47**, with no failures or skips, in **61.61 seconds**. It covers one active request, sequential declines/timeouts, zero journal movement and released holds, canonical session lineage, eligibility/safety changes, cancellation/acceptance, transactional rollback, replacement-service recovery and public contract/privacy. Deterministic regressions reproduced and then verified fixes for session expiry during admission/reservation waits, a sub-second final invitation, exhausted cancellation retries and failure of one request starving another. Early fixture failures involving concurrent insertion order and PostgreSQL statistics snapshots were corrected separately from runtime fixes.

The contention case uses 50 Customer matching requests and 50 direct-call customers, with 50 coordinator tasks and 50 direct-call tasks running concurrently. A real PostgreSQL row gate observes waiting matching and direct operations before release. The final database has one active call, two participant claims and one hold. This is functional concurrency evidence, not sustained production capacity.

The seeded 40-participant simulation gives each participant one opportunity before repeats and admits a newcomer with no acceptance history. A separate real database test creates 2,002 synthetic eligible Listeners and verifies a high-UUID newcomer receives a committed invitation ahead of recently offered established accounts. Stale Redis entries and the twenty-request worker limit also have progress regressions. These controlled populations do not establish production fairness outcomes.

The complete isolated backend regression passed **336/336**, with no failures, cancellations or skips, in **263.79 seconds**. Flutter analysis is clean and **343/343 tests** pass, including 19 matching model/transport/widget regressions. Checks cover consent, frozen uncertain requests, accepted-call routing, background/resume reads, account/origin changes, permission-dialog dismissal, changed speaking languages, a fresh search after a completed match, and Tamil at 360px/200% text. The generated Dart check passes across **84 files**. API unit/provider tests pass **43/43**, the required audio reference passes **3/3**, repository guards pass with **11 tooling tests**, and top-level TypeScript typecheck/build pass. Exact-head CI is recorded in the pull request after publication.

Actual process-kill and physical background delivery are not inferred from an in-process replacement service or simulated transport. Mutation keys remain in memory across offline/background states; a restarted process first recovers `/me/match`, and only explicit new consent can start a new request. No automatic persisted mutation replay is claimed.

## Deployment boundary

No live migration, provider message, account approval, credit grant, APK installation or private server upgrade is part of this verification. The two phones retain their prior installed build and live runtime. A later upgrade requires exact-source passing CI, a verified backup/restore, quiescence and matched API/client compatibility. Keep migration016 and its durable history on code rollback; stop new matching and reconcile active invitations before reverting a worker-capable runtime. Do not restore an old database over newer writes or drop request/call records.
