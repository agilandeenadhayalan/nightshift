# Native designs in the phone app

The owner requested that the 54-screen gallery be applied to the actual phone app on 23 November 2026. This map distinguishes a visual design from a backend capability. Customer and Listener remain the only customer-facing modes. Staff access uses its existing separately authorized workspace.

Live pages bind the shared visual components to AppController and account-scoped Riverpod state. The gallery supplies sample data to those components. Gallery names, amounts, availability and outcomes must never become live account data.

| Design | Live destination or state | Behavior boundary |
| --- | --- | --- |
| 01 | Startup splash | Existing initialization and session restoration decide the next route. |
| 02 | Wallet → payment methods → bank selection | Local selection only; no bank authorization or payment. |
| 03 | Welcome/sign-in | Portrait introduction leads to existing sign-in actions. |
| 04 | Wallet → card information | Card collection is disabled; no PAN or CVV input. |
| 05 | Camera permission explanation variant, shared with 47/53 | Android permission and per-call consent remain separate. |
| 06 | Customer home → instant match | Existing server matching flow and cancellation. |
| 07 | Notification permission explanation | Does not enable unconfigured background invitations. |
| 08 | Nearby-device permission explanation | An explanation cannot grant Android permission. |
| 09 | Notification rationale variant | Shares the same permission boundary as 07. |
| 10 | Listener earnings | Loaded server call settlements, clearly labeled test earnings; no cash withdrawal. |
| 11 | Customer directory loading | Skeleton while real discovery is loading. |
| 12 | Card layout variant | Same disabled collection boundary as 04. |
| 13 | Profile → Call permissions → Microphone | Existing Android permission action retains authority; this does not record a voice sample. |
| 14 | Listener application submitted | Pending state appears only from server application status. |
| 15 | Wallet | Actual test-credit snapshot; sample packs cannot be purchased. |
| 16 | Payment failure design | Review-only result; there is no configured live payment to fail. |
| 17 | Customer profile | Current account identity, avatar and account actions. |
| 18 | Customer history → Call details → Rate conversation | Owned ended session with positive connected time and no active call; rating submission remains unavailable. |
| 19 | Listener orientation | Informational guide; no invented training-video playback or completion. |
| 20 | Listener profile | Actual Listener identity, test-earnings entry and account actions. |
| 21 | Payment processing design | Review-only result; no invented pending transaction. |
| 22 | Edit profile | Current profile loads before editing; saving uses existing consent and owner guards. |
| 23 | Listener application introduction | Applying does not grant Listener approval or promise earnings. |
| 24 | Listener call history | Actual sessions and test settlements, with expandable details. |
| 25 | Wallet → payment methods | Local presentation choices; no checkout. |
| 26 | Community guidelines | Existing guide and consent boundaries. |
| 27 | Phone sign-in → OTP | One real autofill input under six decorative cells; consent, retry and attempt guards retained. |
| 28 | Listener voice-sample step | Existing private WAV selection/upload/consent flow; no automatic recording. Waveform is presentation, not a fabricated recording. |
| 29 | Listener home | Independent persisted Audio and Video switches, actual effective availability. |
| 30 | Phone sign-in | Actual entered number and existing Firebase flow; no invented saved numbers. |
| 31 | Customer call history | Actual participants, duration, status and test-credit charges. |
| 32 | Directory skeleton variant | Same real loading state as 11. |
| 33 | In-call game design | Board presentation can be shown; synchronized games and moves remain unavailable. |
| 34 | Customer home information carousel | Factual test-credit information replaces unapproved offers. |
| 35 | Help & Support | Category selection works; ticket submission is clearly unavailable. |
| 36 | Video call stage | Actual RTC stage; no unsupported face-censor or privacy guarantee. |
| 37 | Call conflict / uncertain state | Existing recover, decline, cancel and End actions remain authoritative. |
| 38 | Listener video stage | Role-specific composition; does not claim the Customer's face is hidden. |
| 39 | Home information carousel variant | Same factual content boundary as 34. |
| 40 | Listener in-call game design | No invented game participant, earning or synchronized state. |
| 41 | Customer discovery filters | Account-fenced server discovery and matching choices. |
| 42 | Nearby-device rationale variant | Same permission boundary as 08. |
| 43 | Home information sheet | Source offer composition uses test-wallet facts, without an unapproved discount. |
| 44 | Customer home directory | Stored Listener avatar selections, actual status and separate Audio/Video actions. |
| 45 | Home information sheet variant | Same factual content boundary as 43. |
| 46 | Listener video call | Actual session/tariff/earnings information; pinned call controls. |
| 47 | Video preparation | Existing camera/microphone permissions and per-call consent. |
| 48 | Listener audio call | Current participant, session details and anchored media/End controls. |
| 49 | In-call game entry | Clearly unavailable synchronized game; End remains reachable. |
| 50 | Customer audio call | Centered participant portrait and compact call controls. |
| 51 | Video/game composition | Video lifecycle remains active and End reachable; game remains unavailable. |
| 52 | Two-way video call | Actual remote stage and local preview after existing consent. |
| 53 | Camera/audio permission explanation | Does not itself start a call or publish media. |
| 54 | Finding/connecting | Actual matching state, portrait hierarchy and anchored cancellation. |

Payment processing/failure are retained in design review until a real payment integration exists. Other alternative compositions share a live route/state rather than creating duplicate navigation destinations. This is not a claim that 54 independent production features are enabled.

Existing owner-dependent launch decisions remain unchanged: real payment/payout providers, prices/offers, support ownership and coverage, rating persistence, shared-game behavior, training content and any privacy claim require their corresponding implementation and acceptance criteria. This visual update neither supplies those decisions nor closes those launch issues.
