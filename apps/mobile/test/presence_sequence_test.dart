import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<bool> availabilityRequests(FakeApi api) => api.requests
    .where((request) => request['path'] == '/me/availability')
    .map((request) => (request['body'] as Json)['online'] as bool)
    .toList();

class GatedLeaveAudio extends FakeAudio {
  Completer<void>? pendingLeave;
  @override
  Future<void> leave() async {
    await pendingLeave?.future;
    await super.leave();
  }
}

void main() {
  late FakeApi api;
  late AppController app;
  late GatedLeaveAudio audio;
  setUp(() async {
    api = FakeApi()..user = userJson(listener: true, approved: true);
    audio = GatedLeaveAudio();
    app = AppController(
        api: api, store: MemoryStore(), audio: audio, startTimers: false);
    await app.initialize();
    await app.login('http://localhost:3000', 'listener', 'fixture-key');
    api.requests.clear();
  });
  tearDown(() => app.dispose());

  for (final replacement in [false, true]) {
    test(
        'old background teardown cannot end a new ${replacement ? 'owner' : 'same-owner'} call',
        () async {
      final leave = Completer<void>();
      audio.pendingLeave = leave;
      final background = app.setForeground(false);
      await settle();
      await app.setForeground(true);
      if (replacement) {
        api.user = userJson();
        app.user = UserProfile.fromJson(api.user);
        api.token = 'replacement-token';
      }
      api.call = callJson(state: 'connected');
      app.activeCall = CallSession.fromJson(api.call!);
      leave.complete();
      await background;
      expect(app.activeCall?.id, 'call-id');
      expect(
          api.requests
              .where((request) => request['path'] == '/calls/call-id/end'),
          isEmpty);
    });
  }

  for (final replacement in [false, true]) {
    test(
        'late mode response cannot restore ${replacement ? 'a replaced' : 'a revoked'} account',
        () async {
      final response = Completer<Json>();
      final oldUser = {...api.user, 'mode': 'customer'};
      api.interceptor = (method, path, body) async =>
          path == '/me/mode' ? response.future : null;
      final mode = app.switchMode();
      await settle();
      api.snapshotFailure =
          const ApiFailure('SESSION_REVOKED', 'Sign in again.', status: 401);
      await app.refresh();
      expect(app.user, isNull);
      if (replacement) {
        app.user = UserProfile.fromJson({...userJson(), 'id': 'replacement'});
        api.token = 'replacement-token';
      }
      response.complete(oldUser);
      await mode;
      expect(app.user?.id, replacement ? 'replacement' : isNull);
      expect(api.token, replacement ? 'replacement-token' : isNull);
    });
  }

  test(
      'late presence failure cannot change a replacement session error or connectivity',
      () async {
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/presence/heartbeat' ? response.future : null;
    final heartbeat = app.heartbeat();
    await settle();
    api.interceptor = null;
    await app.logout();
    api.user = {...userJson(), 'id': 'replacement'};
    await app.login('http://localhost:3000', 'customer', 'fixture-key');
    response.completeError(const ApiFailure('OFFLINE', 'Old request failed.'));
    await heartbeat;
    expect(app.user?.id, 'replacement');
    expect(app.errorCode, isNull);
    expect(app.offline, isFalse);
  });

  test(
      'background waits for an in-flight online request then withdraws availability',
      () async {
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' && body?['online'] == true
            ? response.future
            : null;
    final online = app.setOnline(true);
    await settle();
    final background = app.setForeground(false);
    await settle();
    api.user = {...api.user, 'online': true};
    response.complete(api.user);
    await Future.wait([online, background]);
    expect(availabilityRequests(api), [true, false]);
    expect(api.user['online'], isFalse);
    expect(app.foreground, isFalse);
    expect(
        api.requests.where((r) => r['path'] == '/presence/heartbeat'), isEmpty);
  });

  test('returning to foreground does not cancel the pending offline withdrawal',
      () async {
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' && body?['online'] == true
            ? response.future
            : null;
    final online = app.setOnline(true);
    await settle();
    final background = app.setForeground(false);
    await settle();
    // The server may commit online before its response reaches this device.
    api.user = {...api.user, 'online': true};
    await app.setForeground(true);
    response.complete(api.user);
    await Future.wait([online, background]);
    expect(availabilityRequests(api), [true, false]);
    expect(api.user['online'], isFalse);
    expect(app.user?.online, isFalse);
  });

  test('new explicit online intent follows a pending background withdrawal',
      () async {
    final enable = Completer<Json>(), disable = Completer<Json>();
    var enables = 0;
    api.interceptor = (method, path, body) async {
      if (path != '/me/availability') return null;
      if (body?['online'] == false) return disable.future;
      return ++enables == 1 ? enable.future : null;
    };
    final first = app.setOnline(true);
    await settle();
    final background = app.setForeground(false);
    await settle();
    api.user = {...api.user, 'online': true};
    enable.complete(api.user);
    await first;
    await settle();
    expect(availabilityRequests(api), [true, false]);
    await app.setForeground(true);
    final fresh = app.setOnline(true);
    await settle();
    expect(availabilityRequests(api), [true, false]);
    api.user = {...api.user, 'online': false};
    disable.complete(api.user);
    await Future.wait([fresh, background]);
    expect(availabilityRequests(api), [true, false, true]);
    expect(api.user['online'], isTrue);
  });

  test('queued background withdrawal never uses a replacement account',
      () async {
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/me/availability' && body?['online'] == true
            ? response.future
            : null;
    final online = app.setOnline(true);
    await settle();
    final background = app.setForeground(false);
    await settle();
    app.user = UserProfile.fromJson({...userJson(), 'id': 'replacement'});
    api.token = 'replacement-token';
    response.complete(
        {...userJson(listener: true, approved: true), 'online': true});
    await Future.wait([online, background]);
    expect(availabilityRequests(api), [true]);
    expect(app.user?.id, 'replacement');
    expect(api.token, 'replacement-token');
  });
}
