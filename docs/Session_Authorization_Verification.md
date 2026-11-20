# Session authorization continuation

Recorded 20 November 2026 for the #10 engineering subset, following discovery commit `ca5e8bd`. NightShift retains Customer and Listener modes; staff authority remains separate and unconfigured. No issue is closed by this continuation.

## Reproduced problem and resulting behavior

An HTTP authentication guard could accept a token, then a same-device refresh or logout could revoke its database session before the call service ran. Previously, the already-admitted actor could still accept a call, update readiness/metering, obtain a new RTC token, create a report, or receive an idempotency cache result. Expired or missing session hashes were also unchecked by those service operations. The first 13 regressions reproduced 11 failures, including actual HTTP routes returning success where an authentication failure was expected.

Call operations now acquire participant user locks in UUID order, validate the actor's current session/device, then lock and re-read the call. This preserves the user-before-call order used by logout and blocking. Idempotent create, action and report operations authorize before reading a cached response and retain their authorization locks through commit. A legitimate refreshed session can still retry the original operation without duplicating its effects. There is no missing-session or test-actor bypass.

Accept, media readiness and RTC token issuance also share the current adult/suspension, Listener approval, pair-block and unreleased-hold checks. Added regressions first reproduced missing accept/media eligibility checks, then passed with this shared guard. Current participants can still end, cancel or decline; withdrawing availability alone does not invalidate an existing invitation or call. Unauthorized attempts leave readiness, metering, events, reports and settlement unchanged.

## Verification

| Check | Evidence |
| --- | --- |
| Before/after session regressions | `artifacts/call-authorization-before.log`: 11 failures in 13 checks; the initial fix passes all 13 in `call-authorization-after.log` |
| Before/after eligibility regressions | `artifacts/call-eligibility-before.log`: accept/media rejection failures; final implementation covers those cases |
| Final targeted PostgreSQL/Redis/HTTP suite | 19/19 pass in `artifacts/call-authorization-final.log`; includes four guard-delayed HTTP races, expired/missing sessions, current-session retries, logout/cache denial, no extra durable writes, opposite-party block/media/token ordering and a single terminal event |
| API compile and unit suite | Compile succeeds; 43/43 pass in `artifacts/call-session-api-unit.log` |
| Full integration regression | 196/196 pass, with zero failures/skips/cancellations, in artifacts/call-session-integration-final.log; affected legacy suites also pass 33/33 after their authentication expectations were corrected |
| Repository checks | Secrets, contract build, package boundaries and 10/10 tooling regressions pass in `artifacts/session-verification-repo.log` |
| Preserved audio reference | `node --test` from `audio/` passes 3/3 under Node 24 |
| Independent review | Ordered locks, idempotent responses, current-session retries and the eligibility/stop-action boundary reviewed without a remaining blocker |

The integration tests use a dedicated test database with random schemas, synthetic identities and isolated Redis keys. They do not read or mutate the live phone-test database or Redis database 13. No migration, HTTP contract, rate, financial policy or customer-facing mode was added.

## Phone verification changes and remaining evidence

The same branch contains the debug-only Firebase browser-verification selector and the expired resend-warning correction. The selector keeps app verification enabled; the resend-warning correction never requests a code automatically. The full mobile suite passed 286/286 after the selector; the subsequent warning correction passed 41 focused checks and analysis. Build provenance and the confirmed Redmi owner result are recorded in [Firebase development setup](Firebase_Development_Setup.md). The isolated device server continues running the earlier baseline, so physical phone testing does not establish these new backend race fixes.

The parent [discovery PR #74](https://github.com/agilandeenadhayalan/nightshift/pull/74) passed both backend and Android checks at exact commit `ca5e8bd` in [run 44786641185](https://github.com/agilandeenadhayalan/nightshift/actions/runs/44786641185). That result does not substitute for checks on this continuation.

Local database locks serialize local session revocation and account restrictions. They cannot make a remote provider revocation after an already-completed token verification atomic, or revoke an already-issued Agora token immediately. Actual provider/device revocation behavior, provider-side media cutoff, separate staff MFA/permissions, and the remaining issue dependencies retain their existing acceptance gates.
