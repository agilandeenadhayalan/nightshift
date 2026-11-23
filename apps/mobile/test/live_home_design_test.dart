import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/redesign/home_components.dart';
import 'fakes.dart';
import 'discovery_state_test.dart' show FakeEvents, member;
import 'discovery_ui_test.dart' show reveal;

FakeApi liveHomeApi({bool listener = false}) => FakeApi()
  ..user = {
    ...userJson(listener: listener, approved: true),
    'avatarCode': listener ? 'female_01' : 'male_01',
    'availability': {
      'online': false,
      'audioEnabled': true,
      'videoEnabled': true
    },
  }
  ..directory = [
    for (var i = 0; i < 4; i++)
      {
        ...member(i == 0 ? 'listener-id' : 'listener-$i'),
        'displayName': 'Test Listener ${i + 1}',
        'avatarCode': i == 3 ? 'male_02' : 'female_0${i + 1}',
        'audioAvailable': true,
        'videoAvailable': i.isEven,
        'videoRate': rateJson(video: true),
      }
  ]
  ..historyItems = [
    for (var i = 0; i < 3; i++)
      {
        ...callJson(state: 'ended', video: i.isOdd),
        'id': 'history-$i',
        'customerAvatarCode': 'male_0${i + 1}',
        'listenerAvatarCode': 'female_0${i + 1}',
      }
  ];

Future<AppController> mountLiveHome(WidgetTester tester,
    {bool listener = false,
    String path = '/home',
    String locale = 'en',
    FakeApi? api,
    Widget Function(Widget)? wrapper}) async {
  final app = AppController(
      api: api ?? liveHomeApi(listener: listener),
      store: MemoryStore()
        ..values.addAll({'token': 'saved', 'lastPath': path, 'locale': locale}),
      audio: FakeVideo(),
      directoryEvents: FakeEvents(),
      startTimers: false);
  await app.initialize();
  await app.loadHistory();
  if (listener) await app.refreshListenerAvailability();
  const child = NightShiftApp();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: wrapper?.call(child) ?? child));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets(
      'real Customer home uses portrait grid and opens actual wallet information',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountLiveHome(tester);
    final cards = tester
        .widgetList<NightshiftPortraitCard>(find.byType(NightshiftPortraitCard))
        .toList();
    expect(cards.length, greaterThanOrEqualTo(2));
    expect(cards.first.name, 'Test Listener 1');
    expect(cards.first.avatarCode, 'female_01');
    final first = tester.getRect(find.text('Test Listener 1'));
    final second = tester.getRect(find.text('Test Listener 2'));
    expect(second.left, greaterThan(first.right));
    expect((first.top - second.top).abs(), lessThan(3));
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.textContaining('FLAT ₹'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Open wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Your next conversation'), findsOneWidget);
    expect(find.text('Available test coins'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Open wallet'));
    await tester.pumpAndSettle();
    expect(find.byType(NightshiftPortraitCard), findsNothing);
  });

  testWidgets(
      'full portrait and filter sheets use current directory state and real commands',
      (tester) async {
    final app = await mountLiveHome(tester);
    await tester.tap(find.text('Test Listener 1'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<NightshiftPortraitCard>(
                find.byType(NightshiftPortraitCard))
            .any((c) => c.hero && c.name == 'Test Listener 1'),
        isTrue);
    await reveal(tester, find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Filters'));
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'English'));
    await tester.pumpAndSettle();
    expect(app.language, 'en');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(app.discovery.availableOnly, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Listener header and profile use earnings and saved portrait, not Customer wallet',
      (tester) async {
    final state = await mountLiveHome(tester, listener: true);
    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect((chip.label as Text).data, '₹24.99');
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final hero = tester
        .widget<NightshiftProfileHero>(find.byType(NightshiftProfileHero));
    expect(hero.avatarCode, state.user!.avatarCode);
    expect(hero.roleLabel, 'Listener');
    expect(hero.footer, isNull);
    expect(find.text('Available test coins'), findsNothing);
  });

  testWidgets(
      'mixed history uses each call participant role after switching modes',
      (tester) async {
    final api = liveHomeApi(listener: true)
      ..user = {
        ...userJson(approved: true),
        'mode': 'listener',
        'avatarCode': 'male_01'
      }
      ..historyItems = [
        {
          ...callJson(state: 'ended'),
          'id': 'as-customer',
          'customerAvatarCode': 'male_01',
          'listenerAvatarCode': 'female_02'
        },
        {
          ...callJson(state: 'ended'),
          'id': 'as-listener',
          'customerId': 'other',
          'listenerId': 'customer-id',
          'customerName': 'Other customer',
          'listenerName': 'Test Customer',
          'customerAvatarCode': 'male_04',
          'listenerAvatarCode': 'male_01'
        },
      ];
    await mountLiveHome(tester, listener: true, path: '/history', api: api);
    final rows = tester
        .widgetList<NightshiftSessionSummary>(
            find.byType(NightshiftSessionSummary))
        .toList();
    expect(rows[0].avatarCode, 'female_02');
    expect(rows[0].amount, isNull);
    expect(rows[1].avatarCode, 'male_04');
    expect(rows[1].amount, '₹8.33');
    expect(find.text('Call ID: as-listener'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('history-details-as-listener')));
    await tester.pumpAndSettle();
    expect(find.text('Call ID: as-listener'), findsOneWidget);
    expect(find.text('Report or block'), findsOneWidget);
    expect(find.text('Rate conversation'), findsNothing);
  });

  testWidgets(
      'initial live directory uses the shared skeleton without invented listeners',
      (tester) async {
    final gate = Completer<Json>();
    final api = liveHomeApi()
      ..interceptor = (method, path, body) async =>
          path.startsWith('/listeners?') ? gate.future : null;
    await mountLiveHome(tester, api: api);
    expect(find.byType(NightshiftFeedSkeleton), findsOneWidget);
    expect(find.byType(NightshiftPortraitCard), findsNothing);
    gate.complete({
      'items': <Json>[],
      'nextCursor': null,
      'viewEpoch': 'fixture-view',
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String(),
      'truncated': false
    });
    await tester.pumpAndSettle();
    expect(find.byType(NightshiftFeedSkeleton), findsNothing);
    expect(find.text('No listeners match this filter'), findsOneWidget);
  });

  for (final listener in [false, true]) {
    for (final path in ['/home', '/profile', '/history']) {
      testWidgets(
          'live ${listener ? 'Listener' : 'Customer'} $path fits Tamil 390x600 at 2x',
          (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await mountLiveHome(tester,
            listener: listener, path: path, locale: 'ta');
        final navigation =
            tester.widget<NavigationBar>(find.byType(NavigationBar));
        final destination = navigation.destinations[navigation.selectedIndex]
            as NavigationDestination;
        expect((destination.icon as Icon).color, Colors.white);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('PREVIEW'), findsNothing);
      });
    }
  }
}
