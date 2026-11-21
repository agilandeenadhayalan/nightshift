import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/discovery.dart';
import 'package:nightshift/core/directory_events.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

final clockStart = DateTime.utc(2026, 11, 20);
Json member(String id,
        {bool available = true,
        bool busy = false,
        bool favorite = false,
        String language = 'ta'}) =>
    {
      'id': id,
      'displayName': 'Listener $id',
      'languages': [language],
      'available': available,
      'online': available,
      'reachability': available ? 'foreground' : 'offline',
      'busy': busy,
      'favorite': favorite,
      'rate': rateJson()
    };
Json pageJson(List<Json> items,
        {String epoch = 'view-1', String? cursor, DateTime? server}) =>
    {
      'items': items,
      'viewEpoch': epoch,
      'nextCursor': cursor,
      'serverTime': (server ?? clockStart).toIso8601String(),
      'expiresAt': (server ?? clockStart)
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'truncated': false
    };
Json update(List<Json> items,
        {String epoch = 'view-1',
        List<String> removed = const [],
        DateTime? server}) =>
    {
      'items': items,
      'removedIds': removed,
      'viewEpoch': epoch,
      'language': 'ta',
      'serverTime': (server ?? clockStart.add(const Duration(seconds: 1)))
          .toIso8601String()
    };

class FakeEvents implements DirectoryEvents {
  void Function(Json)? update;
  void Function(bool)? connection;
  final subscriptions = <Json>[];
  int connections = 0, closes = 0;
  String? token;
  @override
  void connect(
      {required String origin,
      required String token,
      required void Function(Json) onUpdate,
      required void Function(bool) onConnection}) {
    connections++;
    this.token = token;
    update = onUpdate;
    connection = onConnection;
  }

  @override
  void subscribe(Json value, void Function(Json) ack) {
    subscriptions.add(value);
    ack({'ok': true, 'viewEpoch': value['viewEpoch']});
  }

  @override
  void close() {
    closes++;
  }
}

