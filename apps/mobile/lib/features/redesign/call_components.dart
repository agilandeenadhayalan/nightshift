import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_system.dart';

/// Visual frame shared by real calls. Media and command ownership stay with
/// the controller; this widget never starts a camera, timer or request.
class LiveCallStage extends StatelessWidget {
  const LiveCallStage(
      {super.key,
      required this.header,
      required this.content,
      required this.controls,
      this.background});
  final Widget header, content, controls;
  final Widget? background;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
              Color(0xFF192B47),
              Color(0xFF11172D),
              Color(0xFF080C18)
            ]))),
        if (background != null) background!,
        if (background != null)
          const IgnorePointer(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [
                0,
                .35,
                .7,
                1
              ],
                          colors: [
                Color(0x99090D1C),
                Color(0x00090D1C),
                Color(0x88090D1C),
                Color(0xF5090D1C)
              ])))),
        SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8), child: header),
          Expanded(child: content),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00080C18), Color(0xF0080C18)])),
              child: controls),
        ])),
      ]);
}

class CallStatusPill extends StatelessWidget {
  const CallStatusPill(
      {super.key, required this.label, this.icon, this.color = NsColors.cyan});
  final String label;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xD911192A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: .5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6)
        ],
        Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]));
}

class CallAttentionCard extends StatelessWidget {
  const CallAttentionCard(
      {super.key,
      required this.title,
      required this.message,
      required this.action});
  final String title, message;
  final Widget action;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF6F0FF),
          borderRadius: BorderRadius.circular(28)),
      child: Column(children: [
        const Icon(Icons.call_end, color: Color(0xFF8047D7), size: 30),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: const Color(0xFF281A3D))),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF675978))),
        const SizedBox(height: 20),
        action,
      ]));
}

class CallRoundControl extends StatelessWidget {
  const CallRoundControl(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.end = false,
      this.selected = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool end, selected;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: end
                  ? const Color(0xFFEF3E68)
                  : selected
                      ? Colors.white
                      : const Color(0xFF252B40),
              border: Border.all(
                  color: end ? const Color(0xFFFF8BA5) : Colors.white24),
              boxShadow: end
                  ? const [
                      BoxShadow(color: Color(0x555B1329), offset: Offset(0, 5))
                    ]
                  : null),
          child: Icon(icon,
              size: 25,
              color: enabled
                  ? selected && !end
                      ? NsColors.background
                      : Colors.white
                  : NsColors.muted)),
      const SizedBox(height: 9),
      Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: enabled ? Colors.white : NsColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    ]);
    final style = ButtonStyle(
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 3, vertical: 4)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))));
    return end
        ? FilledButton(onPressed: onPressed, style: style, child: content)
        : TextButton(onPressed: onPressed, style: style, child: content);
  }
}

class CallControlRow extends StatelessWidget {
  const CallControlRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final child in children) Expanded(child: child)
          ])));
}

/// A decorative motif, never a measurement or an audibility claim.
class CallWaveMotif extends StatelessWidget {
  const CallWaveMotif({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final height in [
          8.0,
          17.0,
          30.0,
          23.0,
          13.0,
          27.0,
          20.0,
          11.0,
          22.0,
          8.0
        ])
          Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                  color: NsColors.cyan, borderRadius: BorderRadius.circular(4)))
      ]));
}

class UnavailableCallGame extends StatelessWidget {
  const UnavailableCallGame(
      {super.key,
      required this.name,
      this.avatarCode,
      required this.title,
      required this.explanation,
      required this.disabledLabel,
      required this.backLabel,
      required this.onBack});
  final String name, title, explanation, disabledLabel, backLabel;
  final String? avatarCode;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          NightshiftAvatar(name: name, avatarCode: avatarCode, size: 46),
          const SizedBox(width: 12),
          Expanded(
              child: Text(name, style: Theme.of(context).textTheme.titleMedium))
        ]),
        const SizedBox(height: 20),
        Semantics(
            label: title,
            image: true,
            child: ExcludeSemantics(
                child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xFF29253D),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24)),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CustomPaint(
                                painter: const CallBoardPainter(0))))))),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFF211A36),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NsColors.violet)),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.casino, color: NsColors.gold, size: 30),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.headlineSmall))
              ]),
              const SizedBox(height: 12),
              Text(explanation, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton(onPressed: null, child: Text(disabledLabel)))
            ])),
        TextButton(onPressed: onBack, child: Text(backLabel)),
      ]);
}

