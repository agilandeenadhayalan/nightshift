# Listener review decisions and durable outcomes

Goal: complete the locally verifiable decision-to-entitlement part of FA-014 and connect its owner-visible result to the existing Listener application flow.

Architecture: a versioned, explicitly approved policy supplies review checks and safe localized outcome text. A separate staff decision service commits immutable decisions and domain events under the existing authority/owner lock order. Replay-safe consumers update the Listener entitlement projection and durable owner notification. Existing Customer and Listener modes and legacy fixture reviews stay separate from staff authority.

Tech stack: TypeScript, PostgreSQL, Nest/Express, Next.js/React, Flutter/Dart; Node 24.13.

Spec: `github/issues/FA-014.md`, `docs/Staff_Review_Plan.md`, `docs/Engineering_Contracts.md`; D17 and D26 record the owner's Firebase and staff SMS-only decisions.

## Global Constraints

- No live decisions, staff grants, SMS, provider changes or database migrations during implementation. Use isolated test databases/schemas; never test with the live device Redis database.
- No bundled production review policy or fixture bypass. Missing policy leaves decisions unavailable. Synthetic policies belong to test harnesses only. Voice and self-declared age are not identity/age verification.
- Principal, sorted source/applicant owners, application/evidence is the lock order. Recheck current grants, source identity, restrictions, known self/linked conflicts and evidence revision at commit.
- Immutable decision/event identities and uniqueness constraints prevent duplicate effects. Approval alone never turns availability on, changes mode or grants money.
- Policy supplies minimal bounded check/evidence/reason identifiers and owner-visible English/Tamil text. Do not retain free-form private reviewer notes unnecessarily.
- Preserve private audio withdrawal after terminal outcomes. Account deletion removes owner notification content; no invented retention policy.
- Never mark external/device/policy acceptance complete from synthetic tests. Correct already-superseded specs without requesting the same owner choice again.

## Review Focus

Authorization and deletion/revocation races; precise material version; retry after lost response; two reviewers deciding concurrently; transactional worker replay/restart; stale browser results after logout; source decisions distinct from legacy fixture rows; policy disabled in the normal runtime; Unicode and Tamil/large text.

## Tasks

### Task 1 — Correct superseded specifications

- [x] Amend `github/issues/FA-009.md`, corresponding `github/issues.json` entry and current master/UI/launch documents to match Firebase phone proof and staff SMS-only decisions.
- [x] Preserve unproven sender presentation, manual/automatic verification and live staff acceptance evidence.
- [x] Validate JSON and inspect all current provider/MFA references. No remote issue changes until reviewed.

### Task 2 — Immutable decisions and durable effects

- [x] Add migration015 for immutable approved policy/decision records, known staff conflicts, domain outbox, consumer receipts, entitlement provenance and owner notices.
- [x] Add bounded policy/service DTOs, expected material/policy checks, reasoned approve/needs-information/reject, idempotency and receipt recovery. Reuse exact review material fingerprint.
- [x] Add atomic replay-safe effect processing and owner-only result read; wire normal runtime with decisions disabled when no approved policy is present.
- [x] Add focused failing tests first, then verify permissions/self-review, stale material/policy, concurrent/repeated decisions, consent/deletion/suspension races, policy-off, lost response/restart, one effective grant/notice, needs-information resubmission and deletion cleanup.
- [x] Run TypeScript build and focused isolated PostgreSQL tests. Expected: all tests pass with no skipped integration checks.

### Task 3 — Staff decision UI and contract

- [x] Coordinate fixed typed routes and DTOs with Task2 before implementing `apps/admin` and `packages/contracts/build-staff-contract.mjs` changes.
- [x] Render policy/checklist, explicit findings/outcome/reason and confirmation; all findings start unset. Disable actions when unavailable/unauthorized.
- [x] Freeze uncertain request payload/key, recover its receipt before explicit retry, clear stale material/policy findings and generation-fence late responses after logout/view exit.
- [x] Correct Unicode code-point length validation for valid application bios.
- [x] Verify unavailable and all three synthetic outcomes, input validation, double submit/lost response, permission/logout changes, Unicode and Tamil at200% text in360px viewport. Expected: unit/contract/browser tests and production build pass.

### Task 4 — Owner-visible application result

- [x] Extend the existing private Listener application controller/screen with the owner-only result, approved localized reason/missing information and pending-versus-active entitlement state.
- [x] Keep switching modes dependent on authoritative user entitlement; never auto-switch or change availability from a notification.
- [x] Verify cross-account/background stale-response cleanup, needs-information resubmit and Tamil/large text; rebuild generated public client only if its public contract changes.

### Task 5 — Integrate, independently review and publish reviewable work

- [x] Inspect whole diff against acceptance criteria and dependency order; fix material findings and rerun their regressions.
- [x] Run required repository guards, full backend suite, staff/browser suite, Flutter checks when changed, and `node --test` from `audio/`.
- [x] Update verification/status records with actual evidence and unresolved owner/provider gates; prepare the next dependency work.
- [x] Commit and open draft PR79 against `codex/listener-review-reads`; exact-head `00c97105f97e0f512bae4ce95bde702afeff8621` passed backend, Android and staff in run44856588700. No merge, production activation or issue closure from partial evidence.

## Preflight conclusions

Task1 shares only documentation with Task5; Task2 publishes the routes/DTOs consumed by Tasks3/4; Task3 owns the staff contract builder and Task4 owns any customer contract changes. Do not run concurrent edits of the same builder. Task2 must report the approved interface before consumers start. Task5 integrates all outputs. Each task's verification matches its claimed scope; approval, deployment, external push and owner policy remain outside synthetic evidence.

Ruling: reuse the existing isolated worktree on a new branch and its verified f220aa5 baseline; do not reinstall dependencies or repeat unchanged baseline suites. Continue already-active agents on their current feature context and parallelize only disjoint files, as instructed by the session's multi-agent policy. Root performs integration and independent review before publication.