void main() {
  late FakeApi api;
  late Discovery state;
  late DateTime time;
  late Object owner;
  setUp(() {
    api = FakeApi()..token = 'token';
    time = clockStart;
    owner = 'owner-a';
    state = Discovery(
        api: api,
        identity: () => owner,
        enabled: () => api.token != null,
        now: () => time,
        startTimer: false);
    state.active = DirectoryKind.discover;
  });
  tearDown(() => state.dispose());

  test(
      'twenty-card pages preserve unique IDs and defer busy ranking while scrolling',
      () async {
    final first = List.generate(20, (i) => member('id-$i'));
    api.interceptor = (method, path, body) async => pageJson(
        path.contains('cursor=') ? [member('id-19'), member('id-20')] : first,
        cursor: path.contains('cursor=') ? null : 'page-2');
    await state.load(DirectoryKind.discover);
    state.viewport(['id-0'], scrolling: true, atTop: false);
    state.applyEvent(update([member('id-0', available: false, busy: true)]));
    expect(state.callable('id-0'), false);
    expect(state.items(DirectoryKind.discover).first.id, 'id-0');
    await state.load(DirectoryKind.discover, append: true);
    expect(state.items(DirectoryKind.discover).map((v) => v.id).toSet().length,
        21);
    expect(state.lookup('id-0')!.busy, true);
    time = time.add(const Duration(seconds: 21));
    state.tick();
    expect(state.page(DirectoryKind.discover).pendingRefresh, true);
    expect(api.requests.length, 2);
    api.interceptor = (m, p, b) async => pageJson(
        [member('id-20'), member('id-0', available: false, busy: true)],
        epoch: 'view-2', server: time);
    state.viewport(['id-0'], scrolling: false, atTop: true);
    await Future<void>.delayed(Duration.zero);
    expect(state.items(DirectoryKind.discover).map((v) => v.id),
        ['id-20', 'id-0']);
  });

  test(
      'failed page preserves cursor and cards; retry asks same page without false empty',
      () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one')], cursor: 'next');
    await state.load(DirectoryKind.discover);
    api.interceptor =
        (m, p, b) async => throw const ApiFailure('OFFLINE', 'hidden');
    await state.load(DirectoryKind.discover, append: true);
    expect(state.page(DirectoryKind.discover).cursor, 'next');
    expect(state.items(DirectoryKind.discover).length, 1);
    api.interceptor = (m, p, b) async => pageJson([member('two')]);
    await state.load(DirectoryKind.discover, append: true);
    expect(api.requests.skip(1).map((r) => r['path']).toSet().length, 1);
    expect(
        state.items(DirectoryKind.discover).map((v) => v.id), ['one', 'two']);
  });

  test('empty intermediate page with cursor is retained and can advance',
      () async {
    api.interceptor = (m, p, b) async => pageJson([], cursor: 'next');
    await state.load(DirectoryKind.discover);
    expect(state.page(DirectoryKind.discover).loaded, true);
    expect(state.page(DirectoryKind.discover).cursor, 'next');
    api.interceptor = (m, p, b) async => pageJson([member('reachable')]);
    await state.load(DirectoryKind.discover, append: true);
    expect(state.items(DirectoryKind.discover).single.id, 'reachable');
  });

  test('malformed and wrong-epoch pages leave valid rows intact', () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one')], cursor: 'next');
    await state.load(DirectoryKind.discover);
    api.interceptor =
        (m, p, b) async => pageJson([member('two')], epoch: 'wrong-view');
    await state.load(DirectoryKind.discover, append: true);
    expect(state.page(DirectoryKind.discover).error!.code, 'INVALID_RESPONSE');
    expect(state.items(DirectoryKind.discover).single.id, 'one');
    api.interceptor = (m, p, b) async => {};
    await state.load(DirectoryKind.discover);
    expect(state.items(DirectoryKind.discover).single.id, 'one');
  });

  test('account change discards pending page and favorite replies', () async {
    final pending = Completer<Json>();
    api.interceptor = (m, p, b) async => pending.future;
    final work = state.load(DirectoryKind.discover);
    owner = 'owner-b';
    state.reconcile();
    pending.complete(pageJson([member('private-a')]));
    await work;
    expect(state.items(DirectoryKind.discover), isEmpty);
    final favorite = Completer<Json>();
    api.interceptor = (m, p, b) async => favorite.future;
    final save = state.favorite('private-a', true);
    owner = 'owner-c';
    state.reconcile();
    favorite.complete({'favorite': true});
    await save;
    expect(state.favoriteRetry, isEmpty);
    expect(state.lookup('private-a'), isNull);
  });

  test('language change rejects older in-flight page and scopes new request',
      () async {
    final pending = Completer<Json>();
    api.interceptor = (m, p, b) async => p.contains('language=en')
        ? pageJson([member('english', language: 'en')], epoch: 'english')
        : pending.future;
    final work = state.load(DirectoryKind.discover);
    await state.filter(language: 'en');
    pending.complete(pageJson([member('tamil')]));
    await work;
    expect(state.items(DirectoryKind.discover).single.id, 'english');
  });

  test('scope and timestamp fencing rejects unrelated or late availability',
      () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one'), member('two')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    state.applyEvent(update([member('two', available: false, busy: true)]));
    expect(state.lookup('two')!.available, true);
    state.applyEvent(update([member('one', available: false, busy: true)]));
    state.applyEvent(update([member('one')], server: clockStart));
    expect(state.lookup('one')!.busy, true);
    state.applyEvent(update([], removed: ['one']));
    expect(state.lookup('one'), isNull);
    expect(state.callable('one'), false);
  });

  test('expiry and missing updates disable cards and require explicit new view',
      () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one')], cursor: 'next');
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: true, atTop: false);
    time = time.add(const Duration(seconds: 31));
    state.tick();
    expect(state.callable('one'), false);
    time = time.add(const Duration(minutes: 5));
    state.tick();
    expect(state.page(DirectoryKind.discover).cursor, isNull);
    expect(state.page(DirectoryKind.discover).error!.code,
        'DIRECTORY_VIEW_EXPIRED');
    expect(api.requests.length, 1);
  });

  test(
      'available-only busy event disables immediately without removing displayed ID',
      () async {
    await state.filter(availableOnly: true);
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: true, atTop: false);
    state.applyEvent(update([member('one', available: false, busy: true)]));
    expect(state.page(DirectoryKind.discover).ids, ['one']);
    expect(state.callable('one'), false);
  });

  test(
      'uncertain favorite retry repeats desired value then removes the saved card',
      () async {
    var mutations = 0;
    api.interceptor = (m, p, b) async {
      if (m == 'PUT') {
        mutations++;
        if (mutations == 1) throw const ApiFailure('OFFLINE', 'lost response');
        return {'favorite': true};
      }
      if (m == 'DELETE') return {'favorite': false};
      return pageJson([member('one')]);
    };
    await state.load(DirectoryKind.discover);
    await state.favorite('one', true);
    expect(state.favoriteRetry['one'], true);
    await state.favorite('one', state.favoriteRetry['one']!);
    expect(state.lookup('one')!.favorite, true);
    expect(state.favoriteRetry, isEmpty);
    state.page(DirectoryKind.favorites).ids = ['one'];
    await state.favorite('one', false);
    expect(state.items(DirectoryKind.favorites), isEmpty);
    expect(api.requests.where((r) => r['method'] == 'PUT').length, 2);
  });

  test('socket token renewal uses fresh connection and rejects old callbacks',
      () async {
    state.dispose();
    final events = FakeEvents();
    state = Discovery(
        api: api,
        identity: () => owner,
        enabled: () => api.token != null,
        events: events,
        now: () => time,
        startTimer: false);
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    state.activate(DirectoryKind.discover);
    await Future<void>.delayed(Duration.zero);
    state.viewport(['one'], scrolling: false, atTop: true);
    events.connection!(true);
    final oldUpdate = events.update!;
    api.token = 'renewed';
    state.reconcile();
    expect(events.connections, 2);
    oldUpdate(update([member('one', available: false, busy: true)]));
    expect(state.lookup('one')!.available, true);
    events.connection!(false);
    expect(state.callable('one'), false);
    owner = 'next';
    state.reconcile();
    expect(state.items(DirectoryKind.discover), isEmpty);
    expect(events.token, 'renewed');
  });

  test('Recents status removal does not alter historical call outcomes',
      () async {
    api.interceptor = (m, p, b) async => {
          'items': <Json>[],
          'removedIds': ['one'],
          'serverTime': clockStart.toIso8601String()
        };
    state.watchRecents(['one']);
    await Future<void>.delayed(Duration.zero);
    expect(state.removed('one'), true);
    expect(state.callable('one'), false);
    expect(api.requests.single['body'], {
      'language': 'ta',
      'listenerIds': ['one']
    });
  });
  test(
      'explicit block defeats pending page, status and socket responses across filters',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    final page = Completer<Json>(), status = Completer<Json>();
    api.interceptor = (m, p, b) async =>
        p == '/listeners/status' ? status.future : page.future;
    final loading = state.load(DirectoryKind.discover);
    state.watchRecents(['one']);
    state.forget('one');
    page.complete(pageJson([member('one')],
        server: clockStart.add(const Duration(seconds: 1))));
    status.complete({
      'items': [member('one')],
      'removedIds': <String>[],
      'serverTime': clockStart.add(const Duration(seconds: 2)).toIso8601String()
    });
    await loading;
    await Future<void>.delayed(Duration.zero);
    state.applyEvent(update([member('one')],
        server: clockStart.add(const Duration(seconds: 3))));
    expect(state.callable('one'), false);
    expect(state.items(DirectoryKind.discover), isEmpty);
    api.interceptor =
        (m, p, b) async => pageJson([member('one', language: 'en')]);
    await state.filter(language: 'en');
    expect(state.lookup('one'), isNull);
    expect(state.items(DirectoryKind.discover), isEmpty);
  });

  test('queued pre-favorite payload cannot undo confirmed mutation', () async {
    api.interceptor = (m, p, b) async =>
        m == 'PUT' ? {'favorite': true} : pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    await state.favorite('one', true);
    state.applyEvent(update([member('one', favorite: false)]));
    expect(state.lookup('one')!.favorite, true);
  });

  test('view eviction and subscription invalidation disable until refreshed',
      () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one')], cursor: 'next');
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    state.applyEvent({
      'viewEpoch': 'view-1',
      'invalidated': true,
      'code': 'DIRECTORY_VIEW_NOT_FOUND'
    });
    expect(state.callable('one'), false);
    api.interceptor = (m, p, b) async =>
        throw const ApiFailure('DIRECTORY_VIEW_NOT_FOUND', 'gone', status: 404);
    await state.load(DirectoryKind.discover, append: true);
    expect(state.page(DirectoryKind.discover).cursor, isNull);
    api.interceptor = (m, p, b) async =>
        pageJson([member('one')], epoch: 'new-view', server: time);
    await state.load(DirectoryKind.discover);
    expect(state.callable('one'), true);
  });
  test('refresh response arriving during scroll waits for idle top boundary',
      () async {
    api.interceptor =
        (m, p, b) async => pageJson([member('one'), member('two')]);
    await state.load(DirectoryKind.discover);
    final pending = Completer<Json>();
    api.interceptor = (m, p, b) async => pending.future;
    final refresh = state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: true, atTop: false);
    pending.complete(pageJson(
        [member('two'), member('one', available: false, busy: true)],
        epoch: 'view-2', server: time.add(const Duration(seconds: 1))));
    await refresh;
    expect(state.page(DirectoryKind.discover).ids, ['one', 'two']);
    expect(state.callable('one'), false);
    state.viewport(['one'], scrolling: false, atTop: true);
    expect(state.page(DirectoryKind.discover).ids, ['two', 'one']);
  });

  test('inconsistent or malformed live fields disable rather than enable call',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    state.applyEvent(update([
      {...member('one'), 'busy': true, 'available': true}
    ]));
    expect(state.callable('one'), false);
    await state.load(DirectoryKind.discover);
    state.applyEvent(update([
      {...member('one'), 'available': 'bad', 'status': 'available'}
    ]));
    expect(state.callable('one'), false);
  });

  test('invalidated epoch ignores queued older success until a new page',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    state.applyEvent({
      'viewEpoch': 'view-1',
      'invalidated': true,
      'code': 'DIRECTORY_VIEW_EXPIRED'
    });
    state.applyEvent(update([member('one')]));
    expect(state.callable('one'), false);
  });
  test(
      'explicit unavailable wins over legacy status and overlapping deltas fail closed',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: false, atTop: true);
    state.applyEvent(update([
      {...member('one', available: false), 'status': 'available'}
    ]));
    expect(state.callable('one'), false);
    await state.load(DirectoryKind.discover);
    state.applyEvent(update([member('one')], removed: ['one']));
    expect(state.callable('one'), false);
  });
  test('deferred installation preserves response freshness and expiry',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: true, atTop: false);
    api.interceptor =
        (m, p, b) async => pageJson([member('new')], epoch: 'view-2');
    await state.load(DirectoryKind.discover);
    time = time.add(const Duration(seconds: 31));
    state.viewport(['one'], scrolling: false, atTop: true);
    expect(state.page(DirectoryKind.discover).epoch, 'view-2');
    expect(state.callable('new'), false);
    expect(state.page(DirectoryKind.discover).expires,
        clockStart.add(const Duration(minutes: 5)));
  });

  test('expired deferred page never installs or revives available cards',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    state.viewport(['one'], scrolling: true, atTop: false);
    api.interceptor =
        (m, p, b) async => pageJson([member('new')], epoch: 'view-2');
    await state.load(DirectoryKind.discover);
    time = time.add(const Duration(minutes: 6));
    state.viewport(['one'], scrolling: false, atTop: true);
    expect(state.page(DirectoryKind.discover).epoch, 'view-1');
    expect(state.callable('new'), false);
    expect(state.page(DirectoryKind.discover).error!.code,
        'DIRECTORY_VIEW_EXPIRED');
  });

  test('malformed invalidation is contained and disables availability',
      () async {
    api.interceptor = (m, p, b) async => pageJson([member('one')]);
    await state.load(DirectoryKind.discover);
    expect(
        () => state.applyEvent(
            {'viewEpoch': 'view-1', 'invalidated': true, 'code': 123}),
        returnsNormally);
    expect(state.callable('one'), false);
  });
}
