# Server-confirmed call allowance plan

Engineering subset for FA-030. Active branch `codex/server-confirmed-call-allowance`, stacked on `codex/audio-teardown-hardening` at `3b485d19f10127e89160df6a3baa476564dca2dc`. The parent passed backend, Android and staff CI in run44867803273. Verify this branch's exact-head CI before publishing final completion evidence.

## Outcome and acceptance boundary

The active call shows the frozen audio/video rate, current server charge/illustrative earnings, confirmed connected time and remaining allocated connected time. Add accurate English/Tamil warning copy for limited test credits versus the development duration cap, and explain uncharged reconnect gaps and automatic termination if recovery fails. Keep End/report/block reachable at large text sizes. These address FA-030's existing call display/low-balance/grace criteria; physical headset/screen-reader and upstream FA-026/028/029 acceptance remain separate.

Remaining allowance is `max(0, maxDurationSeconds * 1000 - connectedMs)` from the authenticated call snapshot, not a client clock countdown. It never independently ends a call or creates a charge. The cap is total healthy connected time, not free seconds plus purchased time. A 60-test-coin audio reservation permits 60 healthy seconds: free through 40 seconds, a 60-coin minimum charge at 40.001 seconds, and almost 20 seconds of allowance still remaining. The current held wallet balance cannot be used to infer in-call remaining time or low funds.

## Boundaries

- Add optional `Call.durationLimitReason` with `test_credit_balance` or `test_duration_cap`. New server projections derive it from the frozen max duration under the existing 600-second development cap. Keep absence valid for historical events and idempotent cached responses. A missing legacy reason uses neutral allowance wording; clients do not infer a balance reason. Unrecognized wire enum values retain the existing invalid-response handling; do not loosen generator templates.
- No migration, change to rates, free threshold, minimum charge, caps, reservations, holds, settlement or End authorization. No production price/provider/purchase promise.
- Warn at one minute or less of confirmed remaining allowance. A static warning is sufficient; do not create a repeating screen-reader announcement every snapshot. At zero, show that allowance is exhausted and await server confirmation; retain End and uncertainty handling.
- During ringing/reconnect, do not consume allowance locally. Mark confirmed values and preserve existing stale/offline status. Do not show a reconnect countdown without a server deadline. Use clear limited-recovery copy without claiming a wall-clock guarantee.
- Exactly Customer and Listener modes remain. Staff tooling is separate. No phone installation or live runtime/provider change follows from this slice.

## Ownership and verification

Backend owns service projection and isolated database/HTTP regressions: balance/cap distinction, minimum-bill boundary, reason frozen despite wallet changes, legacy cached receipts and authorization/schema behavior. Contract lane owns public/event schema definitions and generated clients with drift/compatibility checks. Mobile owns models, narrowly scoped call display and meaningful widget tests for both modes/media, stale/reconnect/zero values, caller-clock changes, English/Tamil 2x text and accessible controls. Root owns integration, evidence, issue status and draft publication.

Run affected tests first, then required backend/mobile/contract checks proportionate to the final changes. Record actual counts without combining overlapping suites. Preserve earlier failure evidence. Any audio behavior change also runs `node --test` from `audio/`. Publish a draft stacked PR and verify CI for its exact final head. Do not close the whole issue from synthetic tests or bypass the physical and release gates.

## Recorded execution

- [x] Implement the optional reason, generated compatibility and server projection without financial/lifecycle changes.
- [x] Implement accessible Customer/Listener audio/video display with confirmed allowance and distinct warnings.
- [x] Independently review and verify: 447 Flutter, 396 full backend integration, 74 API, 7 domain, 3 audio reference and 11 tooling tests; 90 generated files match. The unchanged backend rerun passed after existing PostgreSQL/Redis services were restored from an outage; failed logs remain preserved.
- [x] Build configured ARM64 APK6006, verify its signature and all 31 ELF/ZIP alignments, and record 215 source/four private input hashes. No installation.
- [x] Publish draft PR83 stacked on PR82; backend, Android and staff CI passed for final head `f9a9238c49cc0a28376ec498d2de9d755bd66a16` in run44870326491.
