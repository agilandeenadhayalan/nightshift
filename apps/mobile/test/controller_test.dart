import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

void main() {
  late FakeApi api;
  late FakeAudio audio;
  late MemoryStore store;
  late AppController controller;
  setUp(() async {
    api = FakeApi();
    audio = FakeAudio();
    store = MemoryStore();
    controller =
        AppController(api: api, audio: audio, store: store, startTimers: false);
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test(
      'report and block stops current capture and targets only other participant',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    audio.ready = true;
    await controller.submitSafety(
        controller.activeCall!, 'Synthetic safety test',
        block: true);
    expect(audio.ready, isFalse);
    expect(controller.activeCall, isNull);
    expect(api.requests.any((r) => r['path'] == '/blocks/listener-id'), isTrue);
    final report = api.requests.singleWhere((r) => r['path'] == '/reports');
    expect((report['body'] as Json)['callId'], 'call-id');
    expect(report['key'], isNotNull);
  });

  test('history pages preserve stable IDs and deduplicate overlapping rows',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.interceptor = (method, path, body) async {
      if (path == '/calls') {
        return {
          'items': [callJson(state: 'ended')],
          'nextCursor': 'page-2'
        };
      }
      if (path == '/calls?cursor=page-2') {
        return {
          'items': [
            callJson(state: 'ended'),
            {...callJson(state: 'ended'), 'id': 'older-call'}
          ],
          'nextCursor': null
        };
      }
      return null;
    };
    await controller.loadHistory();
    expect(controller.historyCursor, 'page-2');
    await controller.loadHistory(append: true);
    expect(controller.history.map((c) => c.id), ['call-id', 'older-call']);
    expect(controller.historyCursor, isNull);
  });

  test('history grouping uses calendar day across midnight and month boundary',
      () {
    final now = DateTime(2026, 12, 1, 0, 5);
    expect(historyDay(DateTime(2026, 12, 1, 0, 1), now), 'today');
    expect(historyDay(DateTime(2026, 11, 30, 23, 59), now), 'yesterday');
    expect(historyDay(DateTime(2026, 11, 29, 23, 59), now), 'older');
    expect(historyDay(DateTime(2026, 12, 1, 0, 1).toUtc(), now), 'today');
  });

  test(
      'English selection persists the preference and queries English directory',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    await controller.setLanguage('en');
    expect(store.values['language'], 'en');
    expect(
        api.requests.any((r) => r['path'] == '/snapshot?language=en'), isTrue);
    expect(api.requests.any((r) => r['path'] == '/me/languages'), isFalse);
    expect(controller.user!.languages, ['ta', 'en']);
  });

  test('local hangup releases capture before a slow server acknowledges',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    audio.ready = true;
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path.endsWith('/end') ? response.future : null;
    final ending = controller.transition('end');
    await Future<void>.delayed(Duration.zero);
    expect(audio.ready, isFalse);
    expect(controller.endingLocally, isTrue);
    expect(store.values['abandonedCallId'], 'call-id');
    api.call = null;
    response.complete(callJson(state: 'ended'));
    await ending;
    expect(controller.activeCall, isNull);
  });

  test('stale version hangup reloads authoritative version and retries once',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    var rejected = false;
    api.interceptor = (method, path, body) async {
      if (path.endsWith('/end') && !rejected) {
        rejected = true;
        api.call = callJson(state: 'connected', version: 8);
        throw const ApiFailure('VERSION_CONFLICT', 'Retry', status: 409);
      }
      return null;
    };
    await controller.transition('end');
    final ends =
        api.requests.where((r) => r['path'] == '/calls/call-id/end').toList();
    expect(ends.map((r) => (r['body'] as Json)['expectedVersion']), [1, 8]);
    expect(controller.activeCall, isNull);
  });

  test('offline hangup persists intent and never rejoins an abandoned call',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final joins = audio.joinCount;
    api.interceptor = (method, path, body) async {
      if (path.endsWith('/end')) {
        throw const ApiFailure('OFFLINE', 'Unreachable');
      }
      return null;
    };
    await controller.transition('end');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(controller.endingLocally, isTrue);
    expect(audio.joinCount, joins);
    expect(audio.ready, isFalse);
    expect(store.values['abandonedCallId'], 'call-id');
  });

  test('snapshot started before hangup cannot resurrect the ended call',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final snapshot = Completer<Json>();
    final old = {
      'user': api.user,
      'activeCall': api.call,
      'listeners': [],
      'wallet': {'balanceMicrocredits': 600000000, 'heldMicrocredits': 0}
    };
    api.interceptor = (method, path, body) async =>
        path.startsWith('/snapshot') ? snapshot.future : null;
    final refresh = controller.refresh();
    await controller.transition('end');
    final joins = audio.joinCount;
    snapshot.complete(old);
    await refresh;
    await Future<void>.delayed(Duration.zero);
    expect(controller.activeCall, isNull);
    expect(audio.joinCount, joins);
  });

  test(
      'release startup ignores persisted debug token and never contacts API or audio',
      () async {
    final releaseApi = FakeApi();
    final releaseStore = MemoryStore()
      ..values['token'] = 'retained-debug-token';
    final releaseAudio = FakeAudio();
    final release = AppController(
        api: releaseApi,
        store: releaseStore,
        audio: releaseAudio,
        developmentEnabled: false);
    await release.initialize();
    expect(releaseApi.requests, isEmpty);
    expect(releaseApi.token, isNull);
    expect(releaseAudio.joinCount, 0);
    expect(release.user, isNull);
    release.dispose();
  });

  test(
      'dev access key is not persisted; token and canonical server user are restored',
      () async {
    await controller.login(
        'http://localhost:3000', 'customer', 'private-development-key');
    expect(store.values['token'], 'test-session-token');
    expect(store.values.values, isNot(contains('private-development-key')));
    expect(controller.user!.id, 'customer-id');
    expect(controller.user!.listenerApproved, isFalse);
    expect(controller.canSwitch, isFalse);
  });

  test('microphone denial cannot reserve or charge a call', () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    audio.denied = true;
    await controller.startCall(const ListenerProfile(
        id: 'listener-id',
        name: 'Test Listener',
        languages: ['ta'],
        available: true));
    expect(controller.error, 'Microphone denied');
    expect(
        api.requests
            .where((r) => r['path'] == '/calls' && r['method'] == 'POST'),
        isEmpty);
    expect(controller.activeCall, isNull);
  });

  test(
      'switching mode is blocked during reserved call even for approved listener',
      () async {
    api.user = userJson(approved: true);
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson();
    await controller.refresh();
    expect(controller.canSwitch, isFalse);
    await controller.switchMode();
    expect(api.requests.where((r) => r['path'] == '/me/mode'), isEmpty);
  });

  test('healthy media reports cannot be inferred from accept or HTTP success',
      () async {
    api.user = userJson(listener: true, approved: true);
    await controller.login('http://localhost:3000', 'listener', 'key');
    api.call = callJson();
    await controller.refresh();
    await controller.transition('accept');
    await Future<void>.delayed(Duration.zero);
    await controller.reportMedia();
    final reports = api.requests
        .where((r) => (r['path'] as String).endsWith('/media'))
        .toList();
    expect(reports, isNotEmpty);
    expect(reports.every((r) => (r['body'] as Json)['ready'] == false), isTrue);
    audio.ready = true;
    await controller.reportMedia();
    expect((api.requests.last['body'] as Json)['ready'], isTrue);
  });

  test('server ends call and releases microphone; shared history is refreshed',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final before = audio.leaveCount;
    api.call = null;
    api.historyItems = [callJson(state: 'ended')];
    await controller.refresh();
    expect(audio.leaveCount, greaterThan(before));
    expect(controller.activeCall, isNull);
    expect(controller.history.single.id, 'call-id');
    expect(controller.lastPath, '/history');
  });

  test('background stops audio, ends session, and withdraws availability',
      () async {
    api.user = userJson(listener: true, approved: true, online: true);
    await controller.login('http://localhost:3000', 'listener', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.setForeground(false);
    expect(audio.ready, isFalse);
    expect(controller.activeCall, isNull);
    expect(api.requests.any((r) => r['path'] == '/calls/call-id/end'), isTrue);
    expect(
        api.requests.any((r) =>
            r['path'] == '/me/availability' &&
            (r['body'] as Json)['online'] == false),
        isTrue);
  });

  test('missing provider credentials end safely without claiming media joined',
      () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.rtcFailure = const ApiFailure(
        'RTC_UNAVAILABLE', 'Configure the RTC provider',
        status: 503);
    api.call = callJson(state: 'connecting');
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(audio.joinCount, 0);
    expect(controller.error, 'Configure the RTC provider');
    expect(controller.activeCall, isNull);
  });

  test('revoked session removes stored token and media immediately', () async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.snapshotFailure =
        const ApiFailure('UNAUTHORIZED', 'Session expired', status: 401);
    await controller.refresh();
    expect(controller.user, isNull);
    expect(api.token, isNull);
    expect(store.values.containsKey('token'), isFalse);
    expect(audio.ready, isFalse);
  });

  test('busy listener remains disabled despite online presence', () {
    final listener = ListenerProfile.fromJson({
      'id': 'id',
      'displayName': 'Test',
      'languages': ['ta'],
      'online': true,
      'available': false,
      'busy': true
    });
    expect(listener.available, isFalse);
  });
}
