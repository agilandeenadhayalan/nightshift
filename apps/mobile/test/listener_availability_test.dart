import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'discovery_state_test.dart' show member;
import 'discovery_ui_test.dart' show mountDirectory, reveal;
import 'fakes.dart';

Json listenerUser(
        {bool online = false, bool audio = true, bool video = true}) =>
    {
      ...userJson(listener: true, approved: true, online: online),
      'availability': {
        'online': online,
        'audioEnabled': audio,
        'videoEnabled': video
      },
    };

Future<AppController> availabilityController(FakeApi api) async {
  final app = AppController(
      api: api,
      store: MemoryStore()..values['token'] = 'saved',
      audio: FakeVideo(),
      startTimers: false);
  await app.initialize();
  await app.refreshListenerAvailability();
  return app;
}

List<Json> writes(FakeApi api) => api.requests
    .where((r) => r['path'] == '/me/availability')
    .map((r) => r['body'] as Json)
    .toList();

Future<void> microtasks() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const audioSwitch = ValueKey('listener-audio-availability');
const videoSwitch = ValueKey('listener-video-availability');

void main() {
  test('media flags survive favorite copies and legacy cards remain compatible',
      () {
    final videoOnly = ListenerProfile.fromJson({
      ...member('video-only'),
      'audioAvailable': false,
      'videoAvailable': true,
      'videoRate': rateJson(video: true),
    }).withFavorite(true);
    expect(videoOnly.acceptsMedia(), isFalse);
    expect(videoOnly.acceptsMedia(video: true), isTrue);
    expect(videoOnly.favorite, isTrue);
    expect(ListenerProfile.fromJson(member('legacy')).acceptsMedia(), isTrue);
    expect(() => ListenerAvailability.fromJson({'online': true}),
        throwsFormatException);
  });

  test(
      'each switch saves atomic channels; offline never revives dormant preference',
      () async {
    final api = FakeApi()..user = listenerUser();
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    expect(app.listenerAudioEnabled, isFalse);
    expect(app.listenerVideoEnabled, isFalse);
    await app.setMediaAvailability(audio: true);
    await app.setMediaAvailability(video: true);
    await app.setMediaAvailability(audio: false);
    await app.setMediaAvailability(video: false);
    expect(writes(api), [
      {'online': true, 'audioEnabled': true, 'videoEnabled': false},
      {'online': true, 'audioEnabled': true, 'videoEnabled': true},
      {'online': true, 'audioEnabled': false, 'videoEnabled': true},
      {'online': false, 'audioEnabled': false, 'videoEnabled': false},
    ]);
    await app.setMediaAvailability(video: true);
    final restored = await availabilityController(api);
    addTearDown(restored.dispose);
    expect(restored.listenerAudioEnabled, isFalse);
    expect(restored.listenerVideoEnabled, isTrue);
    expect(restored.user!.availability!.online, isTrue);
  });

  test('unconfirmed and failed save retain server state and release controls',
      () async {
    final api = FakeApi()..user = listenerUser(online: true, video: false);
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    final gate = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' ? gate.future : null;
    final update = app.setMediaAvailability(audio: false);
    await microtasks();
    expect(app.listenerAudioEnabled, isTrue);
    expect(app.availabilityUpdating, isTrue);
    expect(app.canSetMediaAvailability, isFalse);
    await app.setMediaAvailability(video: true);
    expect(writes(api), hasLength(1));
    gate.completeError(
        const ApiFailure('AVAILABILITY_FAILED', 'Retry availability.'));
    await update;
    expect(app.listenerAudioEnabled, isTrue);
    expect(app.listenerVideoEnabled, isFalse);
    expect(app.availabilityUpdating, isFalse);
    expect(app.canSetMediaAvailability, isTrue);
    expect(app.errorCode, 'AVAILABILITY_FAILED');
  });

  for (final fails in [false, true]) {
    test(
        'late availability ${fails ? 'failure' : 'response'} cannot affect replacement owner',
        () async {
      final api = FakeApi()..user = listenerUser();
      final app = await availabilityController(api);
      addTearDown(app.dispose);
      final gate = Completer<Json>();
      api.interceptor = (method, path, body) async =>
          path == '/me/availability' ? gate.future : null;
      final update = app.setMediaAvailability(audio: true);
      await microtasks();
      api.user = {...userJson(), 'id': 'replacement'};
      app.user = UserProfile.fromJson(api.user);
      api.token = 'replacement-token';
      if (fails) {
        gate.completeError(const ApiFailure('OFFLINE', 'Old network failure.'));
      } else {
        gate.complete(listenerUser(online: true, video: false));
      }
      await update;
      expect(app.user!.id, 'replacement');
      expect(app.offline, isFalse);
      expect(app.errorCode, isNull);
      expect(app.busy, isFalse);
      expect(app.availabilityUpdating, isFalse);
    });
  }

  test('capability off clamps dormant video while audio remains usable',
      () async {
    final api = FakeApi()
      ..user = listenerUser(online: true, audio: false)
      ..videoEnabled = false;
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    expect(app.listenerVideoSupported, isFalse);
    expect(app.listenerVideoEnabled, isFalse);
    await app.setMediaAvailability(audio: true);
    expect(writes(api).single,
        {'online': true, 'audioEnabled': true, 'videoEnabled': false});
    await app.setMediaAvailability(video: true);
    expect(writes(api), hasLength(1));
    expect(app.errorCode, 'VIDEO_UNAVAILABLE');
    api.videoEnabled = true;
    await app.refreshListenerAvailability();
    expect(app.listenerVideoSupported, isTrue);
  });

  test(
      'background withdrawal follows a dispatched channel save and preserves preferences',
      () async {
    final api = FakeApi()..user = listenerUser();
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    final gate = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' && body?['online'] == true
            ? gate.future
            : null;
    final update = app.setMediaAvailability(audio: true);
    await microtasks();
    final background = app.setForeground(false);
    await microtasks();
    expect(writes(api), hasLength(1));
    api.user = listenerUser(online: true, video: false);
    gate.complete(api.user);
    await Future.wait([update, background]);
    expect(writes(api), [
      {'online': true, 'audioEnabled': true, 'videoEnabled': false},
      {'online': false},
    ]);
    expect(app.user!.availability!.online, isFalse);
    expect(app.user!.availability!.audioEnabled, isTrue);
    expect(app.user!.availability!.videoEnabled, isFalse);
    expect(app.listenerAudioEnabled, isFalse);
    expect(app.busy, isFalse);
  });

  test('turning both channels off leaves an established call running',
      () async {
    final api = FakeApi()
      ..user = listenerUser(online: true)
      ..call = callJson(state: 'connected');
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    await app.setMediaAvailability(audio: false, video: false);
    expect(app.user!.availability!.online, isFalse);
    expect(app.activeCall!.id, 'call-id');
    expect(app.activeCall!.state, 'connected');
    expect(
        api.requests.where((r) => [
              '/calls/call-id/end',
              '/calls/call-id/cancel',
              '/calls/call-id/decline'
            ].contains(r['path'])),
        isEmpty);
  });

  test(
      'customers, unapproved listeners and offline state cannot change availability',
      () async {
    final api = FakeApi();
    final app = await availabilityController(api);
    addTearDown(app.dispose);
    await app.setMediaAvailability(audio: true);
    app.user = UserProfile.fromJson(userJson(listener: true));
    await app.setMediaAvailability(audio: true);
    app.user = UserProfile.fromJson(listenerUser());
    app.offline = true;
    await app.setMediaAvailability(audio: true);
    expect(writes(api), isEmpty);
  });

  testWidgets('live Listener switches show save progress and server rollback',
      (tester) async {
    final api = FakeApi()..user = listenerUser();
    final app = await availabilityController(api);
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => app)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    expect(find.text('Listener workspace'), findsOneWidget);
    expect(find.text('Who would you like to talk to?'), findsNothing);
    expect(find.text('Go online'), findsNothing);
    final gate = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' ? gate.future : null;
    await tester.tap(find.byKey(audioSwitch));
    await tester.pump();
    expect(find.text('Saving availability…'), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(audioSwitch)).onChanged, isNull);
    expect(tester.widget<Switch>(find.byKey(videoSwitch)).onChanged, isNull);
    gate.completeError(
        const ApiFailure('AVAILABILITY_FAILED', 'Retry availability.'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byKey(audioSwitch)).value, isFalse);
    expect(tester.widget<Switch>(find.byKey(audioSwitch)).onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamil Listener switches stay usable at 390x600 and 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = FakeApi()..user = listenerUser();
    final app = await availabilityController(api);
    await app.setLocale('ta');
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => app)],
        child: const NightShiftApp()));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(audioSwitch));
    await tester.tap(find.byKey(audioSwitch));
    await tester.pumpAndSettle();
    expect(app.listenerAudioEnabled, isTrue);
    await reveal(tester, find.byKey(videoSwitch));
    await tester.tap(find.byKey(videoSwitch));
    await tester.pumpAndSettle();
    expect(app.listenerVideoEnabled, isTrue);
    expect(writes(api).last,
        {'online': true, 'audioEnabled': true, 'videoEnabled': true});
    expect(tester.takeException(), isNull);
  });

  for (final audio in [true, false]) {
    testWidgets(
        'Customer card enables only ${audio ? 'audio' : 'video'} and opens its consent flow',
        (tester) async {
      final api = FakeApi()
        ..directory = [
          {
            ...member('listener-id'),
            'audioAvailable': audio,
            'videoAvailable': !audio,
            'videoRate': rateJson(video: true),
          }
        ];
      final (state, _, events) = await mountDirectory(tester, api: api);
      expect(find.text('Who would you like to talk to?'), findsOneWidget);
      expect(find.byKey(audioSwitch), findsNothing);
      await reveal(tester, find.text('Video call'));
      expect(
          tester
              .widget<ButtonStyleButton>(find.ancestor(
                  of: find.text('Call'),
                  matching:
                      find.byWidgetPredicate((w) => w is ButtonStyleButton)))
              .onPressed,
          audio ? isNotNull : isNull);
      expect(
          tester
              .widget<ButtonStyleButton>(find.ancestor(
                  of: find.text('Video call'),
                  matching:
                      find.byWidgetPredicate((w) => w is ButtonStyleButton)))
              .onPressed,
          audio ? isNull : isNotNull);
      await tester.tap(find.text(audio ? 'Call' : 'Video call'));
      await tester.pumpAndSettle();
      expect(find.text(audio ? 'Start audio call' : 'Preview camera'),
          findsOneWidget);
      // A live per-channel update must also revoke an already open confirmation.
      events.update!({
        'viewEpoch': 'fixture-view',
        'language': 'ta',
        'items': [
          {
            ...member('listener-id'),
            'audioAvailable': false,
            'videoAvailable': false,
            'videoRate': rateJson(video: true),
          }
        ],
        'removedIds': <String>[],
        'serverTime': DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 1))
            .toIso8601String()
      });
      await tester.pumpAndSettle();
      expect(
          state.canCallListener(state.discovery.lookup('listener-id')!,
              video: !audio),
          isFalse);
      if (audio) {
        expect(
            tester
                .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Start audio call'))
                .onPressed,
            isNull);
      }
      expect(
          api.requests
              .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
          isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
