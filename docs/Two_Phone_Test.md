# Android two-phone milestone verification

Status on 20 November 2026: **partially exercised on two real Android phones; the audible-call milestone remains incomplete**. Sign-in, Listener availability, Customer discovery, invitation/acceptance, safe missing-RTC cleanup, decline/cancel/timeout and durable histories were observed; Agora configuration was absent, so no two-way-audio result is claimed. See the [dated device evidence](Device_Debug_2026-11-20.md). Keep this document as the reusable procedure for [#6](https://github.com/agilandeenadhayalan/nightshift/issues/6), [#26](https://github.com/agilandeenadhayalan/nightshift/issues/26) and the first milestone; the broader release matrix remains [#51](https://github.com/agilandeenadhayalan/nightshift/issues/51).

For #8, also complete the [Tamil/English large-text and TalkBack procedure](FA008_Verification.md#required-physical-accessibility-check). Its reading-order and control-reachability checks require a real phone even when widget tests pass.

## Prerequisites

- Two consenting adult testers, two physical Android phones and headphones to avoid acoustic feedback.
- The same NightShift debug APK on both devices. Record its commit, build timestamp and SHA-256; use one application ID and one backend.
- The local NestJS/PostgreSQL stack started using the repository setup instructions, with migrations and fictional test accounts loaded.
- An owner-controlled Agora test project, with app ID and certificate injected only into the backend's local environment. Never paste its certificate, access tokens or credential values into this report, screenshots, GitHub or logs.
- Both devices can reach the development API. A USB `adb reverse` setup reaches a Windows-local API; two networked devices need an explicitly reachable address, WSL forwarding where required and an appropriately restricted local firewall rule. `localhost` on a phone is the phone itself.
- For the later Wi-Fi/mobile test, keep both phones USB attached with `adb reverse` for API control traffic while Agora media uses their separate Wi-Fi/mobile connections. If USB forwarding is unavailable, use a deliberately configured HTTPS staging endpoint reachable from both networks. A private WSL/LAN address does not become reachable from mobile data automatically.
- Use test credits only. Do not enable real purchases, payouts or a public directory. The fictional test sign-in must not be enabled in production.

Follow the Windows Flutter / WSL backend run instructions for exact startup, build defines and local credentials. Do not fabricate a successful connection when Agora configuration is absent; record the actionable setup error instead.

For the first physical-device test, follow `Local_Development.md`: run `adb -s DEVICE_SERIAL reverse tcp:3000 tcp:3000` for each phone and enter `http://127.0.0.1:3000` as its Backend address. A LAN alternative is to build/run from `apps/mobile/` with `flutter run --dart-define=API_BASE_URL=http://WINDOWS_LAN_IP:3000`, replacing the host with the reachable development machine address and configuring forwarding/firewall deliberately. The emulator default `10.0.2.2` is not a physical-phone address. Select fictional account `listener` on B and `customer` on A (`customer2` is available for concurrency checks), enter the development access key manually, and acknowledge the adult test consent. That shared local key is not a production identity system.

This first build is a **foreground call demonstration**. Backgrounding or locking intentionally ends media and marks availability offline; it does not promise background incoming calls or ongoing-call service support. Keep both phones foregrounded for the required path. Full notifications and foreground-service lifecycle behavior remain #29 work.

## Record before the run

The table below is a template for the next complete audio run. Actual device/build metadata from the partial 20 November run is recorded in [Device_Debug_2026-11-20.md](Device_Debug_2026-11-20.md).

| Evidence | Value |
|---|---|
| Tester / date / time zone | Pending; use consenting tester aliases |
| Git commit / APK SHA-256 | Pending |
| Application ID / Flutter / Dart / Agora SDK | Pending |
| Backend commit / PostgreSQL / Redis versions | Pending |
| Device A model / Android / security patch | Pending |
| Device B model / Android / security patch | Pending |
| Network A / network B | Pending; record Wi-Fi/mobile and relevant conditions |
| Microphone / notification permissions | Pending |
| Test Customer alias / test Listener alias | Pending; opaque IDs only |
| Rate version / initial test balance | Pending |

## Required milestone path

1. On device B, sign in as the approved fictional Listener. Switch to Listener mode. Confirm the UI describes test credits/estimated earnings and the basis of pay, then go online. Verify the app remains foregrounded for this first path.
2. On device A, sign in as a different fictional Customer. Select the same speaking/filter language, initially Tamil. Refresh Discover. Verify the Listener is present, available and callable. There must be no staff or admin mobile mode.
3. Open the Listener card and review the test rate and affordable duration. Initiate one call. Record the opaque call ID, request time and ringing state. Confirm ringing has no charge.
4. On B, confirm the invitation identifies the correct safe Customer nickname and expires if unanswered. Accept the call and grant microphone permission. Grant microphone permission on A when requested.
5. Confirm both screens reach the same connected call. A speaks a fresh three-word test phrase; B repeats it. B speaks a different phrase; A repeats it. Record pass/fail for each direction without recording or retaining private conversation audio. A provider join callback alone is not a pass.
6. Toggle mute on each side and verify the other side cannot hear that participant while muted. Restore it. Switch speaker/headset routing and verify actual audible output. Record post-accept join time separately from time spent ringing.
7. End from A. Verify B ends promptly, both channels leave and microphone indicators stop. Confirm the same stable call ID appears in both histories with compatible end reason, connected duration and test charge.
8. Repeat with a new call and end from B. Restart both apps and confirm the completed records remain. Restart the backend and recheck history persistence.

The milestone passes only when all eight steps pass on two real phones. Record both call IDs and any defect references. A completed call that was inaudible fails the milestone regardless of history or billing correctness.

## Failure and recovery cases

| Case | Procedure | Expected result | Result / evidence |
|---|---|---|---|
| Decline | Listener declines an invitation | Both parties recover, claims release, no charge | Passed in [20 November partial run](Device_Debug_2026-11-20.md) |
| Cancel | Customer cancels while ringing | Listener cannot accept a stale invite; no charge | Cancellation/claim release/no charge passed on 20 November; an explicit stale accept attempt remains pending |
| Ring timeout | Do not answer | One stable terminal result, claims release, no charge | Passed in [20 November partial run](Device_Debug_2026-11-20.md) |
| Accept/cancel race | Act on both phones near simultaneously | One server-authorized outcome; no second session | Pending |
| Microphone denial | Deny permission on either phone | Clear recoverable failure; no healthy-time billing without both participants | Pending |
| Missing/invalid RTC config | Use the backend's documented failure test | Actionable failure; no fake connected state or charged successful call | Missing configuration passed on 20 November; invalid credentials remain untested |
| Stale availability | Kill Listener app or disable network while idle | Listener becomes unavailable by configured expiry; no phantom supply | Idle force-stop tested on 20 November: unavailable by first inspection about 65s later, available again after foreground heartbeat. Exact 45s TTL timing and network-disable case remain unmeasured |
| Concurrent callers | A second Customer attempts the same Listener | At most one active reservation; other caller gets a clear busy result | Pending |
| Network gap | During a call disable one network briefly | Reconnecting state; gap excluded; same call resumes within grace | Pending |
| Reconnect timeout | Keep network unavailable past grace | One terminal result; no ghost call or catch-up charge | Pending |
| App process death | Kill either app mid-call | Conservative metering stops and session recovers/expires; no duplicate settlement | Pending |
| Backend restart | Restart API mid-call | Durable session/history; no duplicate claim or debit; any recovery limit documented | Completed-attempt histories persisted after restart on 20 November; active-media restart remains pending |
| Permission settings change | Revoke microphone then resume | No silent capture or permanent broken state; clear recovery | Pending |
| Mode switch during call | Attempt Customer/Listener switch | Disallowed while reserved/active; server remains authoritative | Pending |
| Background / locked screen | Background and lock either device | This build intentionally ends media and goes offline; verify that safe exit. Background incoming/ongoing calls remain unsupported | Pending |
| Audio interruption | Receive cellular call, connect/disconnect headset | Record focus/routing recovery; no hidden continuing charged silence | Pending |
| Different networks | One phone Wi-Fi, one mobile data | Actual two-way audio and correct recovery through provider networking | Pending |
| Tamil / large text / TalkBack | Change UI language and accessibility settings | No clipped critical controls; meaningful label/order and usable End call | Pending |
| Time zone / clock | Change client clock/time zone | Display grouping adapts; server duration and charge do not change | Pending |

## Test-credit tariff checks

The browser-reference tariff is preserved for the Android development fixture: at most 40 cumulative healthy connected seconds costs zero; more than 40 through 60 seconds costs 60 coins; later the charge is the ceiling of cumulative connected seconds. Ringing and reconnect gaps do not advance that duration. The backend owns the amount; client clocks are not payment authority. Production pricing remains an owner decision.

| Healthy connected duration | Expected test coin charge |
|---|---:|
| 0, 1, 39 or 40 seconds | 0 |
| Just over 40 seconds | 60 |
| 59 or 60 seconds | 60 |
| 61 seconds | 61 |

Use automated boundary tests for exact millisecond arithmetic and real devices for audible delivery and gap behavior. Android test listener earnings are a non-payable estimate based on healthy milliseconds, including the free window, with a fictional subsidy counterpart and zero withdrawable balance. Six healthy connected minutes correspond to ₹50. This deliberately differs from the browser's charged-coin-based estimate; see ADR-0001. Do not assume a test credit has an approved cash value.

Provider-side paid-media cutoff is a separate gate: try continuing to publish/subscribe after server termination with a deliberately noncooperating test client and old tokens. A compliant Flutter client leaving the channel, or refusing the next token renewal, does not prove immediate provider enforcement. Keep real-money calls disabled until this test succeeds with the actual provider controls.

## Final result

| Milestone requirement | Result | Evidence |
|---|---|---|
| Listener goes online on Android device B | Passed in partial run | [20 November device evidence](Device_Debug_2026-11-20.md) |
| Customer on device A finds and calls B | Passed in partial run | Real invitation and acceptance persisted |
| Listener accepts; A hears B and B hears A | Incomplete | Acceptance observed; missing Agora setup prevented audible media |
| Either party ends, channel and microphone stop | Pending audible-call test | Safe automatic failure cleanup observed; successful media termination remains untested |
| Both histories show the same completed calls | Passed for failed/declined/cancelled/timed-out attempts | Both apps and API restarted; repeat with audible calls to complete milestone |

Attach redacted screenshots and safe diagnostic IDs if useful. Never attach audio, OTPs, full phone numbers, provider tokens, certificates or real personal data. Record failures honestly and link fixes; leave unexecuted cases pending.
