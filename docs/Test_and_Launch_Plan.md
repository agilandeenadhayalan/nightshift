# Verification and release plan

The supplied tests are planned acceptance work. No application performance or production readiness is claimed by this document.

## First two-phone test

Use two real consenting adult testers on different accounts, with one manually approved listener. Keep balances test-only. Begin with two Android phones; use Wi-Fi on one and a mobile network on the other.

1. Log in, choose Tamil, enable the listener's availability and confirm the customer sees it.
2. Start a call and observe ringing, acceptance and connection separately. Verify no charge while ringing.
3. Speak in both directions, mute/unmute, switch speaker/headset and leave/reopen the app.
4. Disconnect one network briefly, reconnect, and confirm one session with no charge for the gap.
5. End on either side; verify identical session ID, duration, credit usage and listener accrual in both apps and admin.
6. Try a declined invitation, timeout, unavailable listener and exhausted test balance. Verify zero charging for failed connections and enforced media cutoff at budget exhaustion.
7. Block the pair and verify both direct calls and matching prevent reconnection.
8. Repeat with roles/devices swapped and save anonymized evidence, SDK versions and network conditions.

## Required scenario matrix

| Area | Scenarios | Evidence needed |
|---|---|---|
| Identity | Expired/wrong OTP, resend abuse, logout, revoked account, stolen/replayed session, underage DOB | Automated auth/permission checks; real-device sign-in |
| Roles | Unapproved listener, rejected application, customer setting availability, role change during call | API rejects forged requests, not only hidden buttons |
| Presence | Background/foreground, process killed, network removed, heartbeat expiry, two devices | Timed screen recording of test UI and server events without private call content |
| Matching | No eligible hosts, fairness, cancel, stale directory, block pair, sequential declines | Reproducible seeded eligibility tests |
| Concurrency | Two callers claim one listener; one customer starts two calls; accept vs cancel | Real PostgreSQL concurrent integration tests; one active claim invariant |
| Media | Wi-Fi/mobile switch, one-way audio, denied permission, headset, incoming cellular call, OS killing app | Device/network matrix; provider diagnostic IDs |
| Billing | 0/1/59/60/61 seconds, reconnect gap, low balance, rate change mid-call, duplicate timer/job, clock change | Fixed-point expected amounts and journal invariants |
| Provider cutoff | Old token reuse, app ignoring hang-up, expired balance, failed kick | Demonstrate no unauthorized media beyond bounded policy; block paid release if impossible |
| Purchases | Pending/cancelled receipt, duplicate receipt, stolen purchase token, delayed notification, wrong SKU | Store sandbox evidence plus server verification and reconciliation |
| Reconciliation | Missed webhook, callback ordering, refund after spend, external provider timeout | No unexplained money gap; replay doesn't change settled totals |
| Payouts | Failed/unknown/success/reversed payout, duplicate request, bank change, KYC failure | Provider reference, journal entry, available/held amounts reconcile |
| Privacy/safety | Report during call, immediate block, evidence access, deletion, legal retention, capture controls | RBAC tests, device behavior and documented retention result |
| Recovery | API restart mid-call, worker retry, Redis restart, DB interruption, backup restore | Bounded loss, no duplicated money, measured restore duration |
| Performance | 1,000 sockets/100-call synthetic control target; relevant directory fan-out | Load report with hardware and provider quotas; real media sample separately |
| UX | Tamil long strings, large font, screen reader, flaky network, empty states | Signed-off screen checklist |

## CI and manual boundaries

PR checks: formatting, static analysis, type checks, Flutter analysis, meaningful domain tests, real PostgreSQL/Redis integration tests, API contract compatibility, dependency/secret scanning and build verification. Test business invariants rather than mirroring private functions. Migration tests prove upgrade and documented recovery on realistic staging data. Paid store and media tests require sandbox/provider connectivity and cannot be replaced entirely by mocks.

Use Play internal testing for early builds. Where applicable, start the genuine closed-testing period as soon as a usable core is ready and keep testers engaged; a shell that nobody tests is not sufficient evidence. Do not claim a tester count based on mailing-list entries alone.

## Paid launch go/no-go

- FA-001–056 completed or individually reviewed; no deferred item may break a launch invariant.
- No critical security finding, negative spendable balance, duplicate credit/debit/payout, or unauthorized second participant claim.
- Verified payment-route decision, provider underwriting and test payout/refund completed.
- Real listener roster, named support/moderation owner, published hours and emergency disable controls.
- Privacy/community/refund/listener terms and child-safety contact published; account deletion path works.
- Backups and restore tested; rollback runbook uses backward-compatible migrations and preserves journals.
- Closed testing and store review complete where applicable; app access instructions are accurate and no review-only feature hiding.
- launch caps configured: invited users, 20 concurrent calls, top-up/call limits, payout limits and daily spend alerts. These are adjustable launch controls, not universal legal limits.
- First 48 hours monitored during staffed hours; expand only after reviewing connection, billing, support and fraud evidence.

## Rollback and incident response

Disable new matching/purchases independently where needed; allow safe call termination and preserve transaction visibility. Deploy prior compatible code only; do not run destructive database rollback against financial events. Reconcile all in-flight sessions and provider operations before retrying. Tell affected users the confirmed facts and provide a support reference. Restore drills propose RPO ≤15 minutes and RTO ≤2 hours for the launch; use measured results and provider capabilities to set actual commitments.

## November 2026 launch requirements

Use ₹500 per 3,600 paid connected seconds as a proposed listener rate. Freeze the rate when the call starts. Count only verified intervals with both participants connected, exclude ringing, waiting and reconnect gaps, deduplicate events and round to paise once per settlement. Show the basis of pay before a listener goes online. A six-minute paid call earns ₹50. Customer pricing remains a launch decision.

For branded Indian OTP, use MSG91 with the approved entity, sender header, provider chain and message template. Keep credentials on NestJS. After server-side OTP verification, bind the verified number to one user and issue a Firebase custom token. Flutter exchanges it for a Firebase ID token, which NestJS validates on protected requests. FCM handles notifications. Use fictional identities in development. Confirm sender registration and delivery on real Indian SIMs before enabling branded production SMS.

Track SMS cost per successful sign-in, paid seconds per online hour, repeat paid calls and contribution after listener pay, channel fees, RTC, OTP and refunds. Record the price, spend cap and decision owner before taking real payments.
