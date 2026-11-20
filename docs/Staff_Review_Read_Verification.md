# Submitted Listener review access

Recorded 21 November 2026. This implements the protected queue and evidence-reading portion of [#14](../github/issues/FA-014.md), using the separate [staff authority](Embedded_Staff_Verification.md) and existing Listener applications. Customer and Listener remain the only app modes. Review decisions, entitlement events and notifications are not implemented by this slice.

## Read boundary

| Operation | Required permissions | Returned material |
| --- | --- | --- |
| Submitted queue | `listener.review.read` | At most 20 application references, public aliases, requested languages, submission times and sample-availability indicators |
| Private application detail | Review and evidence read | Submitted introduction/topics/languages, an opaque material fingerprint, self-declared adult status and current sample metadata |
| Private sample | Review and evidence read | A complete validated PCM WAV, at most 2 MiB, matching the requested material fingerprint |

Account phone numbers, DOB, provider identifiers, private proposed nicknames and financial fields are absent from these projections. User-written introductions remain review content and can contain information entered by the applicant. Public aliases come from the existing public profile; reading an application never publishes a proposed nickname. Neither a declaration nor a voice sample is presented as verified age, gender or identity.

Only current submitted applications are readable. Drafts, withdrawn records, restricted applicants and the reviewer's known linked applicant account are excluded. Needs-information applications are editable and have no immutable submitted-content snapshot, so their private detail and evidence remain unavailable until resubmission. Separate provider accounts alone do not establish different human people; known additional account links and conflict policy remain owner decisions.

Queue cursors are authenticated, session/filter-bound and expire after five minutes. The keyset preserves PostgreSQL timestamp precision and a database cutoff. After acquiring the complete sorted set of applicant/source-owner locks, the queue checks each candidate's current submission position and revision. Resubmission while a page waits cannot inject a new position into an older page. A short or empty page during concurrent changes is possible; refreshing obtains a new cutoff.

Staff authority is locked before all involved users in sorted order, then application/upload records. Sample storage I/O holds no such database locks. After reading, provider identity is rechecked and the final transaction rechecks local authority, source lineage, applicant restrictions, current state/consent/pointer/fingerprint and actual file size/hash/WAV structure. Four reads can retain bytes concurrently, including provider revalidation; a timed-out underlying read retains its slot until that work settles. Provider state and a local database transaction cannot form one globally atomic operation.

## Embedded web behavior

The review view stays within the existing fixed-origin staff page; no Flutter/native interface or APK change is required. The server proxy forwards only the staff cookie to fixed read routes, rejects redirects and unexpected responses, bounds audio bytes/deadlines and sets private no-store headers. It forwards neither bearer credentials nor Range/conditional-cache headers. Complete sample responses avoid cached or partial fragments bypassing a fresh authorization check.

Audio uses an explicit same-origin player with no preload or automatic playback. The page clears playback and private detail when it learns of access loss, and on logout, expiry, backgrounding or leaving the review view. Stale request/player callbacks cannot restore or dismiss a newer view. These controls do not revoke bytes already delivered to an authorized device or establish a recording-prevention guarantee.

Migration `014_staff_review_reads.sql` adds only the queue index and immutable, object-targeted access audit. Audit contains references, operation, timestamp and a material fingerprint, without copied sample/content. It creates no decisions, approval flags, money, notification records or live staff grants. Production retention policy remains unresolved.

## Verification

- New backend suite: 24/24 passed against isolated PostgreSQL schemas, signed synthetic provider fixtures and synthetic private WAV files. It covers actual HTTP/contract responses, microsecond pagination, same-content resubmission, forged/customer authority, self-access, permission separation, immutable audit and unchanged business state. Storage races cover withdrawal, deletion, source logout, local grant revocation and provider changes; bounded capacity extends through provider revalidation. Range/conditional requests still receive a fresh complete response.
- Full backend integration: 257/257 passed with no failures, skips or cancellations, including the new 24 tests and actual 45-second Redis expiry. The runner used dedicated test databases/random schemas and Redis14; it did not use the live phone database or Redis13. Tests took 212.680 seconds; all four npm/Turbo tasks passed. Earlier staff/native/schema regression passed 47/47, and API units passed 43/43. TypeScript and generated staff-contract drift checks passed.
- Admin: production build/typecheck, 31 unit/contract/transport tests and 19 actual Chromium tests passed. Browser cases cover error/empty/cursor states, empty continuation pages, explicit playback, access/permission changes, logout/expiry/backgrounding, stale callbacks, enforced CSP and 360px/200% text with Tamil. Visual review corrected a partially visible skip link and excessive detail inset. This is browser evidence, not physical TalkBack evidence.
- Repository secret/contract/boundary checks and 11 tooling tests passed. Required `node --test` from `audio/` passed 3/3.

Ignored evidence includes `staff-review-integration-final.log`, `staff-review-reads-focused.log`, `staff-review-authority-regression.log`, `staff-review-api-unit.log`, `listener-review-admin-build.log`, `listener-review-admin-browser.log`, `staff-review-repo.log` and synthetic queue/detail screenshots. No live phone/provider data was used for these tests, and no SMS was sent.

## Remaining acceptance

The authenticated Redmi enrollment reference, explicit initial provisioning and actual embedded session/playback checks remain separate device evidence. The phones currently run the verified staff-shell build described in the preceding verification record; these review reads have not been claimed installed by local test success.

Before real review decisions, the owner must approve the versioned required checklist and accepted evidence, conflict/escalation owner, consent/retention rules, needs-information/rejection/appeal policy and notification copy/channel. Decision records, stale/concurrent decision handling, durable entitlement and notification effects, duplicate-event recovery and approved human findings still need implementation and evidence. This slice does not complete or close #14.
