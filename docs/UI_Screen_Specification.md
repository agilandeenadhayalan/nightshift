# UI requirements — original design to follow

The next design pass can use your redacted screenshots to understand interactions. Create our own layout, icons, copy and brand. Do not copy competitor assets or imply affiliation. This is a functional specification, not a completed visual design.

## Navigation and visual direction

Customer bottom navigation: **Discover · Recents · Profile**. Favorites is a sub-tab within Recents. Wallet balance is visible from Discover and Profile. “Find a listener” is an explicit Discover action; do not add a fourth navigation item for an unfinished feature. Listener mode uses **Availability · Earnings · Profile**. Switching modes requires server-approved role entitlement and is disabled during an active or reserved call.

Use warm neutral backgrounds, one distinctive accent, readable text, large tap targets and a restrained avatar catalogue. Availability needs both text and icon; color alone is insufficient. Tamil and English strings must fit at larger accessibility text sizes. Money, rate and remaining time are visually clearer than a collection of animated rewards. Avoid countdown pressure, fake users, hidden rates or preselected repeat purchases.

## Customer screens

| ID | Screen | Required content and behavior | States and issue mapping |
|---|---|---|---|
| U01 | Welcome and age/terms gate | Explain paid adult conversation, supported languages and basic privacy; neutral date-of-birth gate; policy links | Underage blocked; consent declined; offline. FA-001,009,011 |
| U02 | Phone and OTP | Country/number input, SMS purpose, request/verify, resend cooldown, support | Incorrect/expired code, quota, retry, number change; no OTP logs. FA-009 |
| U03 | Profile setup | Nickname or generated safe nickname, avatar, optional gender preference where appropriate, interests | Validation, nickname moderation, no public phone/DOB. FA-011 |
| U04 | Language | Separate app language from speaking/filter languages; Tamil/English initially | Empty selection; saved state; language fallback. FA-012 |
| U05 | Discover | Header/avatar, credit balance, language filter, real listener cards, availability text and price/minute | Loading, empty, busy, offline, stale, pagination and reconnect. FA-017–019 |
| U06 | Listener detail / pre-call sheet | Verified-check description, languages, topics, rate, affordable time, report/block, audio CTA | Unavailable, insufficient funds, listener became busy. FA-021–022,033 |
| U07 | Find a listener | Explicit consent to matching; selected language and type; matching state, cancel | No matches, timeout, attempt progress, no charge while searching. FA-024 |
| U08 | Outgoing invitation | Listener name/avatar, ringing, cancel; clearly uncharged | Decline, timeout, app resume, cancellation vs acceptance race. FA-023,027 |
| U09 | Active audio | Avatar, mute, speaker/headset, elapsed billable time, rate, credits/time left, end, report/block | Connecting, connected, reconnecting, low balance, ended. FA-026–030,037,045 |
| U10 | Call result | Duration, charged credits, end reason, favorite/review/support | Zero charge for failed connection; discrepancy help. FA-031–032,038 |
| U11 | Wallet / packs | Purchased vs promotional balance, pack amount, coins, indicative call minutes, total price, receipt history | Loading, unavailable SKU, policy-channel availability. FA-033–036 |
| U12 | Payment status | Pending, confirmed, cancelled, failed, support/reference | No false success; background return; delayed receipt. FA-035–036,040 |
| U13 | Transactions and receipts | Recharge, session debit, reversal; date, reference, secure document link if applicable | Cursor pages; restricted access; provider-issued vs company-issued document distinction. FA-039 |
| U14 | Recents and favorites | Today/yesterday/older groupings, last call, current availability, favorites sub-tab | Deleted/blocked listener anonymization; no stale green dots. FA-020,031 |
| U15 | Profile/settings | Edit allowed profile fields, languages, listener application, privacy, help, logout | Re-authentication for sensitive changes; suspension reason. FA-010–016 |
| U16 | Help center | Search/categories: calls, payments, listener, safety, account | FAQ answer feedback optional; useful diagnostic IDs, no secrets. FA-047 |
| U17 | Support ticket | Category, description, optional up-to-three images, consent to contact, ticket state | File validation, pending submission, duplicates, reopen. FA-047 |
| U18 | Report/block | Reason, optional written context/evidence, immediate safety controls | Block effective immediately; acknowledgement; appeal path. FA-045 |
| U19 | Account deletion | Plain-language effect on profile, credits, earnings and required retained records; authentication | Pending/eligible cancellation, legal hold, completed; external request page. FA-016,048 |
| U20 | Restriction notice | Reason category, duration if temporary, support and appeal | No undisclosed permanent loss of earnings. FA-046 |

