# Engineering contracts and repository structure

## Repository layout

| Path | Ownership |
|---|---|
| `apps/mobile/` | Flutter application with customer and listener feature modules |
| `apps/web/` | Reserved Next.js public website and external deletion/support entry |
| `apps/admin/` | Next.js protected staff session UI; intended for the in-app browser |
| `apps/api/` | NestJS controllers, gateway and domain modules |
| `apps/worker/` | Reserved queue consumers, schedulers, outbox delivery and reconciliation entrypoint |
| `packages/contracts/` | Versioned OpenAPI and event JSON schemas; generated clients |
| `packages/backend-domain/` | Pure server-side billing rules; no runtime dependencies or cross-language duplication |
| `packages/config/` | Reserved typed-config boundary; current environment templates contain no secrets |
| `db/migrations/` | Ordered SQL migrations and constraint definitions |
| `infra/` | Local Docker Compose and reviewed cloud IaC |
| `docs/` | Architecture decisions, runbooks, pricing model, policy decisions and release evidence |
| `tests/` | Integration, concurrency, E2E and load scenarios |

Use npm workspaces and Turborepo for the explicit task graph, retaining Flutter's own package manager and lockfile. Only runnable applications and real shared packages are registered: API, mobile task adapter, staff web session shell, browser reference, contracts and backend-domain. Reserved web/worker/config directories are not empty build targets. See [monorepo rules](Monorepo.md) and [ADR-0002](adr/0002-monorepo-task-graph.md).

API code consumes backend-domain and contracts through declared package boundaries. Mobile uses the generated public Dart SDK in `packages/contracts/dart` and declares the contracts dependency in the task graph; do not import TypeScript or server packages into Flutter. Apps do not import other apps. Backend-domain exports pure financial rules with no framework, provider or database dependency; the API owns authorization and durable transactions. Financial calculations execute only on the server. Contracts contain public schemas and no private configuration. Generate the Dart client with `npm run generate:client` and reject drift with `npm run check:client`; generated code is never hand-edited. Local mock provider adapters are explicitly test-only; CI checks they cannot be enabled with production configuration.

## Main durable entities

`users`, `auth_identities`, `devices`, `consents`, `profiles`, `languages`, `user_languages`, `listener_applications`, `listener_reviews`, `listener_profiles`, `blocks`, `favorites`, `call_sessions`, `call_participants`, `active_participant_claims`, `call_events`, `rate_versions`, `wallet_accounts`, `journal_batches`, `journal_lines`, `credit_lots`, `credit_allocations`, `spend_holds`, `purchases`, `provider_events`, `refunds`, `earning_accruals`, `payout_accounts`, `payout_requests`, `payout_events`, `reports`, `support_tickets`, `attachments`, `audit_events`, `outbox_events`, `deletion_requests`.

Separate PII and financial identifiers from public profiles. Retain explicit links between purchase, lot, spend, call, host accrual and refund. Dates are stored in UTC; the user interface renders the user's time zone and includes the zone on downloadable statements. Use stable opaque IDs; telephone numbers are not usernames.

The implemented schema and its dormant sandbox commerce records are documented in [Database_Model.md](Database_Model.md). Those records establish constraints without enabling provider authentication, purchases or payouts; full financial workflows remain later issues.

## API outline

