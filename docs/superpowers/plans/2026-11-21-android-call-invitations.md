# Android call invitations implementation plan

Issue: FA-029 / [#29](https://github.com/agilandeenadhayalan/nightshift/issues/29), with existing FA-023/026/027 foreground test-credit evidence. Branch: `codex/android-call-invitations`, stacked on PR80 at `603a4cb52882e648eb17d2dd3e85e86306322e54`. Parent local verification is complete and backend, Android and staff CI all passed in run44859554440.

## Outcome and boundary

An explicitly opted-in, approved Listener can receive a short-lived generic audio invitation while NightShift is in the background. Opening it restores the visible app and checks the current server call before showing the normal Answer action. Push cannot accept a call, open a microphone, issue an RTC token, extend ringing or charge a wallet.

Incoming background invitations and ongoing background media are separate capabilities. This slice implements the former. Accepted calls retain the existing foreground-only media/leave/end behavior. Ongoing background audio still requires an independently proven engine lifetime, supported audio-focus ownership, interruption readiness and actual capture teardown. No FGS, Core-Telecom, native End action, camera continuation or automatic answer is introduced here. FA-029 remains partial until its physical and ongoing-call checks pass.

Push configuration defaults off. No production policy, staff approval, live migration, device installation, IAM change or provider send is inferred from synthetic tests. During implementation the owner approved permanent package `com.agilandeenadhayalan.nightshift`; its matching Firebase Android app and existing verified local debug signing fingerprints were registered. The owner subsequently confirmed all three prepared Play declarations and authorized app creation; the NightShift dashboard is now verified. Incorporate that package in the new build and FCM restriction while preserving the existing installed test app/server until a coordinated upgrade. See D08, Firebase setup and the launch decision record for these actual external changes and the account-specific closed-test requirement.

## Frozen interface

- Current verified phone session and completed adult onboarding are required. Owner/device/canonical identity/auth_time come from server authentication. Same-device token refresh preserves lineage; logout, fresh sign-in, takeover, deletion or restriction invalidates it.
- `PUT /v1/me/push/registration`, Idempotency-Key, body `{targetKind:'fcm_token',token,expectedVersion:integer|null}` prepares a registration. Token is write-only opaque printable ASCII, 1..4096 bytes; reject unknown fields and bodies over 8KiB. Encrypt it with private AES-GCM material and use a separate keyed digest for uniqueness. No raw token in responses, generic idempotency records or logs.
- Native installs the returned binding durably before `POST /v1/me/push/registration/activate`, Idempotency-Key, body `{registrationId,expectedVersion,bindingId,notificationPermission:'granted',backgroundInvitations:true,capabilityVersion:'android-audio-invitations-v1',consentVersion:'background-invitations-v1'}`. Activation attests client-observed notification capability; it is not OS attestation or proof of delivery.
- `GET /v1/me/push/registration` returns `{registration:PushRegistration|null}`. `DELETE /v1/me/push/registration`, Idempotency-Key, requires `{registrationId,expectedVersion}`. Exact version fences late disables/results. Fresh auth precedes cached mutation receipts.
- `PushRegistration`: `{id,version,bindingId,targetKind:'fcm_token',state:'prepared'|'active'|'revoked'|'expired',backgroundInvitations,leaseExpiresAt:string|null,serverTime,testOnly:true}`. Use ISO UTC dates and positive versions. Prepared expires after five minutes; active opt-in lease is at most 30 minutes and never beyond valid local session authority. No push-driven renewal.
- Data-only FCM payload, all strings, at most 2KiB: `schemaVersion:'1'`, `type:'call.invitation'|'call.terminal'`, `callId`, `eventId`, `callVersion`, `expiresAt`, `registrationId`, `registrationVersion`, `bindingId`. IDs are UUIDs, numeric versions are positive decimals. No user identity, name, phone, bio, wallet, private review, token, URL or arbitrary display copy.
- `reachability:'foreground'|'background_eligible'|'offline'` is projected consistently in directory/favorites/status. `online` continues to mean real matching-version foreground presence. Audio can use a current eligible notification lease; video requires foreground presence at list and final reservation checks. Busy/blocked/restricted/session-invalid states still override availability.
- Foreground presence retains FA-017's existing 45-second freshness bound. Backgrounding with a valid invitation opt-in stops heartbeats while preserving availability intent; it does not immediately erase the last foreground lease. A video invitation may therefore be offered during that residual interval. The background client cannot accept it or report ready media. Immediate visibility withdrawal needs a separately versioned protocol that also fences queued heartbeats; it is not claimed here.
- Sender/receiver use one shared set of synthetic payload fixtures. Native suppresses wrong binding, expired lease/invitation, duplicates and older versions, and persists bounded terminal tombstones. PendingIntents use immutable explicit components and scoped call/action identities. Notification tap is a hint; authenticated GET is authority.

## Backend task — account_backend

- [x] Add migration017 and registration/CAS/lineage invalidation, private token encryption/digest, safe idempotency and bounded opt-in lease.
- [x] Add fixed-endpoint official FCM HTTP v1 transport, dedicated credential provider/scope, bounded response/read timeout, no hidden retries or redirects, no DB locks across network. Pin a direct auth-library dependency if imported; own the npm lockfile.
- [x] Add independent durable push jobs/attempts and no-overlap worker. Socket outbox delivery never consumes FCM work. Invitation preflight requires current ringing; terminal-dismissal preflight requires an authorized newer non-ringing state and the original remaining invitation lifetime. Both validate current recipient/binding/lineage and exact leased attempt.
- [x] Bound provider attempts to two and the original deadline; honor documented Retry-After/minimum retry delay. Unknown response is unknown delivery. Late NotRegistered affects only the exact sent target generation. Rotation and cancellation cannot revive or extend calls.
- [x] Share one reachability predicate across directory, direct audio and matching, rechecking authority/time after asynchronous presence waits. Video stays foreground-only.
- [x] Add real isolated PostgreSQL/Redis/HTTP registration/delivery/race tests and synthetic transport tests; register suites and migration expectations. Do not use live Redis13 or FLUSHDB.

## Native, Flutter and contract task — account_mobile

- [x] Update source public contracts and regenerate the SDK after confirming backend shape. Own only contract/generated/mobile files; backend owns API/runtime/lockfile.
- [x] Deliberately initialize native default Firebase with the existing validated public build configuration while preserving the named phone-auth app. Use one native Messaging receiver, token mode explicitly selected, auto-init initially off and no competing Flutter receiver.
- [x] Implement strict receiver/binding/tombstone policy, explicit notification permission/channel checks, generic localized notifications and authoritative Open recovery. Native logout clears binding and visible notices before awaiting network cleanup; stale token/registration completions cannot attach a new account.
- [x] Implement prepare -> durable native bind -> activate with frozen mutation keys and explicit unknown-response recovery. Provide localized opt-in/expiry/offline/permission-denied states. Preserve availability on background only with a current confirmed invitation lease; accepted calls retain foreground-only teardown.
- [x] Make SDK interruption/capture failure clear media readiness without allowing stale recovery to resurrect a call. Do not introduce a second focus or routing owner. Clearly distinguish fixture evidence from actual output-focus observation.
- [x] Add Kotlin reducer/bridge and Flutter lifecycle/registration/expiry/account-switch/Tamil-large-text tests. Run analysis, full Flutter tests, generated-client checks and appropriate native tests/build.

## Root integration and independent review

- [x] Resolve proposal review findings: one schema key; type-specific terminal dispatch; no conflation of incoming notifications and ongoing media. No destructive native End queue is needed in this slice.
- [x] Independently review privacy, authority, native cold-process behavior, absolute expiry/clock uncertainty, unknown responses, session invalidation and concurrency. Fix demonstrated defects and rerun affected checks.
- [x] Run complete appropriate backend/mobile/contracts/repository verification and required `node --test` from `audio/`. Inspect manifest/permissions and native artifact alignment without claiming physical compatibility from static inspection.
- [ ] Record exact evidence, feature configuration, migration/recovery and remaining acceptance in verification docs and the issue register. Publish a reviewable draft PR stacked on PR80, then verify exact-head CI.
- [ ] Continue ongoing-call compatibility work and selected-device acceptance when prerequisites permit. Physical matrix includes locked screen, notifications denied/channel off, Doze/battery restrictions, offline/API-unreachable, rotation, logout/account switch, expired notice and foreground Answer. FCM arrival alone does not establish the USB-forwarded control API is reachable.

## Isolation

Use Node24.13.0, existing Flutter3.27.4 and the existing worktree/cache. Test database schemas must be isolated; Redis14/15 only. Coordinate DB suite runs to avoid shared-key interference. Preserve the owner's checkout, live schema14 runtime, existing private credentials, installed APK4002, staff approval gates and paid SMS budget. This task has no new SMS sends. Root owns the dedicated credential provider, its12 synthetic transport tests and the APK alignment gate/9 malformed-binary fixtures; backend owns the remaining runtime/DB tests and mobile owns native/Dart/contracts. The invitation capability is API26+ so OS timeout cleanup is supported; Android23–25 retain foreground calls.
