# Audio teardown hardening plan

Continuation for FA-026/028/029 on `codex/audio-teardown-hardening`, stacked on PR81 at `cd7678edac6feadfca2a250325c21124d0ff1b98`. Backend, Android and staff CI passed for that exact parent in run44864035487. Incoming invitations remain a separate implemented subset. This task adds no ongoing background-call capability, service, new provider or live rollout.

## Concrete defects and outcome

The current native cleanup waits behind the serialized SDK operation tail. If that operation never completes, End/logout and durable stop intent can wait indefinitely. Several controller cleanup continuations reread the current call/owner after an await and can affect a replacement session. Server End also advances time-based state before comparing the requested version, so its own uncommitted transition can make a valid observed-version End repeatedly fail.

Latch local readiness and stop intent immediately, request native cleanup before disk/network waits, and let owner-bound server termination and logout progress independently. Bound the caller's cleanup wait without releasing the underlying native engine ownership barrier. A timeout does not establish microphone release and cannot permit another engine. Keep normal Customer/Listener and separate staff behavior unchanged.

## Ownership and interfaces

- Mobile agent owns `lib/core/audio.dart` and focused fake-engine tests. Preserve `CallAudio.leave()` / `CallVideo.stopPreview()` signatures. A successful future requires SDK release acknowledgment; pending/failed cleanup uses stable `RTC_CLEANUP_PENDING` / `RTC_CLEANUP_FAILED` failures. Proposed caller deadline is three seconds, injectable for deterministic tests. The original completion future, never a timeout wrapper, remains the barrier to another engine. Explicitly attempt `enableLocalAudio(false)` before publication mute/leave/release, preserving supported serialization.
- Controller agent owns `lib/core/controller.dart`, any narrowly scoped stop-intent helper, and controller/media lifecycle tests. Capture account/session/origin/call authority before the first await. Each logical termination attempt freezes action, version, key and body; uncertain retry preserves them. Only a definitive conflict plus a current authenticated read may create a new version/key. Stop work must not clear a newer owner's state or hold a global guard against another call. Preserve legacy stop-marker recovery safely.
- Backend agent owns the narrow End version fix and real database regression. First reproduce the stale-media/no-recovery-worker case. Validate the command against the initially locked persisted version while retaining rejection of genuinely older versions and terminal idempotency. Test one terminal transition/settlement and no surviving claims/holds; late healthy media must not revive the call. No migration or public API expansion is planned.
- Root owns localized cleanup copy, documentation, integration and final publication. Coordinate shared fixtures rather than editing another lane's files.

Media withdrawal must not gate End. A false report can change call version or fail eligibility checks; an already in-flight positive report cannot be recalled because the existing API has no media epoch. Prevent new positive reports after local stop and use terminal End as the durable server fence. Do not claim instantaneous server withdrawal or actual capture cessation from a timeout, readiness flag or synthetic test.

## Verification and completion

- [x] Reproduce SDK stalls, cleanup errors, blocked storage and stale owner/call continuations before fixes.
- [x] Implement bounded native caller waits while retaining actual ownership, independent cleanup steps and explicit capture disable.
- [x] Implement fenced durable termination/retry and logout progress independent of SDK waits; preserve current foreground/video safeguards and pending-call semantics.
- [x] Reproduce and fix the server's self-generated End conflict without weakening concurrent version checks.
- [x] Run focused meaningful tests, full Flutter/analyzer, appropriate full backend/contract checks and required `node --test` from `audio/`. Review source independently. Final results: 403 Flutter, 388 full backend integration, 74 API unit/provider, 7 domain, 3 audio reference and 11 tooling tests; generated client has no drift. Independent reviews passed. Private ARM64 APK6005 is built, signed and statically 16KB aligned, with source/private-input provenance; no installation.
- [ ] Record measured results and limits, build/provenance as appropriate, publish a draft PR stacked on PR81 and verify exact-head CI.

Physical microphone/focus/interruption evidence remains a separate required gate. The private live server, migrations001–014, installed APK4002, provider credentials, spending limits and approval policy stay preserved during local engineering. Use isolated test schemas and Redis14/15 only; never Redis13 or FLUSHDB. No real call, SMS, push, staff grant or device installation follows from this plan.
