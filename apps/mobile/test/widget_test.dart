import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'fakes.dart';

void main() {
  Future<AppController> setup(WidgetTester tester,
      {bool listener = false, String locale = 'en'}) async {
    final api = FakeApi()
      ..user = userJson(listener: listener, approved: listener);
    final state = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false);
    await state.initialize();
    await state.setLocale(locale);
    await state.login(
        'http://localhost:3000', listener ? 'listener' : 'customer', 'key');
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
      'Customer has three destinations and no Listener earning controls',
      (tester) async {
    await setup(tester);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsOneWidget);
    await tester.tap(find.text('Recents'));
    await tester.pumpAndSettle();
    expect(find.text('No completed calls yet'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Listener approval required'), findsOneWidget);
    expect(find.text('Switch to Listener'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  testWidgets(
      'approved Listener navigation includes channel controls and history',
      (tester) async {
    final state = await setup(tester, listener: true);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('listener-audio-availability')));
    await tester.pumpAndSettle();
    expect(state.user!.online, isTrue);
    expect(find.text('Live · Audio only'), findsOneWidget);
    await tester.tap(find.text('Earnings'));
    await tester.pumpAndSettle();
    expect(find.text('Earnings & calls'), findsOneWidget);
  });

  testWidgets('Tamil strings and large text render without layout errors',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await setup(tester, locale: 'ta');
    expect(find.text('கண்டறி'), findsOneWidget);
    expect(find.text('சுயவிவரம்'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('சுயவிவரம்'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing server call restores directly into call screen',
      (tester) async {
    final api = FakeApi()..call = callJson();
    final store = MemoryStore()..values['token'] = 'existing-session';
    final state = AppController(
        api: api, store: store, audio: FakeAudio(), startTimers: false);
    await state.initialize();
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    expect(find.text('Calling…'), findsOneWidget);
    expect(find.text('Cancel call'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Cancel call'));
    await tester.pumpAndSettle();
    expect(find.text('Your conversations'), findsOneWidget);
    await tester.tap(find.byTooltip('Call details'));
    await tester.pumpAndSettle();
    expect(find.text('Call ID: call-id'), findsOneWidget);
  });
}