| Endpoint family | Purpose | Critical guard |
|---|---|---|
| `POST /v1/auth/exchange`, `POST /v1/auth/logout` | Verify identity-provider token and manage backend session/device | Issuer/audience/signature/expiry, revocation and device policy |
| `GET/PATCH /v1/me`, `PUT /v1/me/languages` | Profile and preferences | Field allowlist, owner-only writes, moderation |
| `POST /v1/listener-applications`, `GET /v1/me/listener-application` | Private application and status | Signed uploads, restricted review access, consent |
| `PUT /v1/me/availability`, `POST /v1/presence/heartbeat` | Desired availability and liveness | Approved listener, authenticated device and nonce/session |
| `GET /v1/listeners?language=ta&cursor=...` | Eligible paginated directory | Block/age/role filters, privacy and stable cursor |
| `PUT/DELETE /v1/favorites/{listenerId}` | Idempotent favorite choice | Eligibility and visibility |
| `POST /v1/calls` | Start direct attempt with rate quote ID | Idempotency key, fresh eligibility, participant claims and spend hold |
| `POST /v1/matches` | Create cancellable matching request | One active request per account, budget/timeout, consent |
| `POST /v1/calls/{id}/accept|decline|cancel|end` | State transition | Correct participant, expected version, terminal-state handling |
| `POST /v1/calls/{id}/rtc-token` | Obtain/renew scoped media access | Authorized session, participant UID, current spend authorization |
| `GET /v1/calls`, `GET /v1/calls/{id}` | History and item detail | Participant ownership; do not leak other calls |
| `GET /v1/rates`, `GET /v1/coin-packs` | Versioned display catalogue | Channel/storefront constraints, server-owned prices |
| `GET /v1/wallet`, `GET /v1/wallet/transactions` | Balance and journal-derived history | Owner-only, no client-controlled amount |
| `POST /v1/purchases/verify` | Verify a mobile store receipt | Provider verification, SKU/owner binding, unique purchase token |
| `POST /v1/webhooks/{provider}` | Payment/RTC/payout events | Provider signature over correct payload, timestamp/replay validation, dedup |
| `GET /v1/me/earnings`, `POST /v1/payout-requests` | Earnings and payout request | Approved host, verified payout account, available INR, idempotency |
| `POST /v1/reports`, `PUT /v1/blocks/{id}` | Reports and blocking | Immediate pair exclusion; safe evidence handling |
| `POST/GET /v1/support-tickets` | Customer/listener support | Ownership, attachment limits, internal notes excluded |
| `POST /v1/me/deletion-requests` | Deletion workflow | Step-up auth, balances/disputes/retention rules |
| `/v1/admin/...` | Review, finance, safety and operational actions | Owner-selected SMS OTP (D26), explicit permissions, audit and reason codes |

Use structured validation errors, `request_id`, UTC timestamps and stable error codes such as `LISTENER_BUSY`, `QUOTE_EXPIRED`, `INSUFFICIENT_BALANCE`, `CALL_ALREADY_ENDED`. Side-effecting requests carry an idempotency key scoped to actor and operation; conflicting request content with the same key is rejected. HTTP status and app copy must agree.

## WebSocket contract

Authenticate on connection and authorize subscriptions and every sensitive action. Server events include `presence.updated`, `call.invited`, `call.state_changed`, `wallet.updated`, `earnings.updated`, `support.updated`. Include event ID, entity ID, version and timestamp. Do not broadcast phone numbers, raw payment tokens, birth dates, KYC data or private reports. On reconnection, fetch authoritative snapshot plus events after the last acknowledged cursor; Redis pub/sub is not durable event history.

Prefer WebSocket-only Socket.IO for the initial Flutter client; if enabling polling, test load-balancer session affinity and adapters. At multiple replicas, share fan-out and authoritative state, and validate rolling deploy reconnection. Limit channel fan-out to relevant listeners/users. Never stream raw audio through Socket.IO.

## Call reservation transaction

Claim both participants using a stable lock order to avoid deadlocks. A unique active claim on `user_id` applies across customer/listener roles and devices. In the same transaction validate role, block state, current rate and credit availability; create call/claims/hold; append an outbox invitation. If any step fails, none commits. A short lease expiry is recovered by a worker using database compare-and-set, not by an unchecked Redis delete. The accepting request must match both invitation and state version. Reject an acceptance received after cancellation or expiry.

DB state is authoritative after process restarts. The worker scans recoverable sessions and replays outbox records, with uniqueness constraints ensuring retries do not repeat money movements. Provider callbacks may arrive out of order. Append raw validated event metadata, then apply legal transitions without regressing terminal states.

## Financial integrity contract

