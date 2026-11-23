import 'package:flutter/material.dart';
import 'design_system.dart';

/// Shared by the account screens and the design collection. Content always
/// comes from the caller; this presentation does not invent identity or balance.
class NightshiftProfileHero extends StatelessWidget {
  const NightshiftProfileHero(
      {super.key,
      required this.name,
      required this.roleLabel,
      this.avatarCode,
      this.assetPath,
      this.subtitle,
      this.footer,
      this.onEdit,
      this.editLabel,
      this.roleIcon = Icons.person_outline});
  final String name, roleLabel;
  final String? avatarCode, assetPath, subtitle, editLabel;
  final Widget? footer;
  final VoidCallback? onEdit;
  final IconData roleIcon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
          color: const Color(0xFF171722),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white10)),
      child: Column(children: [
        if (editLabel != null)
          Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                  tooltip: editLabel,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined,
                      size: 19, color: NsColors.muted)))
        else
          const SizedBox(height: 16),
        NightshiftAvatar(
            name: name, avatarCode: avatarCode, assetPath: assetPath, size: 94),
        const SizedBox(height: 16),
        Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: NsColors.muted, fontSize: 11))
        ],
        const SizedBox(height: 11),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: NsColors.violet.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NsColors.violet.withAlpha(65))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(roleIcon, size: 15, color: const Color(0xFFC4B5FD)),
              const SizedBox(width: 7),
              Flexible(
                  child: Text(roleLabel,
                      style: const TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)))
            ])),
        if (footer != null) ...[const SizedBox(height: 16), footer!],
      ]));
}

class NightshiftPortraitCard extends StatelessWidget {
  const NightshiftPortraitCard(
      {super.key,
      required this.name,
      required this.languages,
      required this.status,
      required this.available,
      required this.rateLabel,
      required this.actions,
      this.avatarCode,
      this.assetPath,
      this.favorite = false,
      this.favoriteLabel,
      this.onFavorite,
      this.hero = false,
      this.secondaryRateLabel,
      this.onPortraitTap,
      this.portraitLabel});
  final String name, languages, status, rateLabel;
  final String? avatarCode, assetPath, favoriteLabel, secondaryRateLabel;
  final bool available, favorite, hero;
  final VoidCallback? onFavorite;
  final VoidCallback? onPortraitTap;
  final String? portraitLabel;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final portrait = assetPath ?? avatarAssetPath(avatarCode);
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Semantics(
        label: onPortraitTap == null ? null : portraitLabel,
        button: onPortraitTap != null,
        child: GestureDetector(
            onTap: onPortraitTap,
            child: Container(
                height: (hero ? 490 : 310) + (scale - 1) * 130,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(hero ? 28 : 20),
                    border: Border.all(color: Colors.white12)),
                child: Stack(fit: StackFit.expand, children: [
                  if (portrait != null)
                    AvatarPortrait(
                        assetPath: portrait, borderRadius: BorderRadius.zero)
                  else
                    Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                              Color(0xFF282344),
                              Color(0xFF172234)
                            ])),
                        child: Center(
                            child: NightshiftAvatar(
                                name: name, avatarCode: avatarCode, size: 80))),
                  const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [
                        .22,
                        .57,
                        1
                      ],
                              colors: [
                        Colors.transparent,
                        Color(0x65070913),
                        Color(0xFF090D18)
                      ]))),
                  Positioned(
                      top: 10,
                      left: 10,
                      right: 48,
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                  color: const Color(0xB3191C29),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: available
                                          ? const Color(0x8034D399)
                                          : Colors.white24)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        size: 8,
                                        color: available
                                            ? const Color(0xFF34D399)
                                            : NsColors.muted),
                                    const SizedBox(width: 5),
                                    Flexible(
                                        child: Text(status,
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: available
                                                    ? const Color(0xFF72E7BE)
                                                    : Colors.white70)))
                                  ])))),
                  if (favoriteLabel != null)
                    Positioned(
                        top: 3,
                        right: 2,
                        child: IconButton(
                            tooltip: favoriteLabel,
                            onPressed: onFavorite,
                            icon: Icon(
                                favorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: favorite
                                    ? const Color(0xFFFB7185)
                                    : Colors.white,
                                size: 22))),
                  Positioned(
                      left: hero ? 18 : 12,
                      right: hero ? 18 : 12,
                      bottom: 12,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: hero ? 24 : 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 5),
                            Text(languages,
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: hero ? 12 : 10)),
                            const SizedBox(height: 10),
                            Text(rateLabel,
                                style: const TextStyle(
                                    color: NsColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10)),
                            if (secondaryRateLabel != null) ...[
                              const SizedBox(height: 3),
                              Text(secondaryRateLabel!,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 9))
                            ],
                            const SizedBox(height: 8),
                            Row(children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i != 0) const SizedBox(width: 6),
                                Expanded(child: actions[i])
                              ]
                            ]),
                          ])),
                ]))));
  }
}