## Listener screens

| ID | Screen | Required content and behavior | States and issue mapping |
|---|---|---|---|
| L01 | Become a listener | Requirements, free application, expected process and non-guaranteed earnings | Eligible/ineligible; no payment to apply. FA-013 |
| L02 | Application | Bio, languages/topics, adult verification process, consented voice sample, required review upload | Save draft, private upload, validation, retry. FA-013 |
| L03 | Review status | Submitted, needs information, approved, rejected; reason and support | No promise of approval within an unstaffed deadline. FA-014 |
| L04 | Availability dashboard | Audio on/off, connection health, language, shift guidance | Reconnecting/offline; server-approved role; busy lock. FA-015,017 |
| L05 | Incoming call | Caller safe nickname, session type, earnings rate, accept/decline, expiry | Notification foreground/background, expired invitation, one active session. FA-023,029 |
| L06 | Listener call | Audio controls, connected time, estimated earnings, end/report | Earnings estimate marked provisional; reconnection no pay accrual. FA-026,028,041 |
| L07 | Earnings | Pending, available, held, paid; per-session details and rate version | Hold reason, correction/reversal; clear statement. FA-041 |
| L08 | Payout account | KYC/provider flow and bank verification with masked details | Pending/rejected/verified; change cooldown and step-up auth. FA-042 |
| L09 | Request payout | Minimum, fee/deductions, net amount, expected processing range and confirmation | Requested, review, processing, paid, failed, reversed. FA-043 |
| L10 | Listener support | Safety rules, earnings disputes, payout reference and contact | Priority for active safety event; ticket status. FA-045,047 |

## Admin and website

Admin pages: MFA sign-in; review queue and application detail; users/roles/suspensions/appeals; active and completed calls; payment reconciliation; wallet journal; payout review; reports and evidence; support queue; rate/feature settings; operational dashboard; audit log. Approving payouts and changing prices are separate permissions. No ordinary support agent can edit a balance or view full identity documents. Production support actions are reason-coded and audited. See FA-014,040,042–048,049.

Public website pages: home and Android download; how it works and clear pricing explanation; become a listener; support/contact; privacy; terms; community rules; child-safety standards; refund policy; listener terms; account deletion request. Do not display fictional download links, unearned trust badges, false user counts, fake reviews or unavailable 24/7 support. Business/policy copy must be finalized before public release.

## Expansion screens

Video preflight, camera preview and explicit consent; video call and reconnect/quality downgrade; report controls; consent-based text thread; clear offer terms; iOS permission/purchase flows. An AI companion, if later approved, must be visibly marked AI at entry and within the conversation. It must not masquerade as an available human listener.

## Screenshot handoff checklist

Useful references: onboarding, directory availability states, rate sheet, incoming/outgoing call, active call, low balance, top-up/offer details, transaction receipt, earnings/payout, support and deletion. Redact phone numbers, user IDs, account/bank details, OTPs and other people's private content. Annotate which interaction you like; pixel-perfect copying is unnecessary. Capture one loading/empty/failure case as well as the normal screen.

## November 2026 launch requirements

Use ₹500 per 3,600 paid connected seconds as a proposed listener rate. Freeze the rate when the call starts. Count only verified intervals with both participants connected, exclude ringing, waiting and reconnect gaps, deduplicate events and round to paise once per settlement. Show the basis of pay before a listener goes online. A six-minute paid call earns ₹50. Customer pricing remains a launch decision.

For branded Indian OTP, use MSG91 with the approved entity, sender header, provider chain and message template. Keep credentials on NestJS. After server-side OTP verification, bind the verified number to one user and issue a Firebase custom token. Flutter exchanges it for a Firebase ID token, which NestJS validates on protected requests. FCM handles notifications. Use fictional identities in development. Confirm sender registration and delivery on real Indian SIMs before enabling branded production SMS.

Track SMS cost per successful sign-in, paid seconds per online hour, repeat paid calls and contribution after listener pay, channel fees, RTC, OTP and refunds. Record the price, spend cap and decision owner before taking real payments.
