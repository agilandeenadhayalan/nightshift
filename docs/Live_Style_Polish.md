# Live app style polish — 23 November 2026

The owner clarified: **“Polish the current live app style.”** This keeps the current NightShift identity and familiar Customer/Listener navigation. The HTML collection is reference material; it does not replace that instruction. In particular, the Customer feed keeps its normal-width two-column layout, with a single column when larger text or a narrow viewport needs it.

## Visual plan

- Palette: midnight `#070913`, surface `#111424`, raised card `#171A2E`, cyan `#00F7FF`, violet `#8B5CF6`, and readable muted text `#A8B3C9`. Gold `#FBBF24` identifies financial values; status colors keep their existing meaning.
- Type: Space Grotesk for concise headings, Plus Jakarta Sans for readable content/actions, and the existing NightShift brand treatment. Use a consistent heading/body hierarchy and retain system Tamil fallback. Large text changes layout rather than being silently reduced.
- Imagery: the 60 supplied portraits remain unchanged. Account views use the selected avatar; live video uses the RTC adapter. Introductory portraits are decorative. Loading, permissions and empty/error states use one coordinated illustration treatment rather than invented people or a claim that someone is online.
- Layout: bring people and primary actions above long promotional or explanatory blocks. Keep real balances, rates and allowance visible. Put optional detail behind clearly labeled disclosures. Separate portrait imagery from dense card text, maintain predictable page gutters and left-back navigation, and reserve the strongest action styling for the next useful action.
- Interaction: retain server authority, consent, owner/session guards, independent availability switches, and pinned End/Cancel. Unavailable services remain explicitly unavailable. Staff tools remain separately authorized.

The distinctive feature is the supplied portrait collection, supported by a quiet dark foundation and cyan conversation actions. Extra glows, repeated wallet banners and competing large headings are reduced so the images and live state remain the focus. This is a visual refinement, not authorization to activate payments, payouts, support delivery, ratings or synchronized games.

## Review and delivery

Review actual-route captures at normal phone size and large Tamil text, including call controls and local-video thumbnails. Check loading, empty, failed and disabled states as well as populated screens. Run the relevant existing state/lifecycle regressions, the full Flutter suite and analyzer, repository checks and the required audio reference checks before building the next in-place phone update. Record the final evidence after validation.

## Implemented and verified

The Customer directory now uses a compact credit summary and taller portraits with the availability badge below the face. Call information and actions sit beneath each photo. Profile mode switching uses a quieter violet card, and history has clearer details arrows, concise timestamps and full dates in expanded details. Large-text history filters stack vertically with fully constrained labels.

Saved Listener application drafts start with status and editable content; only new applications show the full introduction. Bio guidance has a separate line from the character counter. Account, permission, wallet, earnings and support screens share the same illustration and heading treatment. The live wallet prioritizes actual test balances and puts sample packs behind an explicit disclosure. Shared loading, empty, failure and privacy states retain their existing actions and consent guards.

Video keeps peer identity in the header and uses a compact local-preview status. Large-text media controls keep their complete accessible names. Rate, charged amount and confirmed allowance stay grouped together; only secondary session details collapse. Matching prioritizes the actual remaining wait budget and keeps recovery messages. End and Cancel remain reachable on short screens.

- Full Flutter suite: **765 passed, 24 existing explicit skips**, zero failures. Analyzer: **no issues**. This includes all 54 catalog variants at normal and 2× text size plus actual-route and lifecycle coverage.
- **42 synthetic actual-route captures** reviewed across entry, commerce, home/profile/history, calls/matching, privacy and deletion receipts. Normal and large Tamil layouts exposed and resolved portrait-label overlap, application helper/counter overlap, clipped history segments and hidden video peer identity.
- Repository secret, contract and dependency guards and **27 tooling tests** pass. The unchanged runnable audio reference passes **3/3** under Node 24.13.0.
- Independent reviews of home/account integration, calls/matching and shared/privacy changes found no remaining blocking issue. No backend, controller, credential, tariff, balance, provider or original portrait/font asset changes are included in this polish.

Private delivery targets ARM64 debug APK **6012**, updating the existing package on Redmi and Motorola without clearing data. The build verifies the prior private inputs, signer, bundled assets and native alignment; installation requires successful CI for the committed source and no active calls or matching requests. Build, install and device-health receipts remain ignored local artifacts. No new live media test or production-launch claim is implied by this visual update.
