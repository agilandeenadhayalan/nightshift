# Portrait and typography assets

On 23 November 2026 the owner said the first Flutter pass did not match the supplied design closely enough and supplied two portrait archives for the male and female screen designs. The revised direction keeps the original midnight palette, uses the reference typography and compact proportions, and replaces placeholder headset/person graphics with the supplied artwork wherever an explicit avatar selection or a design example is available.

## Supplied artwork

- `Indian_Male_Avatars_Stomach_Crop_30.zip`: 30 PNGs, stored unchanged under `apps/mobile/assets/avatars/male/`.
- `Mixed_Outfit_Avatars_30.zip`: 30 PNGs, stored unchanged under `apps/mobile/assets/avatars/female/`.
- Source archive SHA-256: male `b5617218fcc4090be245bfa7328c2fca03fb8d035803d3c863ca6fd8c78c5465`; female `6357b4367685f33ccb06aa18ab9a6272526f2335dbaf4a70cde6db7853922235`.
- Assets are bundled locally; rendering them does not contact an image provider. The images already include their coloured backgrounds. Flutter clips and positions the originals rather than altering them.
- Built-in codes are `male_01`–`male_30` and `female_01`–`female_30`. Existing `moon`, `star`, `leaf`, and `wave` remain emoji choices. Both collections are available to both Customer and Listener; selection changes appearance only.
- Actual profiles, directory cards and calls use the saved allowlisted code. Missing or unknown codes use a neutral fallback. Roles, names and account identifiers never infer a person's gender or portrait. Design examples use explicit illustrations and sample labels.
- Migration 020 expands the existing avatar constraint without rewriting choices. New portrait selection requires the updated API and database; this UI work does not migrate the running phone backend or install an APK.
- Omitted optional portrait fields and the original four codes remain supported. An older APK's required onboarding enum may reject a newly selected portrait code; coordinate API, database and APK rollout rather than claiming every mixed-version combination works.

## Fonts

The reference designs use Plus Jakarta Sans for interface copy, Space Grotesk for display text and Outfit for the splash wordmark. The unmodified variable TTFs are bundled from the [Google Fonts repository](https://github.com/google/fonts), together with each family's SIL Open Font License:

- [Plus Jakarta Sans](https://github.com/google/fonts/tree/main/ofl/plusjakartasans)
- [Space Grotesk](https://github.com/google/fonts/tree/main/ofl/spacegrotesk)
- [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit)

Local licenses reside beside the font files under `apps/mobile/assets/fonts/` and are included in the application asset bundle. These font licenses do not establish separate rights for the owner-supplied portraits.

## Visual direction

Retain the source colours: midnight `#070913`, canvas `#0B0D17`, surface `#111424`, cyan `#00F7FF`, violet `#8B5CF6`, and gold `#FBBF24`. Use 16–20 px horizontal spacing, compact grouped profile rows, portrait-led discovery, full-canvas call compositions and anchored controls. Keep preview notices small and clear; use actual user-facing explanations where an action is unavailable. Source promises about verified gender, guaranteed income, instant payouts or security are not introduced by a visual redesign.
