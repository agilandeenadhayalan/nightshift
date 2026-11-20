# Database foundation — FA-007 / #7

The schema supports the existing Android test-credit call slice and provides durable foundations for later identity, review and commerce adapters. Migration `003_identity_commerce_foundation.sql` is additive. It does not turn on production authentication, listener onboarding, purchases, refunds or payouts. The new commerce tables accept **sandbox/test-only** records, and the existing ledger still accepts only `TEST_MICROCREDIT` and `TEST_PAISE` units.

## Ownership and existing core

| Entities | Ownership and invariants |
|---|---|
| `users`, `auth_sessions` | One user may use Customer or Listener mode. Session tokens are hashed; expiry/revocation are server-side. The current accounts are fictional fixtures, not production identity verification. |
| `listener_reviews` | Existing fixture approvals retain their original reviewer/reason and a null application link. New linked reviews use a composite foreign key so the review user must be the applicant. No schema trigger grants the user's Listener entitlement. |
| `rate_versions`, `call_sessions` | Each call freezes its test-rate snapshot, both participant IDs, version, interval totals and final fixed-point amounts. Customer and Listener must differ. Ended state and `ended_at` must agree. Runtime changes use the existing participant authorization and transaction/version checks. |
| `active_participant_claims`, `call_participants` | A user can have only one active claim across modes. Participant IDs and RTC UIDs are unique within a call. The API reserves both participants in one transaction and uses a stable user-lock order. |
| `call_events`, `outbox_events` | A call/version pair has one durable event. A monotonic sequence orders reconnect cursors. An event/recipient pair has one outbox entry; API/socket delivery remains participant-authorized. Delivery retries are not proof of provider-side media delivery. |
| `wallet_accounts`, `journal_batches`, `journal_lines`, `spend_holds` | Integer test units are kept separate. Journal batches/lines reject update/delete; deferred checks require zero-sum lines separately per unit. One call has one spend hold, and settlement keys prevent repeat posting. |
| `blocks`, `favorites`, `reports` | Blocks/favorites have unique actor/target pairs and disallow self-pairs. Reports reference an actor and call; participant eligibility is enforced by the API. Staff triage, retention and moderated profile operations are later work. |

The existing API call lifecycle is `ringing → connecting → connected ↔ reconnecting → ended`, with cancellation, decline, timeout and failed connection able to end earlier. Ended calls never rejoin through client operations. Call authorization, transition logic, metering and journal settlement stay in the API/domain modules; SQL row constraints complement them. See [Engineering_Contracts.md](Engineering_Contracts.md) and the API integration tests for reservation, journal and reconnect details.

## New private identity and review records

`auth_identities` binds an opaque provider/issuer/subject digest to exactly one `user_id`. Binding ownership and provider identifiers cannot be changed after insertion. The verified and revoked timestamps become immutable once recorded. A revoked row cannot be restored to verified; future identity recovery must use an explicit reviewed workflow. This table has no raw phone number, OTP, Firebase ID token, provider secret or credential payload column. Production verification, abuse prevention and session exchange remain #9/#10.

`listener_applications` supplies durable application IDs and states. A user can have at most one draft/submitted/needs-information application. The first submission and decision timestamps cannot be overwritten. Reapplying after a terminal record uses a new application, subject to future eligibility rules. Existing `listener_reviews.application_id` is nullable for backward compatibility, but any non-null reference must belong to the same user. Private evidence storage, staff authorization, approval auditing and entitlement changes remain #13/#14; writing a state directly is not an authorized review workflow.

| Record | Allowed state changes |
|---|---|
| Identity | `pending → verified / revoked`; `verified → revoked` |
| Listener application | `draft → submitted / withdrawn`; `submitted → needs_information / approved / rejected / withdrawn`; `needs_information → submitted / withdrawn` |

New records must begin in the listed initial state. Terminal states have no outgoing transitions. Repeating the same state is allowed, while immutable ownership and recorded timestamps remain protected.

## Dormant commerce foundation