1. The journal sums to zero separately for INR and service-credit units; no floating-point arithmetic.
2. `available = posted balance − active holds`, with the definition documented for each account kind. Never spend earnings payable as customer coins.
3. Unique keys cover purchase token, provider event, call billing interval, refund and payout request.
4. Lot allocation is deterministic; pricing and host compensation versions cannot change during a call.
5. Cumulative-second charging prevents drift: calculate the cumulative authorized amount, subtract already-posted amount and post only the difference. Apply rounding once under a documented fixed-point rule, not per heartbeat.
6. Provider transaction state, verified receipts and settlement reports reconcile to purchases; purchases reconcile to the journal. Unknown external outcomes remain `pending`, not `failed` or `paid` by assumption.
7. Refunds and chargebacks are reversals referencing original events. Financial records are append-only with restricted write roles.
8. Two reviewers approve manual payouts above a chosen threshold; a solo operator uses provider controls and capped batches, and records that a true two-person control is not yet available. Never claim one person supplies dual approval.
9. Top-up settlement, revenue recognition, tax and host payables are different accounting facts. A qualified accountant decides the legal books; this technical ledger supplies traceable events.

## Secrets and environments

Local Compose: PostgreSQL, Redis and test services; use Firebase test numbers and sandbox billing. Staging and production have separate databases, storage, RTC projects/credentials, payment configurations and app build IDs. Store secrets in a secret manager and short-lived CI credentials. Generate `.env.example` with placeholders only. Do not seed fake listeners in production. Public demos use clearly labelled fictional fixtures and no real money.

## Telemetry and operations

Correlate `request_id`, `call_id`, `purchase_id`, `payout_id` and opaque user ID. Record transitions and provider error codes, not OTPs, tokens, full phone numbers, bank details or private call content. Dashboards cover discovery freshness, request→accept→join conversion, join latency, call drops, media quality, billable minutes, zero-charge failures, unreconciled money, payout age, reports, queue lag and cost.

Proposed launch targets: p95 API latency below 300 ms for common reads excluding external providers; p95 post-accept join below 5 s on supported networks; stale online state cleared within 45 s; crash-free sessions at least 99.5%; no duplicate debit, negative spendable balance or unexplained reconciliation difference. These are acceptance targets, not achieved results. Measure invite acceptance separately from technical join success so real host absence is visible.

Critical runbooks: RTC outage, payment-provider delay, duplicate/out-of-order webhook, database unavailable, Redis loss, stalled session, payout uncertainty, fraud burst, privacy incident and restore from backup. If the wallet database cannot authorize spending, prevent new paid sessions and stop existing media at the last authorized boundary. Grace time is company-funded and bounded. Never silently continue an unmetered paid service.

## November 2026 launch requirements

Use ₹500 per 3,600 paid connected seconds as a proposed listener rate. Freeze the rate when the call starts. Count only verified intervals with both participants connected, exclude ringing, waiting and reconnect gaps, deduplicate events and round to paise once per settlement. Show the basis of pay before a listener goes online. A six-minute paid call earns ₹50. Customer pricing remains a launch decision.

The owner's 20 November 2026 provider decision supersedes the original MSG91 requirement: use Firebase paid Phone Authentication SMS to India (+91). Flutter obtains a native phone-verification proof, then exchanges the Firebase ID token with NestJS after a consented app admission. NestJS verifies signatures, project, timestamps, phone-provider claims and revocation, maps the opaque Firebase UID to the canonical phone/account binding, and enforces local suspension and deletion restrictions. SDK-managed persistence alone never restores app access; a securely stored backend-accepted marker and renewed server exchange are required. Application admissions are not a provider SMS billing cap. Phone/Play Integrity enablement, India-only region policy, Blaze and a saved ₹5,000 monthly alerts-only budget are recorded; private Admin permissions and actual SIM evidence remain separate gates. The approved 1,000 SMS/day maximum does not authorize exceeding the monthly operating budget. FCM handles notifications. The older MSG91 custom-token adapter remains only as a compatible optional provider with its own sender/template prerequisites; see [Firebase setup](Firebase_Development_Setup.md).

Track SMS cost per successful sign-in, paid seconds per online hour, repeat paid calls and contribution after listener pay, channel fees, RTC, OTP and refunds. Record the price, spend cap and decision owner before taking real payments.
