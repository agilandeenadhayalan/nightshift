# FA-008: Flutter state, navigation and accessibility evidence

Related issue: [#8](https://github.com/agilandeenadhayalan/nightshift/issues/8). This continuation builds on the monorepo work in #67 and schema/generated-client work in #68. The app still has one Android application ID, `com.nightshift.app`, and exactly Customer and Listener modes. Staff tooling stays separate.

## Scope

History must distinguish a pending request, a failed request and a successful empty response. A retry must repeat the failed history operation, including a page cursor when loading earlier calls. Existing rows must remain readable when a refresh or later page fails. Snapshot polling must not erase a history failure or masquerade as a successful history retry. Logging out must clear history state and prevent late responses from repopulating the previous account's records.

Restoration must return to Discover/Availability, Recents/Earnings or Profile as saved, while an active server call takes priority. Unknown saved destinations fall back to Home. Switching modes returns to and persists Home. Riverpod owns the controller and injectable API/audio/session boundaries; GoRouter owns navigation. Generated API code remains in the contracts package.

Loading and recoverable failure components provide Tamil/English copy and semantic labels. Unknown API error messages and call end reasons must not be displayed as raw server text. A repeated Call control must identify its listener to assistive technology. The UI continues to use actual server data or clearly identified development fixtures, with no invented production activity.

## Automated verification

Verified on 20 November 2026 with Flutter 3.27.4 / Dart 3.6.2, Node 24.13.0 and npm 11.6.2:

| Check | Result |
|---|---|
| Full Flutter suite | **69 tests passed**, including the existing 36 and 33 new state/widget regressions |
| Flutter analysis | No issues found |
| History/controller regressions | 16 new tests cover immediate loading notification, initial failure, cursor-specific retry, preserved rows after malformed refresh, late responses and authorization failures, restored path/language values, mode-switch polling, error ownership and delayed credential cleanup |
| UI regressions | 17 new tests cover pending/failed history, cursor retry, restored Recents/Profile before and after initialization, invalid routes, mode switching, unloaded discovery, recipient labels, Android tap-target/labeled-target guidelines, busy sign-in, Tamil copy and 360px layouts at 2x text in both modes |
| Browser reference, domain and API units | 3 + 5 + 2 tests passed through the root `npm test` command; no audio source was changed |
| Repository checks | Secret/file guard, OpenAPI schema comparison, package boundaries and 10 tooling tests passed in the isolated review worktree |
| Clean npm install | Passed; audit reported 0 vulnerabilities |

The narrow-screen test reproduced an AppBar overflow for Tamil at 2x text. Moving the mode label into the wrapping development banner fixed it. Delayed-response tests reproduced restoration and session-lifecycle edge cases: an old directory poll can no longer undo a successful mode switch, and a new sign-in waits for prior credential cleanup before writing its token. Snapshot recovery clears only snapshot-owned errors; independent history and command failures remain visible.

This change has no database migration, contract regeneration, provider dependency or production configuration change. The previous #7 generated-client and PostgreSQL evidence remains in [FA007_Verification.md](FA007_Verification.md). The PR's CI run rechecks the full backend/database/economics and Android suites against the committed tree.

Automated semantics and layout checks cannot establish how a particular phone's TalkBack voice reads Tamil or navigates the native accessibility tree. No Android devices were attached during this run.

The ARM64 debug build command is `npm run build:android`; its local output is `apps/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`. The PR validation run also uploads `nightshift-debug-apk`. The PR records the completed build and its artifact link/hash, so an earlier milestone's APK is not mistaken for this revision. Both modes use the same installable package.

## Required physical accessibility check

This part of #8 remains **pending**. Use the same APK and evidence record as [Two_Phone_Test.md](Two_Phone_Test.md), and record device model, Android version, TalkBack version, UI language, font/display scaling, commit and APK hash. Use consenting adults and fictional test identities only.

1. At the phone's largest font setting, test both Tamil and English. Open sign-in, all three Customer destinations, all three Listener destinations, the pre-call dialog, an active call and a history result. Verify that text wraps, content scrolls, and Continue, Retry, Accept, End call and Sign out remain reachable without clipped labels.
2. Enable TalkBack and traverse each screen in reading order. Confirm title/context before controls, descriptive field labels, selected navigation destination and mode, listener-specific Call labels, and meaningful labels/state for mute and speaker controls. Confirm no duplicate announcements caused by loading indicators or decorative icons.
3. Enter Recents with a delayed backend response. Confirm a loading announcement and no premature empty-history statement. Disconnect the API before a first history load, reconnect and activate Retry. Confirm the failure is announced and the completed records replace it.
4. With existing history visible, fail a refresh and a subsequent page separately. Verify that rows remain available, Retry requests the failed data and does not duplicate rows, and the failure message clears on success. Check this in both UI languages.
5. Close/reopen from Recents and Profile, then repeat after switching Customer/Listener modes. Confirm the correct destination is restored and an active call still takes precedence. Test both touch and TalkBack activation.
6. Complete the two-phone call procedure. Verify that TalkBack can reach Accept, Decline/Cancel, Mute, Speaker and End call, that ending immediately stops local capture, and that both users can read the resulting history record.

Record pass/fail and any defect references for every case. A passing widget test or an uploaded APK does not complete this physical-device check. No product decision, production sign-in, provider delivery, media cutoff or release approval is inferred from this UI work.
