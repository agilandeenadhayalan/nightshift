import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

void main() {
  late FakeApi api;
  late MemoryStore store;
  late AppController controller;

  setUp(() async {
    api = FakeApi();
    store = MemoryStore();
    controller = AppController(
        api: api, store: store, audio: FakeAudio(), startTimers: false);
    await controller.initialize();
    await controller.login('http://localhost:3000', 'customer', 'key');
  });
  tearDown(() => controller.dispose());

  test('history notifies loading before a delayed first page completes',
      () async {
    final page = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path == '/calls' && method == 'GET' ? page.future : null;
    final observed = <bool>[];
    controller.addListener(() => observed.add(controller.historyLoading));

    final loading = controller.loadHistory();
    expect(observed, [true]);
    expect(controller.historyLoaded, isFalse);
    page.complete({'items': <Json>[]});
    await loading;
    expect(observed, [true, false]);
    expect(controller.historyLoaded, isTrue);
    expect(controller.historyError, isNull);
  });

  test('failed first page has its own error and retries history', () async {
    var fail = true;
    api.interceptor = (method, path, body) async {
      if (path == '/calls' && fail) {
        throw const ApiFailure('OFFLINE', 'Unavailable',
            requestId: 'history-ref');
      }
      return null;
    };
    await controller.loadHistory();
    expect(controller.historyLoaded, isFalse);
    expect(controller.historyLoading, isFalse);
    expect(controller.historyError?.code, 'OFFLINE');
    expect(controller.historyError?.requestId, 'history-ref');
    expect(controller.error, isNull);
    final requestCount = api.requests.length;
    fail = false;
    await controller.retryHistory();
    expect(api.requests.skip(requestCount).map((r) => r['path']), ['/calls']);
    expect(controller.historyLoaded, isTrue);
    expect(controller.historyError, isNull);
  });

  test('failed page keeps existing calls and retry repeats the same cursor',
      () async {
    var fail = true;
    api.interceptor = (method, path, body) async {
      if (path == '/calls' && method == 'GET') {
        return {
          'items': [callJson(state: 'ended')],
          'nextCursor': 'page/2'
        };
      }
      if (path == '/calls?cursor=page%2F2') {
        if (fail) throw const ApiFailure('OFFLINE', 'Unavailable');
        return {
          'items': [
            {...callJson(state: 'ended'), 'id': 'older-call'}
          ],
          'nextCursor': null
        };
      }
      return null;
    };
    await controller.loadHistory();
    await controller.loadHistory(append: true);
    expect(controller.history.map((c) => c.id), ['call-id']);
    expect(controller.historyCursor, 'page/2');
    expect(controller.historyLoaded, isTrue);
    expect(controller.historyError?.code, 'OFFLINE');
    final requestCount = api.requests.length;
    fail = false;
    await controller.retryHistory();
    expect(api.requests.skip(requestCount).map((r) => r['path']),
        ['/calls?cursor=page%2F2']);
    expect(controller.history.map((c) => c.id), ['call-id', 'older-call']);
    expect(controller.historyCursor, isNull);
  });

  test('malformed refresh preserves previously loaded rows and cursor',
      () async {
    api.interceptor = (method, path, body) async => path == '/calls'
        ? {
            'items': [callJson(state: 'ended')],
            'nextCursor': 'page-2'
          }
        : null;
    await controller.loadHistory();
    api.interceptor = (method, path, body) async =>
        path == '/calls' ? {'items': <Json>[], 'nextCursor': 5} : null;
    await controller.loadHistory();
    expect(controller.historyLoaded, isTrue);
    expect(controller.history.map((c) => c.id), ['call-id']);
    expect(controller.historyCursor, 'page-2');
    expect(controller.historyError?.code, 'INVALID_RESPONSE');
  });

  test('logout clears history state and ignores its delayed response',
      () async {
    api.historyItems = [callJson(state: 'ended')];
    await controller.loadHistory();
    final page = Completer<Json>();
    api.interceptor =
        (method, path, body) async => path == '/calls' ? page.future : null;
    final loading = controller.loadHistory();
    await controller.logout();
    expect(controller.history, isEmpty);
    expect(controller.historyCursor, isNull);
    expect(controller.historyLoaded, isFalse);
    expect(controller.historyLoading, isFalse);
    expect(controller.historyError, isNull);
    expect(controller.lastCall, isNull);
    page.complete({
      'items': [callJson(state: 'ended')],
      'nextCursor': 'private-old-page'
    });
    await loading;
    expect(controller.history, isEmpty);
    expect(controller.historyCursor, isNull);
    expect(controller.historyLoaded, isFalse);
  });

  test('old session failure cannot clear a new history request', () async {
    final oldPage = Completer<Json>();
    final newPage = Completer<Json>();
    var pageCount = 0;
    api.interceptor = (method, path, body) async => path == '/calls'
        ? (++pageCount == 1 ? oldPage.future : newPage.future)
        : null;
    final oldLoading = controller.loadHistory();
    await controller.logout();
    await controller.login('http://localhost:3000', 'customer', 'key');
    final newLoading = controller.loadHistory();
    oldPage.completeError(
        const ApiFailure('UNAUTHORIZED', 'Expired', status: 401));
    await oldLoading;
    expect(controller.user, isNotNull);
    expect(controller.historyLoading, isTrue);
    expect(controller.historyError, isNull);
    newPage.complete({'items': <Json>[]});
    await newLoading;
    expect(controller.historyLoaded, isTrue);
    expect(controller.historyLoading, isFalse);
  });

  test(
      'history authorization failure clears the session and exposes error code',
      () async {
    api.interceptor = (method, path, body) async {
      if (path == '/calls') {
        throw const ApiFailure('UNAUTHORIZED', 'Expired', status: 401);
      }
      return null;
    };
    await controller.loadHistory();
    expect(controller.user, isNull);
    expect(api.token, isNull);
    expect(controller.errorCode, 'UNAUTHORIZED');
    expect(controller.historyLoaded, isFalse);
    expect(controller.historyLoading, isFalse);
  });

  test('stored Recents destination restores its calls', () async {
    final savedApi = FakeApi()..historyItems = [callJson(state: 'ended')];
    final savedStore = MemoryStore()
      ..values.addAll({'token': 'session', 'lastPath': '/history'});
    final restored = AppController(
        api: savedApi,
        store: savedStore,
        audio: FakeAudio(),
        startTimers: false);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.lastPath, '/history');
    expect(restored.historyLoaded, isTrue);
    expect(restored.history.single.id, 'call-id');
  });

  test('unsupported saved routes and languages restore safe defaults',
      () async {
    final savedApi = FakeApi();
    final savedStore = MemoryStore()
      ..values.addAll({
        'token': 'session',
        'lastPath': '/staff',
        'locale': 'unsupported',
        'language': 'unsupported'
      });
    final restored = AppController(
        api: savedApi,
        store: savedStore,
        audio: FakeAudio(),
        startTimers: false);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.lastPath, '/home');
    expect(restored.locale, 'en');
    expect(restored.language, 'ta');
    expect(savedApi.requests.any((r) => r['path'] == '/snapshot?language=ta'),
        isTrue);
    await restored.navigate('/unknown');
    expect(savedStore.values['lastPath'], '/home');
  });

  test('switching approved mode persists the home destination', () async {
    api.user = userJson(approved: true);
    await controller.refresh();
    await controller.navigate('/profile');
    await controller.switchMode();
    expect(controller.isListener, isTrue);
    expect(controller.lastPath, '/home');
    expect(store.values['lastPath'], '/home');
  });

  test('old directory poll cannot undo a successful mode switch', () async {
    api.user = userJson(approved: true);
    await controller.refresh();
    final oldSnapshot = Completer<Json>();
    final oldProfile = api.user;
    api.interceptor = (method, path, body) async =>
        path.startsWith('/snapshot') ? oldSnapshot.future : null;
    final polling = controller.refresh();
    await controller.switchMode();
    expect(controller.isListener, isTrue);
    oldSnapshot.complete({
      'user': oldProfile,
      'activeCall': null,
      'listeners': <Json>[],
      'wallet': {'balanceMicrocredits': 600000000, 'heldMicrocredits': 0}
    });
    await polling;
    expect(controller.isListener, isTrue);
    expect(store.values['lastPath'], '/home');
  });

  test('first snapshot failure never becomes a loaded empty directory',
      () async {
    await controller.logout();
    api.snapshotFailure = const ApiFailure('OFFLINE', 'Unavailable');
    await controller.login('http://localhost:3000', 'customer', 'key');
    expect(controller.user, isNotNull);
    expect(controller.snapshotLoaded, isFalse);
    expect(controller.snapshotLoading, isFalse);
    expect(controller.errorCode, 'OFFLINE');
    controller.clearError();
    expect(controller.snapshotLoaded, isFalse);
    api.snapshotFailure = null;
    await controller.refresh();
    expect(controller.snapshotLoaded, isTrue);
    expect(controller.snapshotLoading, isFalse);
  });

  test('new session ignores an older snapshot authorization failure', () async {
    final oldSnapshot = Completer<Json>();
    final newSnapshot = Completer<Json>();
    var count = 0;
    api.interceptor = (method, path, body) async => path.startsWith('/snapshot')
        ? (++count == 1 ? oldSnapshot.future : newSnapshot.future)
        : null;
    final oldPolling = controller.refresh();
    await controller.logout();
    final login = controller.login('http://localhost:3000', 'customer', 'key');
    await Future<void>.delayed(Duration.zero);
    expect(controller.snapshotLoaded, isFalse);
    expect(controller.snapshotLoading, isTrue);
    oldSnapshot.completeError(
        const ApiFailure('UNAUTHORIZED', 'Expired old session', status: 401));
    await oldPolling;
    expect(controller.user, isNotNull);
    expect(controller.snapshotLoading, isTrue);
    expect(controller.error, isNull);
    newSnapshot.complete({
      'user': api.user,
      'activeCall': null,
      'listeners': <Json>[],
      'wallet': {'balanceMicrocredits': 600000000, 'heldMicrocredits': 0}
    });
    await login;
    expect(controller.snapshotLoading, isFalse);
    expect(controller.snapshotLoaded, isTrue);
  });

  test('background recovery clears only the previous snapshot failure',
      () async {
    api.snapshotFailure = const ApiFailure('OFFLINE', 'Unavailable',
        requestId: 'snapshot-reference');
    await controller.refresh();
    expect(controller.errorCode, 'OFFLINE');
    expect(controller.diagnosticId, 'snapshot-reference');
    api.interceptor = (method, path, body) async {
      if (path == '/calls') {
        throw const ApiFailure('INVALID_RESPONSE', 'History unavailable');
      }
      return null;
    };
    await controller.loadHistory();
    api.snapshotFailure = null;
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.errorCode, isNull);
    expect(controller.diagnosticId, isNull);
    expect(controller.offline, isFalse);
    expect(controller.historyError?.code, 'INVALID_RESPONSE');
  });

  test('successful snapshot preserves an unrelated command failure', () async {
    api.snapshotFailure = const ApiFailure('OFFLINE', 'Unavailable');
    await controller.refresh();
    api.snapshotFailure = null;
    await controller.perform(() async {
      throw const ApiFailure('MICROPHONE_DENIED', 'Microphone denied',
          requestId: 'command-reference');
    });
    // perform refreshes after an error, and a later background poll does too.
    await controller.refresh();
    expect(controller.error, 'Microphone denied');
    expect(controller.errorCode, 'MICROPHONE_DENIED');
    expect(controller.diagnosticId, 'command-reference');
  });

  test(
      'sign-in waits for revoked-session storage cleanup before saving its token',
      () async {
    final delayedStore = DelayedTokenStore();
    final sessionApi = FakeApi();
    var signIns = 0;
    sessionApi.interceptor = (method, path, body) async => path == '/auth/dev'
        ? {'token': 'session-${++signIns}', 'user': sessionApi.user}
        : null;
    final session = AppController(
        api: sessionApi,
        store: delayedStore,
        audio: FakeAudio(),
        startTimers: false);
    addTearDown(session.dispose);
    await session.initialize();
    await session.login('http://localhost:3000', 'customer', 'key');
    delayedStore.delayDeletion = true;
    sessionApi.snapshotFailure =
        const ApiFailure('UNAUTHORIZED', 'Expired', status: 401);
    final revoked = session.refresh();
    await delayedStore.deletionStarted.future;
    expect(session.user, isNull);
    sessionApi.snapshotFailure = null;
    final signingIn = session.login('http://localhost:3000', 'customer', 'key');
    await Future<void>.delayed(Duration.zero);
    expect(signIns, 1);
    delayedStore.releaseDeletion.complete();
    await revoked;
    await signingIn;
    expect(signIns, 2);
    expect(sessionApi.token, 'session-2');
    expect(delayedStore.values['token'], 'session-2');
    expect(session.user, isNotNull);
    expect(session.busy, isFalse);
  });
}

class DelayedTokenStore extends MemoryStore {
  bool delayDeletion = false;
  final deletionStarted = Completer<void>();
  final releaseDeletion = Completer<void>();

  @override
  Future<void> delete(String key) async {
    if (key == 'token' && delayDeletion) {
      deletionStarted.complete();
      await releaseDeletion.future;
    }
    await super.delete(key);
  }
}