| Entities | Keys, amounts and ownership |
|---|---|
| `provider_events` | Unique `(provider, environment, event_digest)`; separate payload digest; occurred/received UTC timestamps. Records are append-only. The only accepted environment is `sandbox`. No arbitrary webhook payload is stored. Signature verification and receipt authenticity must be implemented before any adapter trusts these rows. |
| `purchases` | Unique `(provider, environment, purchase_token_digest)` prevents a receipt reference from belonging to two users. User, provider, SKU, amount and credit snapshot are immutable. Positive integer paise and microcredits are separate fields, with explicit INR currency and `test_only=true`. No live price catalogue is implied. |
| `refunds` | A composite foreign key binds purchase, owner, provider and environment. A purchase/request-key pair is unique. Positive amounts are immutable. A parent-row write serializes competing refund reservations and aborts stale higher-isolation snapshots; requested, processing, unknown and succeeded amounts together cannot exceed the purchase amount. Failed/cancelled requests release that reservation. Unverified purchases cannot reserve refunds. |
| `payout_accounts` | Unique provider/environment/account digest and immutable owner binding. Provider-held account references are represented only by digests; no bank account, tax identifier, document or access token is stored. Verification time is preserved. |
| `payout_requests` | A composite foreign key requires the destination account's owner/provider/environment to match. `(user_id, request_key)` is unique; the request fingerprint and amount/fee snapshot cannot change. Positive gross paise, nonnegative fee and generated positive net paise prevent inconsistent totals. A verified account is required for creation and new authorization/dispatch. |
| `payout_events` | Each provider event can be linked once, and its provider/environment and `payout` kind must match. The payout request/provider pair is checked independently. Event records are append-only; inserting one does not automatically change payout status or post journal entries. |

| Record | Allowed state changes |
|---|---|
| Purchase | `pending → verified / rejected / cancelled`; `verified → fulfilled / revoked`; `fulfilled → revoked` |
| Refund | `requested → processing / cancelled`; `processing → unknown / succeeded / failed`; `unknown → succeeded / failed` |
| Payout account | `pending → verified / rejected / disabled`; `verified → disabled` |
| Payout request | `requested → approved / cancelled`; `approved → processing / cancelled`; `processing → unknown / paid / failed`; `unknown → paid / failed`; `paid → reversed` |

Purchase/refund/payout request deletion is rejected so retries cannot erase their ownership/idempotency history. Provider and payout events also reject updates. This is technical record integrity, not a finalized legal retention policy. Provider-reported outcomes must be authenticated and reconciled by later service workflows. In particular, a timed-out transfer remains unknown rather than being retried as a new payment or assumed failed. Disabling an account blocks new authorization but still permits a previously sent request's late outcome/reversal to be recorded.

Refund reservation updates touch the parent purchase's `updated_at` inside the same transaction before reading the reserved sum. At READ COMMITTED this provides a fresh serialized aggregate; at REPEATABLE READ/SERIALIZABLE a conflicting stale snapshot receives SQLSTATE `40001`. The caller must retry the complete transaction with the same operation key and a fresh snapshot, then respect any amount-cap rejection. A plain parent `SELECT FOR UPDATE` would not refresh a REPEATABLE READ child-table snapshot and is deliberately not used for this cap.

