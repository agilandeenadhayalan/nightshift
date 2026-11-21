# Bounded opt-in Listener matching

Goal: implement and verify FA-024's locally testable audio matching flow against the existing directory, pair-eligibility, atomic-reservation and invitation mechanisms. Production identity/reviewer/device gates remain separate.

Architecture: persist one active Customer-owned request, up to three sequential call attempts and fair-offer history. Share the existing atomic call reservation primitive; never attach matching ownership in a later transaction. A separate bounded coordinator reconciles durable calls under ordered participant locks. Flutter obtains explicit consent and restores authoritative status after uncertainty or resume.

Baseline: `00c97105f97e0f512bae4ce95bde702afeff8621`, PR79. Existing linked worktree reused on `codex/bounded-listener-matching`; original checkout and live f220 runtime stay untouched. PR79 backend, Android and staff CI all passed in run44856588700.

## Fixed interface and engineering choices

- Audio only, explicit `consent: true`, version `matching-search-v1`, chosen speaking language and immutable quote. Maximum three invitations, 90-second absolute search deadline, each ringing for at most 30 seconds and never beyond that deadline. Searching/ringing do not charge.
- POST `/v1/matches` with stable Idempotency-Key; GET `/v1/me/match` returns `{request: MatchingRequest|null}`; GET `/v1/matches/:id` is owner-only; POST `/v1/matches/:id/cancel` requires expectedVersion and Idempotency-Key. Revalidate current authority before returning cached mutations.
- MatchingRequest contains id/version, state, language/audio/quoteId, attemptCount/maxAttempts, waitBudgetSeconds/invitationSeconds, createdAt/deadlineAt/endedAt, currentCallId, terminalReason, safe selectionReasons, serverTime and testOnly. States: searching, ringing, matched, cancelled, exhausted, expired, failed. No private ranking data or excluded candidate roster.
- Current call is exposed only while ringing or after matching. Once accepted_at exists, the request is permanently matched even if the call ends before reconciliation. Cancel does not terminate an accepted call.
- Use authenticated one-second polling while active and authoritative resume; existing call invitations/events remain in use. No new matching socket event is necessary for this slice.
- Same-device provider refresh preserves the originating authentication lineage; logout, new sign-in/device takeover, account restrictions and safety block end it. Matching owns the gap between attempts and prevents a direct-call/mode-change bypass.
- Eligible candidates rotate by committed offer history; newcomers have a neutral prior, recent declines are excluded, and seeded random ties are reproducible. The directory's UUID-ordered 2,000-candidate cap must not become the matching pool.

## Tasks and ownership

### 1. Backend transactions and coordinator — account_backend

- [x] Add migration016 for requests, attempts and fair-offer history with ownership, uniqueness, ordinal and deadline constraints.
- [x] Extract the shared locked call reservation primitive; preserve direct-call behavior and local-session fences.
- [x] Implement create/read/cancel, bounded coordinator, lineage/eligibility checks and mode/direct-call ownership guards. Keep full sorted participant locks before request/call locks; do not add inverse-lock callbacks inside existing call recovery.
- [x] Wire HTTP and independent no-overlap worker. Register integration tests and migration expectations.

### 2. Public contract and Flutter — account_mobile

- [x] Update source contract and regenerate the Dart client; do not hand edit generated output.
- [x] Add localized explicit consent, selected language/rate, progress/deadline, safe result and cancellation in the existing Customer flow.
- [x] Preserve one frozen create payload/key across unknown responses; recover before an explicit retry. Fence account/origin/background stale responses and route an accepted call into the existing call flow without starting another search.
- [x] Test consent, zero automatic retry, cancellation/acceptance races, resume, localization and large text; run analysis/full Flutter suite and generated-client check.

### 3. Independent verification — review_decisions_final

- [x] Add real PostgreSQL/Redis tests for one-request ownership, no-supply/all-decline zero journal movement, sequential attempts/deadlines, source lineage, eligibility and safety changes, idempotency, recovery and rollback.
- [x] Verify cancellation/acceptance and multiple-worker races, accepted-then-ended behavior, active gap protection, and an actual 100-way reservation race.
- [x] Run seeded fairness evidence including newcomers above 2,000 candidates and high UUIDs; distinguish simulation results from production capacity guarantees.
- [x] Review runtime independently after implementation; report findings for the implementation owner to fix.

### 4. Integration, records and publication — root

- [x] Inspect the diff against FA-024 and the frozen interface. Resolve findings and run appropriate complete backend/mobile/contracts/repository checks plus `node --test` from audio/.
- [x] Record actual evidence and remaining dependencies in a verification document and issue register. Update Play observation to the saved Trader status without copying private contact details.
- [ ] Commit and publish a draft PR stacked on PR79; verify exact-head CI. No live migration, app installation, provider sends, automatic issue closure or production release follows from synthetic verification.

## Isolation and review boundaries

Backend runtime, independent tests and public contract/mobile files have separate owners. Root owns documentation and final integration. Use existing isolated test databases/schemas and Redis14/15 only; never live Redis13. Node24.13.0, Flutter3.27.4 and the existing dependency cache are already available. Do not repeat installations or unchanged baseline tests without a cause.

The routine algorithm defaults implement the bounded-search acceptance criteria and require no further owner choice. Public rollout, pricing/payout/retention policy, real-device/background delivery and capacity claims remain their existing gates. A partial engineering result must not be represented as all 64 issues completed.