class NightshiftFeatureBanner extends StatelessWidget {
  const NightshiftFeatureBanner(
      {super.key,
      required this.title,
      required this.actionLabel,
      required this.onPressed,
      this.subtitle,
      this.icon = Icons.auto_awesome,
      this.page = 0,
      this.pageCount = 1,
      this.trailing});
  final String title, actionLabel;
  final String? subtitle;
  final VoidCallback? onPressed;
  final IconData icon;
  final int page, pageCount;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NsColors.violet.withAlpha(70)),
          gradient: const LinearGradient(colors: [
            Color(0xFF2A175B),
            Color(0xFF151838),
            Color(0xFF0D1630)
          ])),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: const TextStyle(fontSize: 11, color: NsColors.muted))
          ],
          const SizedBox(height: 8),
          TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: NsColors.gold,
                  foregroundColor: const Color(0xFF241600),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  minimumSize: const Size(44, 36)),
              onPressed: onPressed,
              child: Text(actionLabel,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800))),
          if (pageCount > 1) ...[
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < pageCount; i++)
                Container(
                    width: i == page ? 16 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                        color: i == page ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(8)))
            ])
          ],
        ])),
        const SizedBox(width: 12),
        trailing ?? Icon(icon, color: NsColors.cyan, size: 34),
      ]));
}

class NightshiftFeedSkeleton extends StatelessWidget {
  const NightshiftFeedSkeleton(
      {super.key, required this.label, this.compact = false});
  final String label;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final columns =
              MediaQuery.textScalerOf(context).scale(12) > 18 ? 1 : 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 4; i++)
              SizedBox(
                  width: columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: Container(
                      height: compact ? 180 : 245,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: NsColors.surface,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final width in [75.0, 110.0])
                              Container(
                                  width: width,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 9),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF292D42),
                                      borderRadius: BorderRadius.circular(6)))
                          ])))
          ]);
        }),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(color: NsColors.muted, fontSize: 12)),
      ]));
}

class NightshiftSessionSummary extends StatelessWidget {
  const NightshiftSessionSummary(
      {super.key,
      required this.name,
      required this.description,
      required this.date,
      this.avatarCode,
      this.assetPath,
      this.amount,
      this.video = false,
      this.missed = false,
      this.action,
      this.onTap});
  final String name, description, date;
  final String? avatarCode, assetPath, amount;
  final bool video, missed;
  final Widget? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFF151827),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withAlpha(9))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                NightshiftAvatar(
                    name: name,
                    avatarCode: avatarCode,
                    assetPath: assetPath,
                    size: 48),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(description,
                          style: TextStyle(
                              fontSize: 10,
                              color: missed
                                  ? const Color(0xFFFB7185)
                                  : NsColors.muted)),
                      const SizedBox(height: 4),
                      Text(date,
                          style: const TextStyle(
                              color: NsColors.muted, fontSize: 9)),
                      if (amount != null) ...[
                        const SizedBox(height: 6),
                        Text(amount!,
                            style: const TextStyle(
                                color: NsColors.cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))
                      ],
                    ])),
                const SizedBox(width: 8),
                action ??
                    Icon(video ? Icons.videocam_outlined : Icons.call_outlined,
                        size: 20, color: NsColors.cyan),
              ]))));
}

class NightshiftEarningsSummary extends StatelessWidget {
  const NightshiftEarningsSummary(
      {super.key,
      required this.title,
      required this.amount,
      required this.subtitle,
      this.audioLabel,
      this.videoLabel,
      this.onTap});
  final String title, amount, subtitle;
  final String? audioLabel, videoLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF282249), Color(0xFF131625)])),
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: NsColors.muted, fontSize: 10)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: Text(amount,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800))),
                          if (onTap != null)
                            const Icon(Icons.arrow_forward,
                                color: NsColors.violet)
                        ]),
                        const SizedBox(height: 8),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11, color: NsColors.muted)),
                        if (audioLabel != null || videoLabel != null) ...[
                          const SizedBox(height: 15),
                          Wrap(spacing: 9, runSpacing: 9, children: [
                            if (audioLabel != null)
                              _earningPill(
                                  audioLabel!, Icons.call, NsColors.cyan),
                            if (videoLabel != null)
                              _earningPill(
                                  videoLabel!, Icons.videocam, NsColors.violet)
                          ])
                        ]
                      ])))));
  Widget _earningPill(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withAlpha(16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(90))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700)))
      ]));
}
