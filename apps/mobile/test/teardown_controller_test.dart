import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

class HeldCleanup extends FakeVideo {
  Future<void>? leaving, previewStop, permission;
  @override
  Future<void> leave() async {
    await super.leave();
    await leaving;
  }

  @override
  Future<void> stopPreview() async {
    await super.stopPreview();
    await previewStop;
  }

  @override
  Future<void> checkPermission() async {
    await permission;
    await super.checkPermission();
  }
}

class HeldStore extends MemoryStore {
  String? heldDelete, heldWrite;
  bool holdNextWriteOnly = false;
  Future<void>? gate;
  @override
  Future<void> delete(String key) async {
    if (key == heldDelete) await gate;
    await super.delete(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (key == heldWrite) {
      if (holdNextWriteOnly) heldWrite = null;
      await gate;
    }
    await super.write(key, value);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeApi api;
  late HeldCleanup audio;
  late HeldStore store;
  late AppController controller;
  Future<void> connected() async {
    await controller.login('http://localhost:3000', 'customer', 'key');
    api.call = callJson(state: 'connected');
    await controller.refresh();
    await settle();
    audio.ready = true;
    api.requests.clear();
  }

  setUp(() async {
    api = FakeApi();
    audio = HeldCleanup();
    store = HeldStore();
    controller =
        AppController(api: api, audio: audio, store: store, startTimers: false);
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test(
      'End persists intent and reaches the server while native cleanup is unsettled',
      () async {
    await connected();
    final cleanup = Completer<void>(), server = Completer<Json>();
    audio.leaving = cleanup.future;
    api.interceptor = (method, path, body) async =>
        path.endsWith('/end') ? server.future : null;
    final ending = controller.transition('end');
    try {
      await settle();
      expect(controller.endingLocally, isTrue);
      expect(store.values['abandonedCallId'], 'call-id');
      expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
          hasLength(1));
      expect(audio.ready, isFalse);
    } finally {
      cleanup.complete();
      server.complete(callJson(state: 'ended'));
      await ending;
    }
  });

  test('blocked stop persistence cannot delay server End or cleanup admission',
      () async {
    await connected();
    final disk = Completer<void>();
    store.heldWrite = 'abandonedCallId';
    store.gate = disk.future;
    final before = audio.leaveCount, ending = controller.transition('end');
    try {
      await settle();
      expect(audio.leaveCount, greaterThan(before));
      expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
          hasLength(1));
    } finally {
      disk.complete();
      await ending;
    }
  });

  test('terminal snapshot requests cleanup before waiting for storage',
      () async {
    await connected();
    final disk = Completer<void>();
    store.heldDelete = 'abandonedCallId';
    store.gate = disk.future;
    api.call = null;
    final before = audio.leaveCount, refresh = controller.refresh();
    try {
      await settle();
      expect(audio.leaveCount, greaterThan(before));
      expect(audio.ready, isFalse);
    } finally {
      disk.complete();
      await refresh;
    }
  });

  test('revoked session requests cleanup before blocked credential deletion',
      () async {
    await connected();
    final disk = Completer<void>();
    store.heldDelete = 'token';
    store.gate = disk.future;
    api.snapshotFailure =
        const ApiFailure('UNAUTHENTICATED', 'Expired', status: 401);
    final before = audio.leaveCount, refresh = controller.refresh();
    try {
      await settle();
      expect(api.token, isNull);
      expect(audio.leaveCount, greaterThan(before));
      expect(audio.ready, isFalse);
    } finally {
      disk.complete();
      await refresh;
    }
  });

  test('logout clears local authority while native cleanup is unsettled',
      () async {
    await connected();
    final cleanup = Completer<void>();
    audio.leaving = cleanup.future;
    final logout = controller.logout();
    try {
      await settle();
      expect(api.token, isNull);
      expect(controller.user, isNull);
      expect(store.values['token'], isNull);
      expect(
          api.requests.where((r) => r['path'] == '/auth/logout'), hasLength(1));
    } finally {
      cleanup.complete();
      await logout;
    }
  });

  test('logout is not discarded while a camera permission command is busy',
      () async {
    await connected();
    api.call = null;
    await controller.refresh();
    final permission = Completer<void>();
    audio.permission = permission.future;
    final starting = controller.startCall(ListenerProfile(
        id: 'listener-id',
        name: 'Listener',
        languages: ['ta'],
        available: true));
    await settle();
    expect(controller.busy, isTrue);
    final logout = controller.logout();
    try {
      await settle();
      expect(api.token, isNull);
      expect(controller.user, isNull);
    } finally {
      permission.complete();
      await Future.wait([starting, logout]);
    }
  });

  test('unknown End retries retain the original command key and version',
      () async {
    await connected();
    api.interceptor = (method, path, body) async {
      if (path.endsWith('/end')) {
        throw const ApiFailure('OFFLINE', 'Unknown result');
      }
      return null;
    };
    await controller.transition('end');
    await controller.refresh();
    final ends =
        api.requests.where((r) => r['path'] == '/calls/call-id/end').toList();
    expect(ends.length, greaterThanOrEqualTo(2));
    expect(ends.last['key'], ends.first['key']);
    expect(ends.last['body'], ends.first['body']);
  });

  test('late End response cannot clear a replacement owner call or history',
      () async {
    await connected();
    final result = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/calls/call-id/end' ? result.future : null;
    final ending = controller.transition('end');
    await settle();
    await controller.logout();
    api.user = userJson(listener: true, approved: true);
    api.call = {...callJson(state: 'connected'), 'id': 'replacement-call'};
    await controller.login('http://localhost:3000', 'listener', 'key');
    await settle();
    expect(controller.activeCall?.id, 'replacement-call');
    result.complete(callJson(state: 'ended'));
    await ending;
    expect(controller.activeCall?.id, 'replacement-call');
    expect(controller.user?.id, 'listener-id');
    expect(controller.lastCall, isNull);
  });

  test('old audio failure cleanup cannot end a replacement call', () async {
    await connected();
    final cleanup = Completer<void>();
    audio.leaving = cleanup.future;
    audio.onFailure?.call('RTC_MICROPHONE_FAILED');
    await settle();
    api.call = {...callJson(state: 'connected'), 'id': 'replacement-call'};
    await controller.refresh();
    await settle();
    api.requests.clear();
    cleanup.complete();
    await settle();
    expect(controller.activeCall?.id, 'replacement-call');
    expect(
        api.requests.where((r) => r['path'] == '/calls/replacement-call/end'),
        isEmpty);
  });

  test('cleanup uncertainty remains visible after successful server End',
      () async {
    await connected();
    final cleanup = Completer<void>();
    audio.leaving = cleanup.future;
    final ending = controller.transition('end');
    await settle();
    cleanup.completeError(
        const ApiFailure('RTC_CLEANUP_PENDING', 'Cleanup pending'));
    await ending;
    await settle();
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
        hasLength(1));
    expect(controller.activeCall, isNull);
    expect(controller.errorCode, 'RTC_CLEANUP_PENDING');
  });

  test('restart retries the persisted unknown command despite a newer snapshot',
      () async {
    await connected();
    api.interceptor = (method, path, body) async {
      if (path.endsWith('/end')) throw const ApiFailure('OFFLINE', 'Unknown');
      return null;
    };
    await controller.transition('end');
    await settle();
    final first =
        api.requests.lastWhere((r) => r['path'] == '/calls/call-id/end');
    final receipt = jsonDecode(store.values['callStopIntent']!) as Json;
    expect(receipt['ownerId'], 'customer-id');
    controller.dispose();
    api.call = callJson(state: 'connected', version: 8);
    audio = HeldCleanup();
    controller =
        AppController(api: api, audio: audio, store: store, startTimers: false);
    await controller.initialize();
    await settle();
    final retried =
        api.requests.lastWhere((r) => r['path'] == '/calls/call-id/end');
    expect(retried['key'], first['key']);
    expect(retried['body'], first['body']);
    expect(audio.joinCount, 0);
    expect(controller.endingLocally, isTrue);
  });

  test('legacy marker waits for an exact authenticated call before binding',
      () async {
    controller.dispose();
    store.values['abandonedCallId'] = 'call-id';
    controller =
        AppController(api: api, audio: audio, store: store, startTimers: false);
    await controller.initialize();
    expect(
        api.requests.where((r) => (r['path'] as String).startsWith('/calls/')),
        isEmpty);
    api.call = callJson(state: 'connected');
    await controller.login('http://localhost:3000', 'customer', 'key');
    await settle();
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
        hasLength(1));
    expect(audio.joinCount, 0);
  });

