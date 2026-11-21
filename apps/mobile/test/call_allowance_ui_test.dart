import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/features/call_allowance.dart';
import 'discovery_state_test.dart' show FakeEvents;
import 'fakes.dart';

Future<(AppController, FakeApi)> mountAllowance(WidgetTester tester, Json call,
    {bool listener = false, String locale = 'en'}) async {
  final api = FakeApi()
    ..call = call
    ..user = userJson(listener: listener, approved: listener);
  final state = AppController(
      api: api,
      store: MemoryStore()..values.addAll({'token': 'saved', 'locale': locale}),
      audio: FakeVideo(),
      directoryEvents: FakeEvents(),
      startTimers: false);
  await state.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => state)],
      child: const NightShiftApp()));
  await tester.pumpAndSettle();
  return (state, api);
}

Future<void> revealAllowance(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).last, maxScrolls: 35);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('minimum charge does not consume the remaining call allowance',
      (tester) async {
    await mountAllowance(tester, {
      ...callJson(state: 'connected'),
      'connectedMs': 40001,
      'chargeMicrocredits': 3600000,
      'maxDurationSeconds': 60,
      'durationLimitReason': 'test_credit_balance'
    });
    await revealAllowance(tester, find.text('Audio · 60 test coins / minute'));
    await revealAllowance(tester, find.text('Confirmed call time remaining'));
    expect(find.text('0:20'), findsOneWidget);
    expect(find.text('Test-credit call limit approaching'), findsOneWidget);
    await revealAllowance(tester, find.text('Test coins charged: 60'));
  });

  testWidgets('missing allowance data cannot look like exhausted test credits',
      (tester) async {
    final call = callJson(state: 'connected')..remove('maxDurationSeconds');
    await mountAllowance(tester, call);
    await revealAllowance(tester, find.text('Call time remaining unavailable'));
    expect(find.text('Test-credit call limit approaching'), findsNothing);
    expect(find.text('Call allowance exhausted'), findsNothing);
  });

  for (final (reason, label) in <(String?, String)>[
    ('test_credit_balance', 'Test-credit call limit approaching'),
    ('test_duration_cap', 'Test call time limit approaching'),
    (null, 'Call allowance nearly used'),
  ]) {
    testWidgets('low time uses only the frozen $reason classification',
        (tester) async {
      final (state, _) = await mountAllowance(tester, {
        ...callJson(state: 'connected'),
        'connectedMs': reason == 'test_credit_balance' ? 60000 : 540000,
        'maxDurationSeconds': reason == 'test_credit_balance' ? 120 : 600,
        if (reason != null) 'durationLimitReason': reason,
      });
      state.balance = 0;
      state.held = 999999999;
      state.clearError();
      await tester.pumpAndSettle();
      await revealAllowance(tester, find.text(label));
      expect(find.text('1:00'), findsOneWidget);
      final semantics = tester.widgetList<Semantics>(find.descendant(
          of: find.byType(CallAllowanceDisplay),
          matching: find.byType(Semantics)));
      expect(
          semantics.any((node) => node.properties.liveRegion == true), false);
    });
  }

  testWidgets('warning threshold and rounded display follow snapshots only',
      (tester) async {
    final (state, api) = await mountAllowance(tester, {
      ...callJson(state: 'connected'),
      'connectedMs': 539999,
      'maxDurationSeconds': 600,
      'durationLimitReason': 'test_duration_cap'
    });
    await revealAllowance(tester, find.text('Confirmed call time remaining'));
    expect(find.text('1:01'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-allowance-warning')), findsNothing);
    final requests = api.requests.length;
    await tester.pump(const Duration(hours: 3));
    expect(find.text('1:01'), findsOneWidget);
    expect(api.requests.length, requests);
    api.call = {...api.call!, 'connectedMs': 599999};
    await state.refresh();
    await tester.pumpAndSettle();
    expect(find.text('0:01'), findsOneWidget);
    expect(find.text('Test call time limit approaching'), findsOneWidget);
  });

  testWidgets('zero allowance waits for the server and keeps End available',
      (tester) async {
    final (_, api) = await mountAllowance(tester, {
      ...callJson(state: 'connected'),
      'connectedMs': 60000,
      'maxDurationSeconds': 60,
      'durationLimitReason': 'test_credit_balance'
    });
    await revealAllowance(tester, find.text('Call allowance exhausted'));
    expect(find.text('0:00'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    expect(api.requests.where((r) => (r['path'] as String).endsWith('/end')),
        isEmpty);
    await revealAllowance(tester, find.text('Report or block'));
    await tester.tap(find.text('Report or block'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await revealAllowance(tester, find.text('End call'));
    await tester.tap(find.text('End call'));
    await tester.pumpAndSettle();
    expect(
        api.requests.where((r) =>
            r['method'] == 'POST' && (r['path'] as String).endsWith('/end')),
        hasLength(1));
  });

  for (final video in [false, true]) {
    testWidgets(
        'frozen ${video ? 'video' : 'audio'} price is taken from the call',
        (tester) async {
      final frozenCoins = video ? 150 : 75;
      await mountAllowance(tester, {
        ...callJson(state: 'connected', video: video),
        'rate': {
          ...rateJson(video: video),
          'coinsPerMinute': frozenCoins,
          'microcreditsPerSecond': frozenCoins * 1000,
        }
      });
      // The fake current rate endpoint still offers 60/120; this synthetic
      // call snapshot retains its own earlier price.
      await revealAllowance(
          tester,
          find.text(
              '${video ? 'Video' : 'Audio'} · $frozenCoins test coins / minute'));
    });
  }

  testWidgets(
      'reconnect and offline keep last confirmed values without a grace countdown',
      (tester) async {
    final (state, api) = await mountAllowance(tester, {
      ...callJson(state: 'reconnecting'),
      'connectedMs': 40000,
      'chargeMicrocredits': 0,
      'maxDurationSeconds': 60,
    });
    await revealAllowance(
        tester, find.textContaining('Recovery time is limited'));
    expect(find.text('0:20'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('0:20'), findsOneWidget);
    expect(find.textContaining('45'), findsNothing);
    api.snapshotFailure = const ApiFailure('OFFLINE', 'Synthetic offline');
    await state.refresh();
    await tester.pumpAndSettle();
    await revealAllowance(tester, find.text('Confirmed call time remaining'));
    expect(find.text('0:20'), findsOneWidget);
    expect(api.requests.where((r) => (r['path'] as String).endsWith('/end')),
        isEmpty);
    api.snapshotFailure = null;
    api.call = {
      ...api.call!,
      'state': 'connected',
      'connectedMs': 41000,
      'chargeMicrocredits': 3600000
    };
    await state.refresh();
    await tester.pumpAndSettle();
    expect(find.text('0:19'), findsOneWidget);
    expect(find.textContaining('Recovery time is limited'), findsNothing);
  });

  testWidgets('Listener sees server earnings beside the same time allocation',
      (tester) async {
    await mountAllowance(
        tester,
        {
          ...callJson(state: 'connected'),
          'earningPaise': 1234,
          'connectedMs': 40000,
          'maxDurationSeconds': 60,
        },
        listener: true);
    await revealAllowance(
        tester, find.text('Customer rate: Audio · 60 test coins / minute'));
    await revealAllowance(tester, find.text('Test earnings: ₹12.34'));
    expect(find.textContaining('Test coins charged:'), findsNothing);
    await revealAllowance(tester, find.text('Confirmed call time remaining'));
    expect(find.text('0:20'), findsOneWidget);
  });

  for (final locale in ['en', 'ta']) {
    for (final video in [false, true]) {
      testWidgets(
          '$locale ${video ? 'video' : 'audio'} at 2x text keeps controls reachable',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        await mountAllowance(
            tester,
            {
              ...callJson(state: 'connected', video: video),
              'connectedMs': 550000,
              'maxDurationSeconds': 600,
              'durationLimitReason': 'test_duration_cap'
            },
            locale: locale,
            listener: locale == 'ta');
        await revealAllowance(
            tester,
            find.text(locale == 'ta'
                ? 'உறுதிப்படுத்தப்பட்ட மீதமுள்ள அழைப்பு நேரம்'
                : 'Confirmed call time remaining'));
        expect(find.text('0:50'), findsOneWidget);
        await revealAllowance(
            tester, find.text(locale == 'ta' ? 'அழைப்பை முடி' : 'End call'));
        await revealAllowance(
            tester,
            find.text(
                locale == 'ta' ? 'புகாரளி அல்லது தடு' : 'Report or block'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
