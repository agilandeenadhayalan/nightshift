# Listener decisions and durable outcomes

21 November 2026. This continuation implements the decision and delivery boundaries of FA-014. Customer and Listener remain the only app modes. Staff pages remain separately authorized inside the existing embedded workspace. This document does not approve a human review policy, enroll staff or establish production readiness.

## Behavior and policy boundary

The review service accepts an explicitly supplied, validated policy with an approval reference, version and content digest. The policy defines bounded English/Tamil checklist labels, accepted evidence kinds, outcome reasons and applicant messages. No approved policy, sample policy or staff permission is seeded by migration015. `STAFF_REVIEW_POLICY_FILE` is an optional absolute path to a privately controlled approved JSON policy; it requires configured staff authentication. An absent policy disables decisions and event processing. An invalid configured file fails startup. Checking a file's structure does not establish that its contents have human approval.

Current supported evidence kinds are the application, the consented private voice sample and self-declaration. They do not establish verified age, identity or gender. If the owner-approved assurance policy requires additional evidence, that evidence workflow must be implemented and reviewed before activation. No label or badge may imply checks that were not performed.

Staff must hold read, evidence-read and decision permissions. Each finding starts unset. Every policy check receives an explicit pass, fail or not-checked result; findings cite permitted evidence types and immutable access events for the current material. An approval requires all mandatory checks to pass, rejection requires a recorded failure, and needs-information identifies incomplete or failed checks. Reasons and applicant wording come from the approved policy; private free-form reviewer notes are not collected.

The decision transaction rechecks authority, known self/linked-account conflicts, applicant restrictions, submitted state, current evidence/consent and the exact material fingerprint. The reviewer, session, policy version/digest, material version, findings, reason and server time are recorded immutably with a domain event. Legacy `listener_reviews` fixture records are not promoted to trusted staff decisions. The application points to its current decision so timestamp ties cannot display an earlier review round.

## Retries and effects

The staff request uses a bounded idempotency key. An exact retry returns its existing receipt; a changed body with the same key fails. A receipt can recover an uncertain response after the application leaves the submitted queue. Receipt access still requires current staff authority and conflict checks. Re-reading does not send another decision.

The separate review outbox has one entitlement/notification consumer receipt per event. Each effect and its receipt commit together. Approval updates `users.listener_approved` with source-decision provenance; it does not switch modes, turn availability on, modify wallet balances or create money. Both consumers recheck current applicant deletion/suspension/adulthood. Entitlement processing additionally checks newly known reviewer conflicts; a decision notice may remain available while access is shown as withheld. Event replay cannot reapply a completed entitlement after later revocation.

The current configured policy governs new decisions. A committed decision retains its exact approved historical policy for effect processing; policy rotation does not silently strand earlier pending work. Absence of any configured approved policy pauses effects. Later expiry/revocation of the reviewer's session or permissions does not retroactively reinterpret a valid committed decision. Actual policy withdrawal, reversals and appeals require an explicit authorized workflow.

Notifications are durable owner-only in-app records. No FCM, email or SMS delivery is claimed. The owner result returns only approved localized guidance, missing checks, recorded time and the current entitlement state. Submitted/draft/withdrawn applications do not display an old decision. Notification records are removed on account restrictions/deletion; replay does not recreate completed suppressed effects. Private sample consent may be withdrawn after an approval/rejection without rewriting that outcome or creating an indefinite audio-retention requirement.

## Mobile evidence

The existing Listener application screen shows the localized review update and distinguishes pending entitlement processing, active access and withheld access. It never changes the account's mode, entitlement or online status from a message. The controller discards late results after account/origin changes, hides mismatched application outcomes, clears old guidance after resubmission and reports result-read failure separately from uncertain mutation outcomes.

Local Flutter analysis passed with no findings; all 324 tests passed, including 29 focused application/result tests. New checks cover the actual generated HTTP decoder, account-switch response fencing, stale resubmission guidance, mismatched application reads, failed result reads following a completed withdrawal, and Tamil at 200% text in a 360px viewport. The generated Dart client matches OpenAPI Generator 7.26.0 across 80 files. The unchanged `audio/` reference passed all 3 tests under the pinned Node 24.13.0 runtime.

## Backend evidence

The full isolated PostgreSQL/Redis integration suite passed **289/289 tests**, with zero failures or skips, in 202.29 seconds. This includes 32 new decision tests; the 43 API unit/provider tests, repository guards, 11 tooling tests, TypeScript checks and build also passed. A separate reviewer re-ran the 29 focused Flutter tests successfully and found no blocking issue in the owner-result flow.

The decision tests cover policy-off behavior, unprivileged/self/known-conflict denial, explicit findings and access references, stale material/policy, immutable records, concurrent decisions, idempotent receipts, concurrent effect delivery, transaction rollback followed by a replacement service instance, deletion/suspension/withdrawal races, historical policy rotation, later staff revocation, owner isolation, post-decision sample deletion and policy-file validation. The recovery test injects failure before transaction commit and recreates the service; it is not an operating-system crash experiment. A real PostgreSQL timestamp inference error found by the initial tests was fixed before this passing run.

The timestamp-tie regression fixes the clock and reverses the UUID ordering across two needs-information rounds; the application pointer returns the second round's guidance. A dependency test consumes the genuine synthetic decision through `NightShiftService`: Listener mode/availability remain rejected until entitlement processing, then require explicit owner actions. The policy/version contract also accepts the same valid Unicode code-point lengths across server and client.

## Staff browser evidence

The staff production build/typecheck passed, with **38 unit/contract/transport tests** and **29 Chromium tests** passing. Coverage includes all three synthetic outcomes, policy/permission gating, unset findings, confirmation, duplicate-submit prevention, receipt-first recovery after a lost response, explicit retry of the same unchanged request, stale policy/material, logout/grant changes, private audio cleanup and late callback fencing. A maximum-size multilingual policy verifies the bounded proxy response. Valid bios use Unicode code-point lengths consistently.

The final browser run passed in 31.4 seconds. Tamil checklist/confirmation at 200% text in a 360px viewport was inspected visually; an actual overflow found during testing was fixed. A delayed audio error could overwrite a recorded receipt during review; it is now fenced and covered by a regression. A fresh whole-branch reviewer found no remaining material code blockers. This is synthetic browser evidence, not a live Redmi staff session.

## Remaining acceptance evidence

The owner selected SMS OTP-only staff authentication, the Redmi account, themself as initial reviewer/access administrator and the embedded workspace. Those decisions are already recorded. The authenticated Redmi account/request binding, explicit permission provisioning and actual embedded staff session remain unverified. No grant was made by this continuation.

Human approval of versioned review criteria, adult/identity assurance, accepted evidence, privacy/retention rules, appeals/escalation, a conflict reviewer/backup and applicant notification wording remains required before real decisions. Exact-head CI is recorded in the pull request after publication. No existing open issue is closed merely by a passing synthetic slice.
