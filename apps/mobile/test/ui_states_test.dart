import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/screens.dart';
import 'fakes.dart';

Future<AppController> mountApp(WidgetTester tester,
    {FakeApi? api,
    MemoryStore? store,
    String path = '/home',
    String locale = 'en',
    bool initializeBeforeMount = true}) async {
  final session = store ?? MemoryStore();
  session.values.addAll({
    'token': 'existing-session',
    'lastPath': path,
    'locale': locale,
  });
  final controller = AppController(
      api: api ?? FakeApi(),
      store: session,
      audio: FakeAudio(),
      startTimers: false);
  if (initializeBeforeMount) await controller.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
      child: const NightShiftApp()));
  if (!initializeBeforeMount) await controller.initialize();
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('pending initial history is loading, not empty', (tester) async {
    final pending = Completer<Json>();
    final api = FakeApi()
      ..interceptor = (method, path, body) async =>
          method == 'GET' && path == '/calls' ? pending.future : null;
    await mountApp(tester, api: api);
    await tester.tap(find.text('Recents'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loading calls…'), findsOneWidget);
    expect(find.text('No completed calls yet'), findsNothing);
    pending.complete({'items': <Json>[]});
    await tester.pumpAndSettle();
    expect(find.text('Loading calls…'), findsNothing);
    expect(find.text('No completed calls yet'), findsOneWidget);
  });

  testWidgets('history offline retry reloads calls, not snapshot',
      (tester) async {
    var fail = true;
    final api = FakeApi()
      ..historyItems = [callJson(state: 'ended')]
      ..interceptor = (method, path, body) async {
        if (method == 'GET' && path == '/calls' && fail) {
          throw const ApiFailure('OFFLINE', 'Raw server text must not appear',
              requestId: 'request-example');
        }
        return null;
      };
    await mountApp(tester, api: api);
    await tester.tap(find.text('Recents'));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
    expect(find.text('No completed calls yet'), findsNothing);
    expect(find.text('Raw server text must not appear'), findsNothing);
    expect(find.text('Reference: request-example'), findsOneWidget);
    final snapshots = api.requests
        .where((request) => (request['path'] as String).startsWith('/snapshot'))
        .length;
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Call details'));
    await tester.pumpAndSettle();
    expect(find.text('Call ID: call-id'), findsOneWidget);
    expect(find.text('Connection unavailable'), findsNothing);
    expect(
        api.requests.where((request) => request['path'] == '/calls').length, 2);
    expect(
        api.requests
            .where((request) =>
                (request['path'] as String).startsWith('/snapshot'))
            .length,
        snapshots);
  });

  testWidgets('failed earlier page keeps rows and retries the same cursor',
      (tester) async {
    var fail = true;
    final api = FakeApi()
      ..interceptor = (method, path, body) async {
        if (method == 'GET' && path == '/calls') {
          return {
            'items': [callJson(state: 'ended')],
            'nextCursor': 'older-page'
          };
        }
        if (path == '/calls?cursor=older-page') {
          if (fail) throw const ApiFailure('OFFLINE', 'Offline');
          return {
            'items': [
              {...callJson(state: 'ended'), 'id': 'older-call'}
            ],
          };
        }
        return null;
      };
    final controller = await mountApp(tester, api: api, path: '/history');
    await tester.scrollUntilVisible(find.text('Load earlier calls'), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load earlier calls'));
    await tester.pumpAndSettle();
    expect(controller.history.map((call) => call.id), ['call-id']);
    await tester.scrollUntilVisible(find.text('Retry'), -250,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
        controller.history.map((call) => call.id), ['call-id', 'older-call']);
    expect(
        api.requests
            .where((request) => request['path'] == '/calls?cursor=older-page')
            .length,
        2);
    expect(
        api.requests.where((request) => request['path'] == '/calls').length, 1);
  });

  for (final beforeMount in [true, false]) {
    for (final path in ['/history', '/profile']) {
      testWidgets(
          'restores $path with initialization before mount $beforeMount',
          (tester) async {
        final state = await mountApp(tester,
            path: path, initializeBeforeMount: beforeMount);
        final container = ProviderScope.containerOf(
            tester.element(find.byType(NightShiftApp)));
        expect(
            container
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            path);
        expect(state.isListener, isFalse);
        if (path == '/history') {
          expect(find.text('Your conversations'), findsOneWidget);
        } else {
          final profile = find.byType(ProfileScreen);
          expect(profile, findsOneWidget);
          expect(
              find.descendant(
                  of: profile, matching: find.text(state.user!.name)),
              findsOneWidget);
          expect(find.descendant(of: profile, matching: find.text('Customer')),
              findsOneWidget);
          final edit = find.descendant(
              of: profile, matching: find.byTooltip('Edit profile'));
          expect(edit.hitTestable(), findsOneWidget);
          expect(
              tester
                  .widget<IconButton>(find.ancestor(
                      of: edit, matching: find.byType(IconButton)))
                  .onPressed,
              isNotNull);
        }
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            path == '/history' ? 1 : 2);
      });
    }
  }

  testWidgets('invalid saved route restores Discover', (tester) async {
    await mountApp(tester, path: '/not-a-destination');
    expect(find.text('Who would you like to talk to?'), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
  });

  testWidgets('mode switch from Profile opens and persists Availability',
      (tester) async {
    final api = FakeApi()..user = userJson(approved: true);
    final store = MemoryStore();
    final state =
        await mountApp(tester, api: api, store: store, path: '/profile');
    await tester.tap(find.text('Switch to Listener'));
    await tester.pumpAndSettle();
    expect(state.isListener, isTrue);
    expect(find.text('Standby · Offline'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    expect(store.values['lastPath'], '/home');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
  });

  testWidgets(
      'failed first snapshot does not invent empty directory or balance',
      (tester) async {
    final api = FakeApi()
      ..snapshotFailure = const ApiFailure('OFFLINE', 'Raw offline text');
    final state = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false);
    await state.initialize();
    await state.login('http://localhost:3000', 'customer', 'key');
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsNothing);
    expect(find.text('Your test credits'), findsNothing);
    api.snapshotFailure = null;
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(find.text('No listeners match this filter'), findsOneWidget);
    expect(find.text('Your test credits'), findsOneWidget);
  });

  testWidgets(
      'listener call button names its recipient and has accessible target',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = FakeApi()
      ..directory = [
        {
          'id': 'listener-id',
          'displayName': 'Test Listener',
          'languages': ['ta'],
          'available': true,
        }
      ];
    await mountApp(tester, api: api);
    await tester.ensureVisible(find.text('Call'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Call Test Listener'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
      'dismissed first snapshot failure still needs an explicit refresh',
      (tester) async {
    final api = FakeApi()
      ..snapshotFailure =
          const ApiFailure('INVALID_RESPONSE', 'Internal detail');
    final state = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false);
    await state.initialize();
    await state.login('http://localhost:3000', 'customer', 'key');
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Connect to see availability'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsNothing);
    expect(find.text('Your test credits'), findsNothing);
    api.snapshotFailure = null;
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Your test credits'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsOneWidget);
  });

  testWidgets('first snapshot has a named loading state before data arrives',
      (tester) async {
    final pending = Completer<Json>();
    final api = FakeApi()
      ..interceptor = (method, path, body) async =>
          path.startsWith('/snapshot') ? pending.future : null;
    final state = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false);
    await state.initialize();
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    final login = state.login('http://localhost:3000', 'customer', 'key');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loading availability…'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsNothing);
    expect(find.text('Your test credits'), findsNothing);
    pending.completeError(const ApiFailure('OFFLINE', 'Network unavailable'));
    await login;
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
    expect(find.text('Loading availability…'), findsNothing);
  });

  testWidgets('busy sign-in keeps a readable progress label', (tester) async {
    final state = AppController(
        api: FakeApi(),
        store: MemoryStore(),
        audio: FakeAudio(),
        startTimers: false);
    await state.initialize();
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    final pending = Completer<void>();
    final operation = state.perform(() => pending.future);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Signing in…'), 300,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Signing in…'), findsOneWidget);
    pending.complete();
    await operation;
    await tester.pumpAndSettle();
    expect(find.text('Continue to NightShift'), findsOneWidget);
  });

  for (final listener in [false, true]) {
    testWidgets(
        'Tamil at 2x text fits a narrow phone in ${listener ? 'Listener' : 'Customer'} mode',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });
      final api = FakeApi()
        ..user = userJson(listener: listener, approved: listener)
        ..historyItems = [callJson(state: 'ended')];
      await mountApp(tester, api: api, locale: 'ta');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(listener ? 'வருமானம்' : 'சமீபத்தில்'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('சுயவிவரம்'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tamil error and call end reason never expose raw codes',
      (tester) async {
    final api = FakeApi()
      ..historyItems = [
        {...callJson(state: 'ended'), 'reason': 'connection_timeout'}
      ];
    await mountApp(tester, api: api, path: '/history', locale: 'ta');
    await tester.tap(find.byTooltip('அழைப்பு விவரங்கள்'));
    await tester.pumpAndSettle();
    expect(find.text('முடிவு காரணம்: இணைப்பு நேரம் முடிந்தது'), findsOneWidget);
    expect(find.textContaining('connection_timeout'), findsNothing);
    api.interceptor = (method, path, body) async {
      if (method == 'GET' && path == '/calls') {
        throw const ApiFailure('OFFLINE', 'Raw English provider error');
      }
      return null;
    };
    final state =
        ProviderScope.containerOf(tester.element(find.byType(NightShiftApp)))
            .read(appControllerProvider);
    await state.loadHistory();
    await tester.pumpAndSettle();
    expect(find.text('இணைப்பு கிடைக்கவில்லை'), findsOneWidget);
    expect(find.text('Raw English provider error'), findsNothing);
    expect(find.text('முடிந்த அழைப்புகள் இன்னும் இல்லை'), findsNothing);
  });
}