  test('a foreign scoped receipt cannot borrow the current owner authority',
      () async {
    controller.dispose();
    store.values.addAll({
      'token': 'token',
      'baseUrl': 'http://localhost:3000',
      'abandonedCallId': 'call-id',
      'callStopIntent': jsonEncode({
        'schemaVersion': 1,
        'ownerId': 'another-owner',
        'origin': 'http://localhost:3000',
        'callId': 'call-id',
        'action': 'end',
        'version': 1,
        'key': 'frozen-key'
      })
    });
    api.call = callJson(state: 'connected');
    controller =
        AppController(api: api, audio: audio, store: store, startTimers: false);
    await controller.initialize();
    await settle();
    expect(
        api.requests.where((r) => r['path'] == '/calls/call-id/end'), isEmpty);
    expect(controller.endingLocally, isFalse);
    expect(audio.joinCount, 1);
  });

  test('a definitive conflict rebases key and body only after a current read',
      () async {
    await connected();
    var attempt = 0;
    api.interceptor = (method, path, body) async {
      if (path == '/calls/call-id/end' && attempt++ == 0) {
        api.call = callJson(state: 'connected', version: 9);
        throw const ApiFailure('VERSION_CONFLICT', 'Changed', status: 409);
      }
      return null;
    };
    await controller.transition('end');
    final ends =
        api.requests.where((r) => r['path'] == '/calls/call-id/end').toList();
    expect(ends.map((r) => (r['body'] as Json)['expectedVersion']), [1, 9]);
    expect(ends.last['key'], isNot(ends.first['key']));
    expect(
        api.requests.where(
            (r) => r['method'] == 'GET' && r['path'] == '/calls/call-id'),
        hasLength(1));
  });