const _green = Color(0xFF36BD85), _yellow = Color(0xFFF5C84C);
const _red = Color(0xFFF16B79), _blue = Color(0xFF579BED);

class CallBoardPainter extends CustomPainter {
  const CallBoardPainter(this.moves);
  final int moves;
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 15;
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = const Color(0x33FFFFFF);
    canvas.drawRect(Offset.zero & size, fill..color = const Color(0xFF090614));
    for (var y = 0; y < 15; y++) {
      for (var x = 0; x < 15; x++) {
        if ((x >= 6 && x <= 8) || (y >= 6 && y <= 8)) {
          var color = const Color(0xFF191625);
          if (y == 7 && x > 0 && x < 6) color = _green;
          if (x == 7 && y > 0 && y < 6) color = _yellow;
          if (y == 7 && x > 8 && x < 14) color = _blue;
          if (x == 7 && y > 8 && y < 14) color = _red;
          if (x == 1 && y == 6) color = _green;
          if (x == 8 && y == 1) color = _yellow;
          if (x == 13 && y == 8) color = _blue;
          if (x == 6 && y == 13) color = _red;
          final rect = Rect.fromLTWH(x * u, y * u, u, u);
          canvas.drawRect(rect, fill..color = color.withValues(alpha: .7));
          canvas.drawRect(rect, stroke);
        }
      }
    }
    void token(double x, double y, Color color) {
      final c = Offset(x * u, y * u);
      canvas.drawCircle(c + Offset(0, u * .1), u * .43,
          fill..color = Colors.black.withValues(alpha: .2));
      canvas.drawCircle(c, u * .4, fill..color = color);
      canvas.drawCircle(
          c,
          u * .4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      canvas.drawCircle(c - Offset(u * .08, u * .08), u * .22,
          fill..color = Colors.white.withValues(alpha: .45));
    }

    for (final (x, y, color) in [
      (0.0, 0.0, _green),
      (9.0, 0.0, _yellow),
      (0.0, 9.0, _red),
      (9.0, 9.0, _blue)
    ]) {
      final yard = Rect.fromLTWH(x * u, y * u, 6 * u, 6 * u);
      canvas.drawRect(
          yard,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.black, .18)!,
                  Color.lerp(color, Colors.black, .75)!
                ]).createShader(yard));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH((x + .8) * u, (y + .8) * u, 4.4 * u, 4.4 * u),
              Radius.circular(u * .3)),
          fill..color = const Color(0xB3090614));
      for (final dx in [2.0, 4.0]) {
        for (final dy in [2.0, 4.0]) {
          canvas.drawCircle(Offset((x + dx) * u, (y + dy) * u), u * .67,
              fill..color = color.withValues(alpha: .17));
          if (!(x == 0 && y == 9 && dx == 2 && dy == 2)) {
            token(x + dx, y + dy, color);
          }
        }
      }
    }
    final center = Offset(7.5 * u, 7.5 * u);
    for (final (points, color) in [
      ([Offset(6 * u, 6 * u), Offset(6 * u, 9 * u)], _green),
      ([Offset(6 * u, 6 * u), Offset(9 * u, 6 * u)], _yellow),
      ([Offset(9 * u, 6 * u), Offset(9 * u, 9 * u)], _blue),
      ([Offset(6 * u, 9 * u), Offset(9 * u, 9 * u)], _red)
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(points[0].dx, points[0].dy)
            ..lineTo(points[1].dx, points[1].dy)
            ..close(),
          fill..color = color);
    }
    for (final (x, y) in [(2.5, 8.5), (6.5, 2.5), (12.5, 6.5), (8.5, 12.5)]) {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5,
            r = u * (i.isEven ? .32 : .14);
        final p = Offset(x * u + math.cos(a) * r, y * u + math.sin(a) * r);
        if (i == 0) {
          star.moveTo(p.dx, p.dy);
        } else {
          star.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(star..close(), fill..color = const Color(0xFFBCB3D9));
    }
    token(6.5, 13.5 - (moves % 5), _red);
    token(8.5, 3.5, _yellow);
  }

  @override
  bool shouldRepaint(covariant CallBoardPainter oldDelegate) =>
      oldDelegate.moves != moves;
}
