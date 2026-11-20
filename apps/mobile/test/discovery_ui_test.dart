import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/discovery.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';
import 'discovery_state_test.dart' show FakeEvents, member;

Future<(AppController, FakeApi, FakeEvents)> mountDirectory(WidgetTester tester,
    {FakeApi? api, String locale = 'en', FakeAudio? audio}) async {
  final service = api ??
      (FakeApi()
        ..directory = [
          {...member('listener-id'), 'videoRate': rateJson(video: true)}
        ]);
  final events = FakeEvents();
  final controller = AppController(
      api: service,
      store: MemoryStore()..values.addAll({'token': 'saved', 'locale': locale}),
      audio: audio ?? FakeVideo(),
      directoryEvents: events,
      startTimers: false);
  await controller.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => controller)],
      child: const NightShiftApp()));
  await tester.pumpAndSettle();
  return (controller, service, events);
}

Future<void> reveal(WidgetTester tester, Finder finder,
    {double delta = 240}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, delta,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void busy(FakeEvents events) => events.update!({
      'viewEpoch': 'fixture-view',
      'language': 'ta',
      'items': [
        {
          ...member('listener-id', available: false, busy: true),
          'videoRate': rateJson(video: true)
        }
      ],
      'removedIds': <String>[],
      'serverTime': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 1))
          .toIso8601String()
    });

class PermissionGate extends FakeAudio {
  final gate = Completer<void>();
  @override
  Future<void> checkPermission() => gate.future;
}

void main() {
  testWidgets(
      'busy socket status disables open audio confirmation without moving card',
      (tester) async {
    final (state, api, events) = await mountDirectory(tester);
    await reveal(tester, find.text('Call'));
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    final before =
        List<String>.of(state.discovery.page(DirectoryKind.discover).ids);
    busy(events);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start audio call'))
            .onPressed,
        isNull);
    expect(state.discovery.page(DirectoryKind.discover).ids, before);
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Busy'), findsOneWidget);
  });

  testWidgets('busy update disables consented video confirmation',
      (tester) async {
    final (_, api, events) = await mountDirectory(tester);
    await reveal(tester, find.text('Video call'));
    await tester.tap(find.text('Video call'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Preview camera'));
    await tester.tap(find.text('Preview camera'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    busy(events);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start video call'))
            .onPressed,
        isNull);
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
  });

  testWidgets('changing account invalidates an open audio confirmation',
      (tester) async {
    final (state, api, _) = await mountDirectory(tester);
    await reveal(tester, find.text('Call'));
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    state.user = UserProfile.fromJson({...userJson(), 'id': 'another-owner'});
    state.clearError();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start audio call'))
            .onPressed,
        isNull);
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
  });

  testWidgets('loading and failed first page never claim an empty directory',
      (tester) async {
    final pending = Completer<Json>();
    final api = FakeApi()
      ..interceptor = (m, p, b) async =>
          p.startsWith('/listeners?') ? pending.future : null;
    final events = FakeEvents();
    final state = AppController(
        api: api,
        store: MemoryStore()..values['token'] = 'saved',
        audio: FakeAudio(),
        directoryEvents: events,
        startTimers: false);
    await state.initialize();
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => state)],
        child: const NightShiftApp()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Loading listeners…'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsNothing);
    pending.completeError(const ApiFailure('OFFLINE', 'private server error'));
    await tester.pumpAndSettle();
    expect(find.text('Could not update availability'), findsOneWidget);
    expect(find.text('No listeners match this filter'), findsNothing);
    expect(find.text('private server error'), findsNothing);
  });

  testWidgets(
      'Favorites is inside Recents and excluded counterpart remains unavailable',
      (tester) async {
    final api = FakeApi()
      ..historyItems = [callJson(state: 'ended')]
      ..directory = [member('listener-id', favorite: true)];
    final (state, _, events) = await mountDirectory(tester, api: api);
    await tester.tap(find.text('Recents'));
    await tester.pumpAndSettle();
    expect(find.text('Current availability: Available now'), findsOneWidget);
    expect(state.history.single.state, 'ended');
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Call'));
    events.update!({
      'viewEpoch': 'fixture-view',
      'language': 'ta',
      'items': <Json>[],
      'removedIds': ['listener-id'],
      'serverTime': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 1))
          .toIso8601String()
    });
    await tester.pumpAndSettle();
    expect(state.discovery.items(DirectoryKind.favorites), isEmpty);
    expect(state.discovery.callable('listener-id'), false);
    expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        3);
  });

  testWidgets(
      'Tamil Favorites at 2x text fits and exposes truthful limited-view copy',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    final (state, _, _) = await mountDirectory(tester, locale: 'ta');
    await tester.tap(find.text('சமீபத்தில்'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('விருப்பமானவர்கள்'));
    await tester.pumpAndSettle();
    state.discovery.page(DirectoryKind.favorites).truncated = true;
    state.clearError();
    await tester.pumpAndSettle();
    await reveal(
        tester,
        find.text(
            'பட்டியலின் ஒரு பகுதி மட்டுமே காட்டப்படுகிறது. கிடைக்கும் நிலை முழுமையாக இல்லாமல் இருக்கலாம்.'));
    expect(tester.takeException(), isNull);
  });

  test('permission completion after account switch sends no reservation',
      () async {
    final api = FakeApi()..token = 'old';
    final audio = PermissionGate();
    final state = AppController(
        api: api, store: MemoryStore(), audio: audio, startTimers: false)
      ..user = UserProfile.fromJson(userJson());
    final call =
        state.startCall(ListenerProfile.fromJson(member('listener-id')));
    await Future<void>.delayed(Duration.zero);
    state.user = UserProfile.fromJson({...userJson(), 'id': 'new-owner'});
    api.token = 'new';
    audio.gate.complete();
    await call;
    expect(api.requests.where((r) => r['path'] == '/calls'), isEmpty);
    state.dispose();
  });

  test('invalid persisted discovery language normalizes before first query',
      () async {
    final state = AppController(
        api: FakeApi(),
        store: MemoryStore()
          ..values.addAll({'token': 'token', 'language': 'invalid'}),
        audio: FakeAudio(),
        startTimers: false);
    await state.initialize();
    expect(state.language, 'ta');
    expect(state.discovery.language, 'ta');
    state.dispose();
  });
  test('blocking an old conversation cannot mutate the replacement account',
      () async {
    final api = FakeApi()..token = 'a';
    final audio = LeaveGate();
    final state = AppController(
        api: api, store: MemoryStore(), audio: audio, startTimers: false)
      ..user = UserProfile.fromJson(userJson())
      ..activeCall = CallSession.fromJson(callJson(state: 'active'));
    final action =
        state.submitSafety(state.activeCall!, 'test reason', block: true);
    await Future<void>.delayed(Duration.zero);
    state.user = UserProfile.fromJson({...userJson(), 'id': 'replacement'});
    api.token = 'b';
    audio.gate.complete();
    await action;
    expect(
        api.requests.where((r) =>
            (r['path'] as String).startsWith('/blocks/') ||
            r['path'] == '/reports'),
        isEmpty);
    state.dispose();
  });
}

class LeaveGate extends FakeAudio {
  final gate = Completer<void>();
  @override
  Future<void> leave() => gate.future;
}
