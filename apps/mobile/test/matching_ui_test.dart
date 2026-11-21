import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/matching_screen.dart';
import 'fakes.dart';
import 'matching_test.dart' show matchJson, matchCallId;

Future<(AppController, FakeApi)> mount(WidgetTester tester,
    {String locale = 'en', Json? request, bool fullApp = false}) async {
  final api = FakeApi()..token = 'synthetic';
  api.interceptor = (method, path, body) async {
    if (path == '/me/match') return {'request': request};
    if (path == '/matches') return request = matchJson();
    return null;
  };
  final state = AppController(
      api: api,
      store: MemoryStore()..values['token'] = 'saved',
      audio: FakeAudio(),
      startTimers: false);
  await state.initialize();
  state.locale = locale;
  await state.matching.open();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => state)],
      child: fullApp
          ? const NightShiftApp()
          : MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(locale == 'ta' ? 2 : 1)),
                  child: child!),
              home: const MatchingScreen())));
  await tester.pumpAndSettle();
  return (state, api);
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 220,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ended matched request requires a separate new-search action and fresh consent',
      (tester) async {
    final (state, api) =
        await mount(tester, request: matchJson(state: 'matched', attempts: 1));
    expect(state.hasCall, false);
    expect(find.text('Start audio search'), findsNothing);
    await reveal(tester, find.text('Review a new audio search'));
    await tester.tap(find.text('Review a new audio search'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Start audio search'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start audio search'))
            .onPressed,
        isNull);
    expect(api.requests.where((r) => r['path'] == '/matches'), isEmpty);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Start audio search'));
    await tester.tap(find.text('Start audio search'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r['path'] == '/matches'), hasLength(1));
  });

  testWidgets('removed speaking language resets selection and consent safely',
      (tester) async {
    final (state, api) = await mount(tester);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    api.user = {
      ...api.user,
      'languages': ['en']
    };
    await state.refresh();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byType(CheckboxListTile));
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
    await reveal(tester, find.text('Start audio search'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start audio search'))
            .onPressed,
        isNull);
    expect(api.requests.where((r) => r['path'] == '/matches'), isEmpty);
  });

  testWidgets(
      'search discloses bound and rate, requires explicit consent and permits Cancel',
      (tester) async {
    final (state, api) = await mount(tester);
    expect(find.textContaining('90 seconds total'), findsOneWidget);
    expect(state.matching.rate?.id, 'test-audio-v1');
    var start = find.widgetWithText(FilledButton, 'Start audio search');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r['path'] == '/matches'), hasLength(1));
    expect(find.text('Attempt 0 of 3'), findsNothing);
    expect(find.textContaining('Attempt 0 of 3'), findsOneWidget);
    expect(find.text('Cancel search'), findsOneWidget);
    expect(state.matching.blocked, true);
  });

  testWidgets(
      'ringing matching route retains search Cancel and blocks direct calls/mode switch',
      (tester) async {
    final (state, api) = await mount(tester,
        request: matchJson(state: 'ringing', attempts: 1), fullApp: true);
    api.call = {...callJson(), 'id': matchCallId};
    await state.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(MatchingScreen), findsOneWidget);
    expect(find.text('Cancel search'), findsOneWidget);
    expect(state.canSwitch, false);
    final listener = ListenerProfile.fromJson(directoryCard({
      'id': 'listener-id',
      'displayName': 'Listener',
      'languages': ['ta'],
      'available': true
    }));
    expect(state.canCallListener(listener), false);
    await state.setForeground(false);
    expect(api.requests.where((r) => r['path'] == '/calls/$matchCallId/cancel'),
        isEmpty);
    expect(api.requests.where((r) => r['path'] == '/matches'), isEmpty);
  });

  testWidgets(
      'accepted call hands off existing call screen and cancel cannot end it',
      (tester) async {
    final (state, api) = await mount(tester,
        request: matchJson(state: 'ringing', attempts: 1), fullApp: true);
    api.interceptor = (method, path, body) async {
      if (path.endsWith('/cancel') && path.startsWith('/matches/')) {
        api.call = {
          ...callJson(state: 'connecting', version: 2),
          'id': matchCallId
        };
        return matchJson(state: 'matched', attempts: 1, version: 2);
      }
      if (path == '/me/match') {
        return {
          'request': matchJson(state: 'matched', attempts: 1, version: 2)
        };
      }
      return null;
    };
    await tester.tap(find.text('Cancel search'));
    await tester.pumpAndSettle();
    expect(state.activeCall?.id, matchCallId);
    expect(find.byType(MatchingScreen), findsNothing);
    expect(api.requests.where((r) => r['path'] == '/calls/$matchCallId/end'),
        isEmpty);
  });

  testWidgets('lost response offers recovery without a duplicate search',
      (tester) async {
    final (state, api) = await mount(tester);
    api.interceptor = (method, path, body) async {
      if (path == '/matches') throw const ApiFailure('OFFLINE', 'unknown');
      if (path == '/me/match') return {'request': matchJson()};
      return null;
    };
    await state.startMatching(language: 'ta', consent: true);
    await tester.pumpAndSettle();
    expect(find.text('Request outcome not yet confirmed'), findsOneWidget);
    await reveal(tester, find.text('Check search status'));
    await tester.tap(find.text('Check search status'));
    await tester.pumpAndSettle();
    expect(find.text('Request outcome not yet confirmed'), findsNothing);
    expect(api.requests.where((r) => r['path'] == '/matches'), hasLength(1));
  });

  testWidgets(
      'Tamil at 360px and 200 percent keeps consent/start/status/cancel usable',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (_, api) = await mount(tester, locale: 'ta');
    expect(tester.takeException(), isNull);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final start = find.text('ஆடியோ தேடலைத் தொடங்கு');
    await reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('தேடலை ரத்து செய்'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'தேடலை ரத்து செய்'))
            .onPressed,
        isNotNull);
    expect(api.requests.where((r) => r['path'] == '/matches'), hasLength(1));
  });

  testWidgets(
      'permission completion after account change cannot create a search',
      (tester) async {
    final permission = Completer<void>();
    final api = FakeApi()..token = 'synthetic';
    final state = AppController(
        api: api,
        store: MemoryStore(),
        audio: _Permission(permission),
        startTimers: false)
      ..user = UserProfile.fromJson(userJson())
      ..snapshotLoaded = true;
    addTearDown(state.dispose);
    await state.matching.open();
    final operation = state.startMatching(language: 'ta', consent: true);
    await tester.pump();
    state.user = UserProfile.fromJson({...userJson(), 'id': 'replacement'});
    permission.complete();
    await operation;
    expect(api.requests.where((r) => r['path'] == '/matches'), isEmpty);
  });

  testWidgets(
      'closing and reopening consent while permission waits cannot use the old consent',
      (tester) async {
    final permission = Completer<void>();
    final api = FakeApi()..token = 'synthetic';
    final state = AppController(
        api: api,
        store: MemoryStore(),
        audio: _Permission(permission),
        startTimers: false)
      ..user = UserProfile.fromJson(userJson())
      ..snapshotLoaded = true;
    addTearDown(state.dispose);
    await state.matching.open();
    final operation = state.startMatching(language: 'ta', consent: true);
    await tester.pump();
    state.matching.dismiss();
    await state.matching.open();
    permission.complete();
    await operation;
    expect(api.requests.where((r) => r['path'] == '/matches'), isEmpty);
  });
}

class _Permission extends FakeAudio {
  _Permission(this.gate);
  final Completer<void> gate;
  @override
  Future<void> checkPermission() => gate.future;
}
