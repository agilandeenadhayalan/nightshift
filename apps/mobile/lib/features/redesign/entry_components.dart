import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system.dart';

/// Shared native login sheet. The caller owns every authentication action.
class NightshiftAuthLayout extends StatelessWidget {
  const NightshiftAuthLayout(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.sheetTitle,
      required this.children,
      this.badge,
      this.onBack,
      this.backLabel = 'Back'});
  final String title, subtitle, sheetTitle, backLabel;
  final List<Widget> children;
  final Widget? badge;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: NsColors.background,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 16, 24, 28),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          if (onBack != null)
                                            IconButton(
                                                onPressed: onBack,
                                                tooltip: backLabel,
                                                icon: const Icon(
                                                    Icons.arrow_back)),
                                          if (onBack != null)
                                            const SizedBox(width: 8),
                                          const Expanded(
                                              child: NightshiftBrand(size: 23)),
                                        ]),
                                        const SizedBox(height: 30),
                                        Text(title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium),
                                        const SizedBox(height: 8),
                                        Text(subtitle,
                                            style: const TextStyle(
                                                color: NsColors.muted)),
                                      ])),
                              Container(
                                  key: const Key('live-auth-sheet'),
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 12, 24, 28),
                                  decoration: const BoxDecoration(
                                      color: Color(0xff0e1422),
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(30)),
                                      border: Border(
                                          top: BorderSide(
                                              color: Color(0xff354057)))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Center(
                                            child: Container(
                                                width: 44,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xff3e495b),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)))),
                                        const SizedBox(height: 24),
                                        Row(children: [
                                          Expanded(
                                              child: Text(sheetTitle,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge)),
                                          if (badge != null) ...[
                                            const SizedBox(width: 8),
                                            badge!
                                          ]
                                        ]),
                                        const SizedBox(height: 20),
                                        ...children,
                                      ])),
                            ])),
                  )),
        ))),
      );
}

/// One accessible/autofill input; the six decorative cells never expose digits.
class NightshiftOtpField extends StatelessWidget {
  const NightshiftOtpField(
      {super.key,
      required this.controller,
      required this.label,
      this.enabled = true});
  final TextEditingController controller;
  final String label;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: const TextStyle(color: NsColors.muted)),
        const SizedBox(height: 10),
        SizedBox(
            height: 64,
            child: Stack(children: [
              Positioned.fill(
                  child: ExcludeSemantics(
                      child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => Row(children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                        child: Container(
                            key: ValueKey('otp-cell-$i'),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: NsColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: enabled && i == value.text.length
                                        ? NsColors.cyan
                                        : const Color(0xff354057))),
                            child: Text(i < value.text.length ? '•' : '',
                                style: const TextStyle(fontSize: 26)))),
                  ],
                ]),
              ))),
              Positioned.fill(
                  child: Semantics(
                      label: label,
                      child: TextField(
                        key: const Key('phone-code'),
                        controller: controller,
                        enabled: enabled,
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enableSuggestions: false,
                        obscureText: true,
                        maxLength: 6,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        style: const TextStyle(
                            color: Colors.transparent, fontSize: 26),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(
                            filled: false,
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none),
                      ))),
            ])),
      ]);
}

/// A permission rationale only. Requests and media lifetime remain caller-owned.
class NightshiftPermissionCard extends StatelessWidget {
  const NightshiftPermissionCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.explanation,
      required this.action,
      this.footer});
  final IconData icon;
  final String title, explanation;
  final Widget action;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => NightshiftSurface(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
            Center(child: NightshiftIllustration(icon: icon, size: 64)),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            Text(explanation,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NsColors.muted)),
            const SizedBox(height: 24),
            action,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ]));
}

class NightshiftVoiceSampleVisual extends StatelessWidget {
  const NightshiftVoiceSampleVisual(
      {super.key, required this.title, required this.caption});
  final String title, caption;
  @override
  Widget build(BuildContext context) => NightshiftSurface(
          child: Column(children: [
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 24),
        ExcludeSemantics(
            child: SizedBox(
                height: 70,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 25; i++)
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Center(
                                child: Container(
                                    height: 12.0 + ((i * 17) % 55),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: i < 13
                                            ? NsColors.cyan
                                            : NsColors.violet))))),
                ]))),
        const SizedBox(height: 20),
        Text(caption, textAlign: TextAlign.center),
      ]));
}

class NightshiftEntryPortraitScene extends StatelessWidget {
  const NightshiftEntryPortraitScene({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 276,
      child: LayoutBuilder(
          builder: (_, box) => Stack(alignment: Alignment.center, children: [
                Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          NsColors.violet.withAlpha(80),
                          Colors.transparent
                        ]))),
                Positioned(
                    left: 4,
                    top: 54,
                    child: Transform.rotate(
                        angle: -.13,
                        child: const AvatarPortrait(
                            assetPath: 'assets/avatars/male/avatar_07.png',
                            width: 108,
                            height: 152))),
                Positioned(
                    right: 4,
                    top: 34,
                    child: Transform.rotate(
                        angle: .12,
                        child: const AvatarPortrait(
                            assetPath: 'assets/avatars/female/avatar_15.png',
                            width: 108,
                            height: 158))),
                Positioned(
                    top: 72,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: NsColors.background,
                            borderRadius: BorderRadius.circular(30),
                            border:
                                Border.all(color: NsColors.cyan.withAlpha(140)),
                            boxShadow: [
                              BoxShadow(
                                  color: NsColors.violet.withAlpha(75),
                                  blurRadius: 28)
                            ]),
                        child: const AvatarPortrait(
                            assetPath: 'assets/avatars/female/avatar_03.png',
                            width: 134,
                            height: 170))),
                Positioned(
                    top: 12,
                    left: box.maxWidth * .4,
                    child:
                        _sceneIcon(Icons.nights_stay_rounded, NsColors.gold)),
                Positioned(
                    bottom: 11,
                    left: 20,
                    child: _sceneIcon(Icons.headphones_rounded, NsColors.cyan)),
                Positioned(
                    bottom: 24,
                    right: 22,
                    child: _sceneIcon(
                        Icons.favorite_rounded, const Color(0xfff472b6))),
              ])));
  Widget _sceneIcon(IconData icon, Color color) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xff1d1735),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(70))),
      child: Icon(icon, size: 23, color: color));
}
