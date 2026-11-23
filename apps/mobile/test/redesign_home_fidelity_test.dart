import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/features/redesign/design_system.dart';
import 'package:nightshift/features/redesign/home_designs.dart';
import 'package:nightshift/features/redesign/home_components.dart';

Future<void> openHome(WidgetTester tester, int id) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
          theme: nightshiftTheme(), home: HomeDesignScreen(designId: id))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Listener home keeps preview and wallet visible at 360px 2x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: nightshiftTheme(),
            home: const MediaQuery(
                data: MediaQueryData(
                    size: Size(360, 800), textScaler: TextScaler.linear(2)),
                child: HomeDesignScreen(designId: 29)))));
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('₹20.35').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'portrait feed displays two distinct people beside each other and keeps favorite local',
      (tester) async {
    await openHome(tester, 44);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Nila'), findsOneWidget);
    final first = tester.getRect(find.text('Maya'));
    final second = tester.getRect(find.text('Nila'));
    expect(second.left, greaterThan(first.right));
    expect((first.top - second.top).abs(), lessThan(2));
    await tester.tap(find.byTooltip('Save Maya'));
    await tester.pump();
    expect(find.byTooltip('Remove Maya'), findsOneWidget);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeDesignScreen)));
    expect(container.read(homeDesignProvider(44)).favorite, isTrue);
    await tester.tap(find.byTooltip('Save Nila'));
    await tester.pump();
    expect(find.byTooltip('Remove Maya'), findsOneWidget);
    expect(find.byTooltip('Remove Nila'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Maya'));
    await tester.pump();
    expect(find.byTooltip('Save Maya'), findsOneWidget);
    expect(find.byTooltip('Remove Nila'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final id in [17, 20]) {
    testWidgets(
        'profile $id groups identity, balance and settings with supplied artwork',
        (tester) async {
      await openHome(tester, id);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
          images.any((image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName.startsWith(
                  'assets/avatars/${id == 17 ? 'male' : 'female'}/')),
          isTrue);
      expect(find.text('Language Settings'), findsOneWidget);
      expect(
          tester.getTopLeft(find.text('Language Settings')).dy, lessThan(740));
      await tester.tap(find.text('Language Settings'));
      await tester.pumpAndSettle();
      expect(find.text('தமிழ்'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (id == 20) {
        Navigator.of(tester.element(find.text('தமிழ்'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Switch to Customer'));
        await tester.pumpAndSettle();
        expect(find.text('Maya'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('sample missed session does not display earnings',
      (tester) async {
    await openHome(tester, 24);
    final row = find
        .ancestor(
            of: find.text('Missed call'),
            matching: find.byType(NightshiftSessionSummary))
        .first;
    expect(find.descendant(of: row, matching: find.textContaining('+₹')),
        findsNothing);
    expect(find.descendant(of: row, matching: find.text('—')), findsOneWidget);
  });
}
