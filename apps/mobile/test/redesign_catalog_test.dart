import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/features/redesign/design_catalog.dart';
import 'package:nightshift/features/redesign/design_system.dart';
import 'package:nightshift/features/redesign/home_designs.dart';
import 'fakes.dart';

void main() {
  test('the source collection maps each of its 54 IDs exactly once', () {
    expect(nativeDesigns.map((d) => d.id).toSet(),
        {for (var i = 1; i <= 54; i++) i});
    expect(nativeDesigns.length, 54);
    expect(nativeDesigns.every((d) => d.title.isNotEmpty), isTrue);
  });

  for (final scale in [1.0, 2.0]) {
    for (final design in nativeDesigns) {
      testWidgets(
          'native design ${design.id} renders at text scale $scale without live operations',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FakeApi();
        final app = AppController(
            api: api,
            store: MemoryStore(),
            audio: FakeAudio(),
            startTimers: false);
        final boundary = GlobalKey();
        await tester.pumpWidget(ProviderScope(
          overrides: [appControllerProvider.overrideWith((_) => app)],
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: nightshiftTheme(),
                home: MediaQuery(
                    data: MediaQueryData(
                        size: const Size(390, 844),
                        textScaler: TextScaler.linear(scale)),
                    child: buildNativeDesign(design.id)),
              )),
        ));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull,
            reason: 'Design ${design.id}: ${design.title} at $scale');
        expect(find.byType(Scaffold), findsWidgets);
        expect(api.requests, isEmpty,
            reason:
                'Opening a design must not perform an authenticated operation.');
        if (scale == 1 &&
            const bool.fromEnvironment('CAPTURE_NATIVE_DESIGNS')) {
          final renderer = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final picture = await renderer.toImage();
            final bytes =
                await picture.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../artifacts/flutter-designs/${design.id.toString().padLeft(2, '0')}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }

  testWidgets(
      'filter selections update Riverpod without changing account state',
      (tester) async {
    final api = FakeApi();
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => app)],
        child: MaterialApp(
            theme: nightshiftTheme(),
            home: const HomeDesignScreen(designId: 41))));
    await tester.tap(find.text('English'));
    await tester.pump();
    final scope = ProviderScope.containerOf(
        tester.element(find.byType(HomeDesignScreen)));
    expect(scope.read(homeDesignProvider(41)).language, 'English');
    expect(app.language, 'ta');
    expect(api.requests, isEmpty);
  });
}
