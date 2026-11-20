# Account Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Complete the executable phone sign-in, session, adult profile and language paths before downstream listener and account-lifecycle work.

**Architecture:** Keep one Customer/Listener Flutter app and the shared NestJS/PostgreSQL backend. Firebase ID tokens identify phone sessions; every authenticated phone request checks provider verification and local revocation. Pending onboarding has a restricted session with no discovery, calling, wallet or Listener access.

**Tech Stack:** Flutter 3.27.4, Dart 3.6.2, NestJS, PostgreSQL 17.7, Redis 7.4.7, Node 24.13.0, generated OpenAPI Dart client.

**Spec:** github/issues/FA-009.md through FA-012.md; docs/Engineering_Contracts.md. The complete backlog and external decisions are tracked separately in docs/Backlog_Completion_Plan.md and docs/Launch_Decisions_Required.md.

## Global Constraints

- Exactly Customer and Listener modes; staff tooling stays separate.
- Use issue acceptance criteria and dependency order. Private engineering does not waive external release gates.
- Test credits only; production startup remains disabled. No new phone identity receives credit or Listener entitlement.
- Secrets, provider credentials and local databases remain outside Git.
- Existing audio/video flows and the independent audio reference remain runnable.

## Review Focus

- Concurrent token refresh, logout and stale responses must not restore a revoked identity.
- Underage, invalid calendar dates and immutable DOB updates must fail before service access.
- OTP/provider timeouts must not automatically repeat a chargeable SMS or authentication mutation.
- Private DOB, phone, proposed nickname and provider tokens must never enter discovery or logs.
- Tamil large text, restart during onboarding and disabled provider configuration must yield usable recovery.

### Task 1: Backend phone sessions and adult onboarding

**Files:** apps/api/src/auth.ts, identity/phone-auth.ts, http.ts; new account module; db/migrations/006_account_onboarding.sql; apps/api/test/account.integration.test.ts.

**Interfaces:** POST /v1/auth/exchange accepts idToken/deviceId and returns token/expiresAt/user/needsOnboarding/testOnly. GET and PUT /v1/me/onboarding use OnboardingState. Profile fields: displayName, avatarCode (moon/star/leaf/wave), interfaceLanguage (ta/en), speaking languages (ta/en), dateOfBirth (YYYY-MM-DD or null in response). Completion additionally requires consentVersion adult-onboarding-v1.

- [x] Add failing authorization, date-boundary, device and revocation regressions.
- [x] Implement hash-only phone sessions with live Firebase verification, restricted onboarding access and durable device policy.
- [x] Implement atomic immutable DOB/18+ gate, built-in avatars, private pending nickname, versioned development consent and language preferences.
- [x] Run real isolated PostgreSQL/Redis integration tests and TypeScript checks.

### Task 2: Versioned generated contract

**Files:** packages/contracts/build-contract.mjs, openapi.json, events.schema.json and generated dart/ SDK.

**Interfaces:** exchangePhoneSession, getOnboarding, completeOnboarding; existing User stays unchanged.

- [x] Add bounded strict request/response schemas and document restricted onboarding authorization.
- [x] Generate the official Dart SDK and run exact regeneration drift checks.
- [x] Validate backend HTTP responses and malformed generated-response regressions.

### Task 3: Flutter phone identity and onboarding

**Files:** apps/mobile/lib/core identity/session/controller/api modules; features phone/onboarding screens; app routing; targeted tests.

**Interfaces:** The original custom-token checkpoint used OTP request/verify and secure application refresh-credential storage. The owner's provider change now uses native Firebase phone verification and SDK-managed credentials, with a secure backend-accepted identity marker. Both register through exchangePhoneSession; coalesced refresh updates server binding without replaying a mutation. Native changes receive their own review in Task 7.

- [x] Add failing OTP, expired-token, stale-response, restart and age-error UI regressions.
- [x] Implement explicit phone consent, OTP cooldown/recovery and provider configuration unavailable state.
- [x] Implement secure token exchange/refresh/logout and restricted onboarding routes.
- [x] Implement localized adult profile and separate interface/speaking-language choices.
- [x] Run Flutter analysis, tests and ARM64 debug build.

### Task 4: Review and evidence

- [x] Review backend and mobile boundaries independently; resolve security and correctness findings.
- [x] Run repository gates, full unit/integration/economics suites, exact client regeneration and Android build.
- [x] Record actual evidence and remaining provider/device/owner gates without closing incomplete issues.
- [ ] Commit a reviewable change and open a stacked PR; monitor required CI to completion.

