import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/account_privacy.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

const privacyNotice = {
  'noticeVersion': 'account-deletion-test-v1',
  'text':
      'Test deletion suspends the account. Test credits are inaccessible and nonrefundable. Financial and dispute retention needs review.',
  'testOnly': true,
  'retentionReviewRequired': true
};
Json deletionReceipt({bool held = false}) => {
      'requestId': 'request-id',
      'status': held ? 'pending_hold' : 'review_required',
      'requestedAt': '2026-11-20T10:00:00Z',
      'personalDataDeletedAt': '2026-11-20T10:00:00Z',
      'holds': held ? ['financial_records'] : [],
      'noticeVersion': 'account-deletion-test-v1',
      'testOnly': true,
      'retentionReviewRequired': true
    };

class FailingReceiptStore extends MemoryStore {
  @override
  Future<void> write(String key, String value) async {
    if (key == 'deletionReceipt') throw StateError('secure storage failure');
    await super.write(key, value);
  }
}

void main() {
  test('explicit deletion confirmation and durable receipt precede command',
      () async {
    final api = FakeApi()..token = 'bearer', store = MemoryStore();
    var deleted = false;
    api.interceptor = (m, p, b) async {
      if (p == '/me/deletion-requests') {
        expect(store.values['deletionReceipt'], isNotNull);
        expect(b!['receiptToken'], matches(r'^[a-f0-9]{64}$'));
        expect(b['confirm'], true);
        return deletionReceipt(held: true);
      }
      return null;
    };
    final privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {
          deleted = true;
          await store.delete('token');
        });
    addTearDown(privacy.dispose);
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: false, expectedOwnerId: 'owner');
    expect(api.requests, isEmpty);
    expect(store.values, isEmpty);
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(deleted, true);
    expect(privacy.receipt!['status'], 'pending_hold');
    expect(store.values['deletionReceipt'], isNotNull);
  });
  test('secure receipt write failure prevents deletion command', () async {
    final api = FakeApi();
    final privacy = AccountPrivacy(
        api: api,
        store: FailingReceiptStore(),
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(api.requests, isEmpty);
    expect(privacy.hasSavedReceipt, false);
  });
  test(
      'lost response recovers with tokenless status and never resubmits deletion',
      () async {
    final api = FakeApi()..token = 'private-current-token',
        statusApi = FakeApi()..token = 'must-be-cleared',
        store = MemoryStore();
    var deleted = 0;
    api.interceptor = (m, p, b) async {
      if (p == '/me/deletion-requests') {
        throw const ApiFailure('OFFLINE', 'uncertain');
      }
      return null;
    };
    statusApi.interceptor = (m, p, b) async {
      expect(p, '/account-deletion/status');
      expect(statusApi.token, isNull);
      expect(b!.keys, ['receiptToken']);
      return deletionReceipt();
    };
    final privacy = AccountPrivacy(
        api: api,
        receiptApi: statusApi,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {
          deleted++;
        });
    addTearDown(privacy.dispose);
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(privacy.hasSavedReceipt, true);
    expect(deleted, 0);
    final stored = jsonDecode(store.values['deletionReceipt']!);
    await privacy.recoverStatus();
    expect(deleted, 1);
    expect(
        api.requests.where((r) => r['path'] == '/me/deletion-requests').length,
        1);
    expect(statusApi.requests.single['body']['receiptToken'],
        stored['receipts'][0]['receiptToken']);
  });
  test(
      'legacy receipt migrates and another account can delete without losing it',
      () async {
    final api = FakeApi()..token = 'new-owner-token',
        store = MemoryStore(),
        statusApi = FakeApi();
    String? owner = 'new-owner';
    final deleted = <String>[];
    final original = jsonEncode({
      'ownerId': 'previous-owner',
      'origin': api.baseUrl,
      'receiptToken': 'a' * 64
    });
    store.values['deletionReceipt'] = original;
    final privacy = AccountPrivacy(
        api: api,
        receiptApi: statusApi,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => owner,
        onDeleted: (id) async {
          deleted.add(id);
        });
    addTearDown(privacy.dispose);
    await privacy.initialize();
    final migrated = jsonDecode(store.values['deletionReceipt']!);
    expect(migrated['version'], 2);
    expect(migrated['receipts'].single, jsonDecode(original));
    expect(privacy.hasSavedReceipt, false);
    api.interceptor = (m, p, b) async => deletionReceipt();
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'new-owner');
    expect(privacy.errorCode, isNull);
    expect(api.requests.length, 1);
    expect(deleted, ['new-owner']);
    final saved =
        jsonDecode(store.values['deletionReceipt']!)['receipts'] as List;
    expect(saved.length, 2);
    expect(saved.first, jsonDecode(original));
    expect(saved.last['ownerId'], 'new-owner');
    expect(saved.last['receiptToken'], isNot(saved.first['receiptToken']));
    expect(privacy.savedReceiptChoices.map((choice) => choice.index), [1]);
    privacy.selectReceipt(
        0); // A signed-in owner cannot view a prior owner's receipt.
    expect(privacy.selectedReceiptIndex, 1);
    owner = null;
    privacy.clearPrivateView();
    expect(privacy.savedReceiptChoices.length, 2);
    privacy.selectReceipt(0);
    expect(privacy.receipt, isNull);
    statusApi.interceptor = (m, p, b) async {
      expect(b!['receiptToken'], 'a' * 64);
      expect(statusApi.token, isNull);
      return deletionReceipt();
    };
    await privacy.recoverStatus();
    expect(privacy.receipt, isNotNull);
    expect(deleted, ['new-owner']);
  });
  test('saved capability never follows changed origin', () async {
    final api = FakeApi(), store = MemoryStore(), statusApi = FakeApi();
    store.values['deletionReceipt'] = jsonEncode({
      'ownerId': 'owner',
      'origin': 'https://original.example.test',
      'receiptToken': 'b' * 64
    });
    final privacy = AccountPrivacy(
        api: api,
        receiptApi: statusApi,
        store: store,
        backendUrl: 'https://changed.example.test',
        currentUserId: () => null,
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    await privacy.initialize();
    await privacy.recoverStatus();
    expect(privacy.errorCode, 'DELETION_ORIGIN_CHANGED');
    expect(statusApi.requests, isEmpty);
  });
  test('stale privacy load cannot repopulate a signed-out account', () async {
    final api = FakeApi(), pending = Completer<Json>();
    String? owner = 'owner';
    api.interceptor =
        (m, p, b) async => p == '/me/consents' ? pending.future : privacyNotice;
    final privacy = AccountPrivacy(
        api: api,
        store: MemoryStore(),
        backendUrl: api.baseUrl,
        currentUserId: () => owner,
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    final load = privacy.load();
    owner = null;
    privacy.clearPrivateView();
    pending.complete({
      'items': [
        {'purpose': 'private'}
      ]
    });
    await load;
    expect(privacy.consents, isEmpty);
    expect(privacy.notice, isNull);
  });
  test('fresh sign-in rejection keeps recovery receipt without auto retry',
      () async {
    final api = FakeApi()..token = 'owner-token', store = MemoryStore();
    api.interceptor = (m, p, b) async {
      throw const ApiFailure('FRESH_SIGN_IN_REQUIRED', 'safe', status: 403);
    };
    final privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {
          fail('not deleted');
        });
    addTearDown(privacy.dispose);
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(privacy.errorCode, 'FRESH_SIGN_IN_REQUIRED');
    expect(api.requests.length, 1);
    expect(privacy.hasSavedReceipt, true);
  });

  test('unreadable receipt list fails closed without overwriting capabilities',
      () async {
    final api = FakeApi()..token = 'owner-token', store = MemoryStore();
    const malformed =
        '{"version":2,"receipts":[{"receiptToken":"incomplete"}]}';
    store.values['deletionReceipt'] = malformed;
    final privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(api.requests, isEmpty);
    expect(privacy.errorCode, 'DELETION_RECEIPT_UNREADABLE');
    expect(store.values['deletionReceipt'], malformed);
  });

  test('failed legacy migration preserves the original secure receipt',
      () async {
    final api = FakeApi()..token = 'owner-token',
        store = FailingReceiptStore(),
        statusApi = FakeApi();
    final original = jsonEncode(
        {'ownerId': 'owner', 'origin': api.baseUrl, 'receiptToken': 'c' * 64});
    store.values['deletionReceipt'] = original;
    final privacy = AccountPrivacy(
        api: api,
        receiptApi: statusApi,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    await privacy.initialize();
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    expect(api.requests, isEmpty);
    expect(store.values['deletionReceipt'], original);
    expect(privacy.errorCode, 'DELETION_RECEIPT_UNREADABLE');
    statusApi.interceptor = (m, p, b) async {
      expect(b!['receiptToken'], 'c' * 64);
      return deletionReceipt();
    };
    await privacy.recoverStatus();
    expect(privacy.receipt, isNotNull);
    expect(store.values['deletionReceipt'], original);
  });

  test('same owner on a different service receives a separate capability',
      () async {
    final api = FakeApi()
          ..baseUrl = 'https://current.example.test'
          ..token = 'owner-token',
        store = MemoryStore();
    store.values['deletionReceipt'] = jsonEncode({
      'ownerId': 'owner',
      'origin': 'https://previous.example.test',
      'receiptToken': 'd' * 64
    });
    final privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => 'owner',
        onDeleted: (_) async {});
    addTearDown(privacy.dispose);
    api.interceptor = (m, p, b) async {
      expect(b!['receiptToken'], isNot('d' * 64));
      return deletionReceipt();
    };
    privacy.notice = privacyNotice;
    await privacy.submit(confirmed: true, expectedOwnerId: 'owner');
    final saved =
        jsonDecode(store.values['deletionReceipt']!)['receipts'] as List;
    expect(saved.length, 2);
    expect(saved.first['receiptToken'], 'd' * 64);
    expect(saved.last['origin'], api.baseUrl);
    expect(privacy.selectedReceiptIndex, 1);
  });

  test(
      'real transport cannot dispatch deletion after account changes during refresh',
      () async {
    final refreshStarted = Completer<void>(),
        releaseRefresh = Completer<void>();
    var calls = 0, deleted = 0;
    String? owner = 'account-a';
    final api = NightShiftApi(client: MockClient((request) async {
      calls++;
      return http.Response(jsonEncode(deletionReceipt()), 201);
    }))
      ..baseUrl = 'https://privacy.example.test'
      ..token = 'token-a';
    api.prepareSession = () async {
      refreshStarted.complete();
      await releaseRefresh.future;
    };
    final store = MemoryStore();
    final privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: api.baseUrl,
        currentUserId: () => owner,
        onDeleted: (_) async {
          deleted++;
        });
    addTearDown(privacy.dispose);
    addTearDown(api.close);
    privacy.notice = privacyNotice;
    final submitting =
        privacy.submit(confirmed: true, expectedOwnerId: 'account-a');
    await refreshStarted.future;
    owner = 'account-b';
    api.token = 'token-b';
    privacy.clearPrivateView();
    releaseRefresh.complete();
    await submitting;
    expect(calls, 0);
    expect(deleted, 0);
    expect(api.token, 'token-b');
    expect(privacy.hasSavedReceipt, false);
    expect(privacy.receipt, isNull);
    expect(
        jsonDecode(store.values['deletionReceipt']!)['receipts']
            .single['ownerId'],
        'account-a');
  });
}
