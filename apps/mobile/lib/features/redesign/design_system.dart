import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared native tokens from the owner's November 23 screen collection.
abstract final class NsColors {
  static const background = Color(0xFF070913);
  static const surface = Color(0xFF111424);
  static const card = Color(0xFF171A2E);
  static const cyan = Color(0xFF00F7FF);
  static const violet = Color(0xFF8B5CF6);
  static const gold = Color(0xFFFBBF24);
  static const muted = Color(0xFF94A3B8);
}

ThemeData nightshiftTheme({bool light = false}) {
  final scheme = light
      ? ColorScheme.fromSeed(
          seedColor: const Color(0xFF7947EA), surface: const Color(0xFFF8F9FB))
      : const ColorScheme.dark(
          primary: NsColors.violet,
          onPrimary: Colors.white,
          secondary: NsColors.cyan,
          onSecondary: NsColors.background,
          surface: NsColors.surface,
          onSurface: Color(0xFFF1F5F9),
          error: Color(0xFFFF8A9B),
          outline: Color(0xFF475569));
  final base = ThemeData(
      useMaterial3: true, colorScheme: scheme, fontFamily: 'PlusJakartaSans');
  return base.copyWith(
    scaffoldBackgroundColor:
        light ? const Color(0xFFF8F9FB) : NsColors.background,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          letterSpacing: -1),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          letterSpacing: -.7),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          letterSpacing: -.4),
      titleLarge:
          base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    ),
    appBarTheme: AppBarTheme(
        backgroundColor: light ? Colors.white : NsColors.background,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false),
    cardTheme: CardTheme(
      color: light ? Colors.white : NsColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outline.withAlpha(50))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : NsColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outline.withAlpha(90))),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 54),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: light ? Colors.white : NsColors.surface,
      indicatorColor: NsColors.violet.withAlpha(55),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: light ? Colors.white : NsColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    ),
    dialogTheme: DialogTheme(
        backgroundColor: light ? Colors.white : NsColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    dividerTheme: DividerThemeData(color: scheme.outline.withAlpha(60)),
    chipTheme: base.chipTheme.copyWith(
        backgroundColor: light ? Colors.white : NsColors.card,
        selectedColor: NsColors.violet.withAlpha(70),
        labelStyle: TextStyle(
            color: light ? const Color(0xff382351) : const Color(0xffe2e8f0)),
        secondaryLabelStyle:
            TextStyle(color: light ? const Color(0xff5426a8) : Colors.white),
        checkmarkColor: light ? const Color(0xff6d28d9) : NsColors.cyan,
        side: BorderSide(color: scheme.outline.withAlpha(60)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}

class NightshiftBrand extends StatelessWidget {
  const NightshiftBrand({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: size * 1.5,
            height: size * 1.5,
            child: const CustomPaint(painter: NightshiftMascotPainter())),
        const SizedBox(width: 8),
        Flexible(
            child: Text('nightshift',
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: size,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: Theme.of(context).colorScheme.onSurface))),
      ]);
}

class NightshiftMascotPainter extends CustomPainter {
  const NightshiftMascotPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final glow = Paint()
      ..color = NsColors.violet.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(50, 50), 34, glow);
    final body = Path()
      ..moveTo(17, 57)
      ..cubicTo(9, 23, 65, 8, 79, 37)
      ..cubicTo(97, 69, 63, 90, 34, 73)
      ..lineTo(11, 78)
      ..lineTo(23, 64)
      ..close();
    canvas.drawPath(
        body,
        Paint()
          ..shader = const LinearGradient(
                  colors: [NsColors.cyan, NsColors.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              .createShader(const Rect.fromLTWH(10, 10, 80, 80)));
    final eye = Paint()..color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 39, 7, 15), const Radius.circular(4)),
        eye);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(61, 36, 7, 15), const Radius.circular(4)),
        eye);
    canvas.drawArc(
        const Rect.fromLTWH(43, 48, 24, 15),
        .15,
        math.pi - .4,
        false,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(84, 18), 4, Paint()..color = NsColors.cyan);
    canvas.restore();
  }

  @override
  bool shouldRepaint(NightshiftMascotPainter oldDelegate) => false;
}

/// Only a selected, allowlisted built-in code can identify a portrait asset.
/// Neither role, display name nor account ID determines a person's appearance.
String? avatarAssetPath(String? code) {
  if (code == null ||
      !RegExp(r'^(male|female)_(0[1-9]|[12][0-9]|30)$').hasMatch(code)) {
    return null;
  }
  final parts = code.split('_');
  return 'assets/avatars/${parts[0]}/avatar_${parts[1]}.png';
}

class AvatarPortrait extends StatelessWidget {
  const AvatarPortrait(
      {super.key,
      required this.assetPath,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.alignment = Alignment.topCenter,
      this.borderRadius = const BorderRadius.all(Radius.circular(24))});
  final String assetPath;
  final double? width, height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final BorderRadiusGeometry borderRadius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => SizedBox(
              width: width,
              height: height,
              child: const ColoredBox(
                  color: NsColors.card,
                  child: Center(
                      child: Icon(Icons.person_outline_rounded,
                          color: NsColors.muted)))),
        ),
      );
}

class NightshiftAvatar extends StatelessWidget {
  const NightshiftAvatar(
      {super.key,
      required this.name,
      this.size = 80,
      this.listener = false,
      this.avatarCode,
      this.assetPath});
  final String name;
  final double size;
  final bool listener;
  final String? avatarCode, assetPath;
  @override
  Widget build(BuildContext context) => Semantics(
        label: name,
        image: true,
        child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: listener
                        ? [const Color(0xFF6D28D9), const Color(0xFFDB2777)]
                        : [const Color(0xFF164E63), const Color(0xFF7C3AED)]),
                border:
                    Border.all(color: NsColors.cyan.withAlpha(90), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: NsColors.violet.withAlpha(40), blurRadius: 30)
                ]),
            padding: const EdgeInsets.all(3),
            child: assetPath != null || avatarAssetPath(avatarCode) != null
                ? AvatarPortrait(
                    assetPath: assetPath ?? avatarAssetPath(avatarCode)!,
                    width: size - 6,
                    height: size - 6,
                    borderRadius: BorderRadius.circular(size))
                : Center(
                    child: Text(
                        switch (avatarCode) {
                          'star' => '⭐',
                          'leaf' => '🌿',
                          'wave' => '🌊',
                          _ => '🌙',
                        },
                        style: TextStyle(fontSize: size * .48)))),
      );
}

class NightshiftSurface extends StatelessWidget {
  const NightshiftSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(60))),
        child: child,
      );
}

class NightshiftBackdrop extends StatelessWidget {
  const NightshiftBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.6,
                colors: [Color(0xFF241044), NsColors.background],
                stops: [0, .7])),
        child: child,
      );
}