The current test journal is intentionally not linked to these dormant purchase/payout states. Fulfilment, available-payable reservations, receipt-to-journal linkage, credit lots, approvals, reversals and provider settlement reconciliation must be implemented and tested before any monetary workflow is exposed (#34–#44). A status row is never sufficient evidence of a credit grant, bank transfer or provider verification. No commerce route has been added to the Android API by this migration.

## Time, numeric representation and private references

- All persisted instants use PostgreSQL `timestamptz`. API boundaries serialize UTC instants; presentation chooses a user time zone. Do not store ambiguous local wall-clock strings.
- Financial amounts use `bigint` fixed-point units; paise, microcredits and milliseconds are different quantities. The `pg` driver returns `bigint` as strings. Future adapters must use integer/BigInt validation and checked conversion, never floating-point money calculations.
- UUIDs are opaque record IDs. Provider subject, receipt, event and account digests are lowercase 64-character values. Production adapters must use a canonical, scoped keyed digest for low-entropy identifiers; keys and any necessary encrypted provider references belong in restricted server storage outside public profiles and source control. This migration does not implement that adapter or a key lifecycle.
- Foreign keys bind ownership across rows. Check constraints enforce row-local validity; transition triggers preserve lifecycle and immutable fields. The refund cap uses a lock and aggregate rather than a cross-table `CHECK`, following [PostgreSQL constraint guidance](https://www.postgresql.org/docs/17/ddl-constraints.html).

## Migration and verification

Do not modify migrations 001/002 or any already-applied migration. The runner holds a database advisory transaction lock, verifies stored SHA256 checksums and applies missing files in order within a transaction. Migration 003 adds tables, functions/indexes and a nullable review link; it neither reseeds nor rewrites existing users, calls, journal amounts or reviews.

Run the root `npm run test:integration` with a dedicated `TEST_DATABASE_URL`. `apps/api/test/schema.test.ts` creates random isolated schemas and removes only those schemas afterward. Its ten tests cover a repeatable empty migration, an upgrade from 001/002 with representative seeded accounts/reviews/journal and completed-call/outbox history, unchanged prior checksums, identity/applicant ownership, state transitions, receipt/event/request deduplication, zero/negative/fractional amounts, immutable amounts/evidence, concurrent refund over-reservation at READ COMMITTED and REPEATABLE READ, and payout reconciliation after account disablement. The existing API integration suite must continue to pass.

Local verification on 20 November 2026: all ten schema tests passed against PostgreSQL 17.7. The REPEATABLE READ regression first reproduced over-reservation with a lock-only implementation, then passed after the parent-row write was added. These are synthetic sandbox records. No provider request, real payment/payout or physical-device verification was performed.

Owner-controlled provider setup, budget/caps, finance/safety appointments, retention, permanent application ID and release approvals remain in the existing [decision register](Decision_Register.md). This document introduces no approved production tariff, payout threshold or identity-review policy.

## Presence authority extension

Migration `010_presence_versions.sql` adds a nonnegative `bigint` presence version to each user. Availability/mode changes, device replacement, logout, underage restriction and deletion advance this durable version. Redis stores only a 45-second lease for a version; directory and call eligibility also require matching database intent, adult/Listener eligibility and a current authorized session. Same-device identity-token refresh preserves the version so it does not interrupt reachability.

Redis writes occur after database commit. Conditional lease publication and cleanup prevent delayed requests from replacing or deleting a newer intent; a stale write after Redis loses its key still fails the database-version check. The version is internal authorization metadata and is not added to the public profile or app modes. This additive migration does not approve new Listeners or enable production authentication. Physical network/process interruption evidence remains separate from database/cache race tests.

## Short-lived directory views

Migration `011_discovery_views.sql` stores owner/filter-bound view IDs, fixed member ranks, opaque cursor IDs and which members have actually been served. It copies no profile, phone, sample or financial fields. A view expires after five minutes; creating views keeps at most four per owner. Pages contain at most 20 currently eligible cards, while membership and ordering remain fixed until refresh. Every response rechecks approval, adult status, suspension, mode, language, pair blocks and current reachability.

The development implementation takes at most 2,000 UUID-ordered candidates before ranking them by available, busy and offline. An explicit `truncated` response identifies larger supply; neither an empty truncated page nor refresh proves there are no other matching listeners. This is a bounded engineering policy, not complete ordering over unlimited supply or a measured production capacity claim. Socket subscriptions contain at most 40 actually served members and are scoped to the owner and language.

Expiry cleanup is bounded. Suspending an account removes its owned views and references to it as a directory member in the same transaction. Pair blocks delete corresponding favorites, and favorite writes use the same sorted participant locks as block/call authorization. Directory membership never grants contact permission: call creation independently revalidates the pair.

## Separate staff authority

Migration `012_staff_authority.sql` adds staff principals, explicit permission grants, revocable sessions, bounded login challenges and append-only audit events. Provider subject identifiers remain private; keyed subject bindings, cookie hashes and unique proof hashes support identity lookup and replay protection. An optional immutable `linked_user_id` prepares known self-review checks. Staff records are separate from customer users, device sessions and modes.

Grant changes and principal disable/revocation advance a monotonic authority version and invalidate existing staff sessions. Grant history is retained, and audit records cannot be updated or deleted. Sensitive actions must take the staff principal lock and revalidate session/permission authority before applicant/application locks. No principal or grant is seeded and the normal API bootstrap remains unavailable. This migration supplies no review checklist, approval decision, entitlement or notification effect; see [staff verification](Staff_Access_Verification.md).