## Execution decisions

- Reuse the clean existing linked worktree at C:/Users/agila/.codex/worktrees/fa008-ui-foundation/NightShift, branching codex/backlog-completion from PR #72. The original D:/Learning/NightShift owner edits remain untouched.
- User requested completion of all issues, authorizing implementation now. Continue with independent work while external decisions are pending; no separate plan-approval pause.
- New nicknames stay private pending moderation; public aliases remain safe until the review workflow is implemented.
- Owner subsequently selected Firebase project nightshift-c3e1a; Android registration is complete, billing disabled, private client configuration ignored. The initially created separate project is unused. See Firebase_Development_Setup.md.
- Account code and 19 backend regressions passed an 86-test integration run. Independent review found and corrected authentication-lineage logout/refresh races, invalid enum types and nullable SQL identity metadata. Mobile account implementation passed with new regression coverage; final combined branch checks remain below.

### Task 5: Consent and deletion foundation (#16)

**Files:** apps/api/src/account-lifecycle.ts; db/migrations/007_account_lifecycle.sql; apps/api/test/account-lifecycle.test.ts; apps/mobile account lifecycle controller/screens/tests; generated contracts and http.ts.

**Interfaces:** owner GET me/consents and me/deletion-notice; POST me/deletion-requests with noticeVersion/confirm/32-byte random hexadecimal receiptToken; public POST account-deletion/status with the private capability only. Fresh trusted Firebase auth_time must be at most 300 seconds old; a token refresh is insufficient. No public method clears retention holds.

- [x] Implement immediate access withdrawal, private-profile erasure, narrowly scoped evidence holds, immutable journal preservation and internal recovery.
- [x] Run 18 isolated database/HTTP tests including stale/fake step-up, ownership, capability recovery, financial and scoped evidence holds, underage privacy and storage retry.
- [x] Implement localized mobile consent history, explicit deletion confirmation, secure pre-submit receipt persistence and login recovery without repeating the deletion command.
- [x] Complete independent cross-module review, combined suites and build for the account checkpoint.

### Task 6: Private listener applications (#13)

**Files:** apps/api/src/listener-applications.ts; db/migrations/008_listener_applications.sql; apps/api/test/listener-applications.test.ts; apps/mobile listener application controller/screens/tests; HTTP/config/contracts.

**Interfaces:** create/update/get draft, owner-bound five-minute upload lease, raw PCM WAV upload/read, idempotent submit/withdraw. WAV files are 2–60 seconds and at most 2 MiB in an explicitly configured private local directory. Bio/topics/review consent are private; a sample never proves age, gender or identity. No app user gains approval from submission.

- [x] Implement bounded file/signature/duration checks, capabilities, ownership and consent state transitions.
- [x] Implement and test private file selection/upload, draft recovery, submission and withdrawal in Flutter; physical document-provider testing remains separate.
- [x] Verify interrupted uploads, cross-owner access, expired leases, duplicate submission, deletion cleanup and safe HTTP error envelopes.
- [x] Complete independent review and combined verification; record remaining staff/storage/provider gates.

### Task 7: Owner-selected native Firebase paid SMS

- [x] Replace the selected mobile flow with native Firebase Phone Authentication for India, preserving the Customer/Listener product shape.
- [x] Add consented application admissions and exact phone-proof/opaque UID mapping, canonical legacy-account convergence, revocation and deletion restrictions.
- [x] Generate the admissions/exchange SDK and pass the real generated-client journey without live provider traffic.
- [x] Register the debug signing fingerprints. After explicit owner approval, enable Phone/Play Integrity and save the India-only SMS allowlist.
- [x] Run 140 database/HTTP/schema checks, 43 API unit checks and exact 69-file SDK drift verification; build the initial native ARM64 APK.
- [x] Finish mobile cancellation/partial-storage-failure and stalled-SDK review regressions; all 235 Flutter tests and analyzer pass, final APK rebuilt, independent focused review passed 21 tests.
- [ ] Complete the original Task 4 evidence/PR/CI package.
- [ ] Configure billing and private Admin permissions and complete consented real-SIM tests after the billing account and monthly budget are supplied. The owner approved 1,000 SMS/day as an operating limit; no hard provider cap is implied.

The earlier account checkpoint is committed as `9e853bb`; its preserved APK and 213 Flutter tests are historical evidence. Current native-flow evidence is recorded in Account_Application_Verification.md. No product issue is closed solely because its local engineering subset passes.
