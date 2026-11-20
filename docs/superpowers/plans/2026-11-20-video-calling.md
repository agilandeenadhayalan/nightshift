# NightShift Video Calling Implementation Plan

> **For agentic workers:** Use the subagent-driven-development workflow, with independently owned files implemented in parallel under the active session's delegation instructions. Steps use checkbox tracking.

**Goal:** Add explicitly consented one-to-one video calls to the existing private Android test app.

**Architecture:** Extend immutable call media/rate snapshots and the existing claims/settlement lifecycle. Add a camera-capable Agora adapter, local preflight and video UI; keep audio compatibility and generated contracts.

**Tech Stack:** Flutter 3.27.4/Dart 3.6.2, Agora Flutter 6.5.3, NestJS/PostgreSQL/Redis, Node 24.13.0.

**Spec:** `docs/Video_Calling.md`, `github/issues/FA-057.md`, `github/issues/FA-058.md`.

## Global Constraints

- One Android application ID `com.nightshift.app`; exactly Customer and Listener modes.
- Test credits only; credentials and local databases outside Git; no call recording.
- Audio compatibility and the existing `audio/` tests must pass.
- Video rate fixture: 120 coins/minute, 40-second free threshold, 60-second minimum, 120,000 microcredits/second; audio remains unchanged.
- Default-off `VIDEO_CALLS_ENABLED`; no production/public rollout or completed-dependency claim.
- No camera on invitation, restored session or background. Local preview requires an explicit action; publication requires call-bound consent.
- Audio fallback ends the old call and quotes a new audio invitation; no in-place repricing.

## Review Focus

- Late preview/config/join completions after cancel/background cannot reacquire a camera.
- Older audio event/idempotency JSON remains decodable without new optional fields.
- Video consent and ready flags cannot be bypassed by an old audio client.
- Concurrent audio/video invitations share one claim and one bounded spend authorization.
- Permission loss, camera off and terminal snapshots stop capture and stop healthy-time billing.

### Task 1: Backend, domain and contract

Files: `apps/api/src/{service,http,config,seed}.ts`, API tests, `packages/backend-domain`, `packages/contracts/build-contract.mjs`, generated JSON contracts, `db/migrations/005_video_calls.sql`, `infra/compose.yaml`, `.env.example`.

- [x] Add failing tariff, consent, disabled-feature, ownership/claim, readiness and migration compatibility tests.
- [x] Implement the shared interfaces in `packages/contracts/openapi.json`; freeze media/rate/consent and preserve existing audio data.
- [x] Run domain/API unit and isolated integration checks; validate contracts.
- [x] Review scope and data/privacy invariants before integration.

### Task 2: Camera-capable Agora adapter

Files: `apps/mobile/lib/core/audio.dart`, Android manifest, focused media tests.

- [x] Pin camera ownership/lifecycle behavior with a testable narrow SDK boundary where needed.
- [x] Implement `CallVideo` in `apps/mobile/lib/core/audio.dart`: preview, video join, capture controls, readiness, quality adaptation and reliable release.
- [x] Preserve audio behavior and logging privacy; analyze and test the affected adapter.
- [x] Review asynchronous teardown and camera-off behavior.

### Task 3: Controller, models and generated API integration

Files: `apps/mobile/lib/core/{controller,models,api}.dart`, `apps/mobile/test/fakes.dart`, controller/API/model tests, generated Dart SDK.

- [x] Add tests for explicit consent, stale preview work, denied camera, restored-call behavior, video readiness and local teardown before network acknowledgement.
- [x] Implement the controller/model interfaces in `packages/contracts/openapi.json`; integrate new backend fields and endpoint through the generated SDK.
- [x] Regenerate/check the SDK and run focused controller/contract tests.
- [x] Review races between preview disposal, accepted-call join and end.

### Task 4: User interface

Files: `apps/mobile/lib/features/screens.dart`, `video_preflight.dart`, `video_view.dart`, `message_copy.dart`, widget tests.

- [x] Add tests for discover/video invitation, preview consent, denial/cancel, camera controls and fallback price disclosure.
- [x] Implement the preflight and active-video views using the controller interfaces; label audio/video in history.
- [x] Keep Tamil/English controls, reachable End/report buttons and large-text layouts.
- [x] Review privacy copy, explicit consent and fallback behavior.

### Task 5: End-to-end verification and delivery

- [x] Run repository guards, types/builds, isolated backend integration, all Flutter tests/analysis and `audio/` Node tests.
- [x] Build a debug APK; enable the private test flag only for the authorized local stack, apply additive migration and preserve prior histories.
- [x] Record actual physical results or remaining two-phone checks; do not start cameras without explicit tester action/consent.
- [ ] Update issue evidence and owner decisions, perform independent review, create a draft PR referencing #57/#58 and monitor CI.

## Execution rulings

The user's request authorizes implementation now; existing instructions say to continue independent engineering past external blockers. Engineering proceeds without another design-approval prompt. Private video can be developed while the broader #26/#28/#37/#56/#58 release gates remain open. Separate file ownership permits parallel backend, media and UI work; the root integrates controller/contracts and reviews the combined result.