  test('late conflict read cannot issue a rebased End under a new owner',
      () async {
    await connected();
    final read = Completer<Json>();
    api.interceptor = (method, path, body) async {
      if (path == '/calls/call-id/end') {
        throw const ApiFailure('VERSION_CONFLICT', 'Changed', status: 409);
      }
      if (method == 'GET' && path == '/calls/call-id') return read.future;
      return null;
    };
    final ending = controller.transition('end');
    await settle();
    await controller.logout();
    api.user = userJson(listener: true, approved: true);
    api.call = {...callJson(state: 'connected'), 'id': 'replacement-call'};
    await controller.login('http://localhost:3000', 'listener', 'key');
    read.complete(callJson(state: 'connected', version: 9));
    await ending;
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
        hasLength(1));
    expect(controller.activeCall?.id, 'replacement-call');
  });

  test('late cleanup error cannot replace a new call message', () async {
    await connected();
    final cleanup = Completer<void>();
    audio.leaving = cleanup.future;
    await controller.transition('end');
    api.call = {...callJson(state: 'connected'), 'id': 'replacement-call'};
    await controller.refresh();
    await settle();
    controller.clearError();
    cleanup.completeError(
        const ApiFailure('RTC_CLEANUP_FAILED', 'Old cleanup failed'));
    await settle();
    expect(controller.errorCode, isNull);
    expect(controller.activeCall?.id, 'replacement-call');
  });

  test('old pending remote logout cannot swallow a new owner logout', () async {
    await connected();
    final oldRemote = Completer<Json>();
    var count = 0;
    api.interceptor = (method, path, body) async =>
        path == '/auth/logout' && count++ == 0 ? oldRemote.future : null;
    final first = controller.logout();
    await settle();
    api.user = userJson(listener: true, approved: true);
    await controller.login('http://localhost:3000', 'listener', 'key');
    expect(controller.user?.id, 'listener-id');
    final second = controller.logout();
    try {
      await settle();
      expect(api.token, isNull);
      expect(controller.user, isNull);
      expect(
          api.requests.where((r) => r['path'] == '/auth/logout'), hasLength(2));
    } finally {
      oldRemote.complete({});
      await Future.wait([first, second]);
    }
  });

  test('delayed history persistence cannot overwrite newer navigation',
      () async {
    await connected();
    final disk = Completer<void>();
    store.heldWrite = 'lastPath';
    store.holdNextWriteOnly = true;
    store.gate = disk.future;
    final ending = controller.transition('end');
    await settle();
    final navigation = controller.navigate('/profile');
    await settle();
    disk.complete();
    await Future.wait([ending, navigation]);
    expect(controller.lastPath, '/profile');
    expect(store.values['lastPath'], '/profile');
  });

  test(
      'unknown logout retains an owned stop receipt and cannot rejoin on sign-in',
      () async {
    await connected();
    final joins = audio.joinCount;
    api.interceptor = (method, path, body) async {
      if (path == '/auth/logout' || path.endsWith('/end')) {
        throw const ApiFailure('OFFLINE', 'Unknown result');
      }
      return null;
    };
    await controller.logout();
    await settle();
    final saved = store.values['callStopIntent'];
    expect(saved, isNotNull);
    expect((jsonDecode(saved!) as Json)['ownerId'], 'customer-id');
    await controller.login('http://localhost:3000', 'customer', 'key');
    await settle();
    expect(controller.endingLocally, isTrue);
    expect(audio.joinCount, joins);
    expect(api.requests.where((r) => r['path'] == '/calls/call-id/end'),
        hasLength(1));
  });
}
