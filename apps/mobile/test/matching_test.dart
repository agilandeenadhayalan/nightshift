import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/matching.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

const matchId = '10000000-0000-4000-8000-000000000001';
const matchCallId = '20000000-0000-4000-8000-000000000001';
final matchClock = DateTime.utc(2026, 11, 21, 12);
Json matchJson(
        {String state = 'searching',
        int version = 1,
        int attempts = 0,
        String? reason,
        DateTime? serverTime,
        String id = matchId}) =>
    {
      'id': id,
      'version': version,
      'state': state,
      'language': 'ta',
      'mediaType': 'audio',
      'quoteId': 'test-audio-v1',
      'attemptCount': attempts,
      'maxAttempts': 3,
      'waitBudgetSeconds': 90,
      'invitationSeconds': 30,
      'createdAt': matchClock.toIso8601String(),
      'deadlineAt':
          matchClock.add(const Duration(seconds: 90)).toIso8601String(),
      'endedAt': ['searching', 'ringing'].contains(state)
          ? null
          : (serverTime ?? matchClock).toIso8601String(),
      'currentCallId':
          ['ringing', 'matched'].contains(state) ? matchCallId : null,
      'terminalReason': reason,
      'selectionReasons': ['ringing', 'matched'].contains(state)
          ? ['language_match', 'currently_available', 'fair_rotation']
          : <String>[],
      'serverTime': (serverTime ?? matchClock).toIso8601String(),
      'testOnly': true,
    };

class MatchHarness {
  final api = FakeApi()
    ..token = 'synthetic'
    ..baseUrl = 'https://api.example';
  Object? owner = 'owner-a';
  bool foreground = true;
  DateTime clock = matchClock;
  Json? server;
  late final Matching model = Matching(
      api: api,
      identity: () => owner,
      enabled: () => owner != null,
      foreground: () => foreground,
      now: () => clock,
      startTimer: false);
  MatchHarness() {
    api.interceptor = (method, path, body) async {
      if (path == '/me/match') return {'request': server};
      if (path == '/matches') return server = matchJson();
      if (path.endsWith('/cancel')) {
        return server = matchJson(
            state: 'cancelled', version: 2, reason: 'customer_cancelled');
      }
      return null;
    };
  }
  Future<void> ready() async {
    model.reconcile();
    await Future<void>.delayed(Duration.zero);
    await model.loadRate();
  }

  List<Json> get mutations =>
      api.requests.where((r) => r['method'] == 'POST').toList();
}

void main() {
  test(
      'strict generated matching schema rejects missing nullable and unknown state',
      () {
    expect(sdk.MatchingRequest.fromJson(matchJson()), isNotNull);
    expect(
        () =>
            sdk.MatchingRequest.fromJson(matchJson()..remove('currentCallId')),
        throwsFormatException);
    expect(
        () => sdk.MatchingRequest.fromJson({...matchJson(), 'state': 'video'}),
        throwsFormatException);
    expect(
        () => sdk.MatchingRequest.fromJson({...matchJson(), 'maxAttempts': 4}),
        throwsFormatException);
    expect(() => MatchRequest.fromJson({...matchJson(), 'attemptCount': 4}),
        throwsFormatException);
    expect(
        () => MatchRequest.fromJson(
            {...matchJson(), 'currentCallId': matchCallId}),
        throwsFormatException);
    expect(
        () => sdk.CreateMatchingRequest.fromJson({
              'language': 'ta',
              'mediaType': 'video',
              'quoteId': 'test-audio-v1',
              'consent': true,
              'consentVersion': 'matching-search-v1'
            }),
        throwsFormatException);
  });

  test(
      'explicit consent creates once; ticks only read and never extend deadline',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    await h.ready();
    await h.model.start(language: 'ta', consent: false);
    expect(h.mutations, isEmpty);
    await h.model.start(language: 'ta', consent: true);
    await h.model.start(language: 'ta', consent: true);
    expect(h.mutations, hasLength(1));
    expect(h.mutations.single['body'], {
      'language': 'ta',
      'mediaType': 'audio',
      'quoteId': 'test-audio-v1',
      'consent': true,
      'consentVersion': 'matching-search-v1'
    });
    h.clock = h.clock.add(const Duration(seconds: 91));
    h.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(h.model.remainingSeconds, 0);
    expect(h.model.request!.active, true,
        reason: 'client time never invents terminal state');
    expect(h.mutations, hasLength(1));
  });

  test('lost create response recovers committed receipt without replay',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    await h.ready();
    h.api.interceptor = (method, path, body) async {
      if (path == '/matches') {
        h.server = matchJson();
        throw const ApiFailure('OFFLINE', 'lost');
      }
      if (path == '/me/match') return {'request': h.server};
      return null;
    };
    await h.model.start(language: 'ta', consent: true);
    expect(h.model.uncertain, 'create');
    h.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(h.mutations, hasLength(1));
    await h.model.recover();
    expect(h.model.uncertain, isNull);
    expect(h.model.request!.id, matchId);
    await h.model.retry();
    expect(h.mutations, hasLength(1));
  });

  test('absent receipt permits only explicit identical key/body retry',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    await h.ready();
    var attempts = 0;
    h.api.interceptor = (method, path, body) async {
      if (path == '/matches' && attempts++ == 0) {
        throw const ApiFailure('OFFLINE', 'lost');
      }
      if (path == '/matches') return matchJson();
      if (path == '/me/match') return {'request': null};
      return null;
    };
    await h.model.start(language: 'ta', consent: true);
    await h.model.retry();
    expect(h.mutations, hasLength(1));
    await h.model.recover();
    expect(h.model.retryAllowed, true);
    h.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(h.mutations, hasLength(1));
    await h.model.retry();
    expect(h.mutations, hasLength(2));
    expect(h.mutations[0]['key'], h.mutations[1]['key']);
    expect(h.mutations[0]['body'], h.mutations[1]['body']);
  });

  test(
      'accept winning cancel returns matched and never calls End or replacement',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    h.server = matchJson(state: 'ringing', attempts: 1);
    await h.ready();
    h.api.interceptor = (method, path, body) async {
      if (path.endsWith('/cancel')) {
        return h.server = matchJson(state: 'matched', attempts: 1, version: 2);
      }
      if (path == '/me/match') return {'request': h.server};
      return null;
    };
    await h.model.cancel();
    expect(h.model.request!.state, 'matched');
    h.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(h.mutations, hasLength(1));
    expect(h.mutations.single['path'], '/matches/$matchId/cancel');
  });

  test('lost cancel response retains key and ignores older in-flight poll',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    h.server = matchJson(state: 'ringing', attempts: 1);
    await h.ready();
    final delayed = Completer<Json>();
    h.api.interceptor = (method, path, body) async {
      if (path == '/me/match') return delayed.future;
      if (path.endsWith('/cancel')) throw const ApiFailure('OFFLINE', 'lost');
      return null;
    };
    final read = h.model.recover();
    await h.model.cancel();
    delayed.complete({'request': matchJson(version: 1)});
    await read;
    expect(h.model.uncertain, 'cancel');
    expect(h.model.request!.state, 'ringing');
    final original = h.mutations.single;
    h.api.interceptor = (method, path, body) async {
      if (path == '/me/match') return {'request': h.server};
      if (path.endsWith('/cancel')) {
        return matchJson(
            state: 'cancelled', version: 2, reason: 'customer_cancelled');
      }
      return null;
    };
    await h.model.recover();
    await h.model.retry();
    expect(h.mutations.last['key'], original['key']);
    expect(h.mutations.last['body'], original['body']);
    expect(h.model.request!.state, 'cancelled');
  });

  test(
      'background pauses reads; resume recovers without starting a new request',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    h.server = matchJson(state: 'ringing', attempts: 1);
    await h.ready();
    final before = h.api.requests.length;
    h.foreground = false;
    h.model.tick();
    h.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(h.api.requests.length, before);
    h.foreground = true;
    h.model.reconcile();
    await Future<void>.delayed(Duration.zero);
    expect(h.api.requests.length, before + 1);
    expect(h.mutations, isEmpty);
  });

  test(
      'late create response after owner/origin change cannot expose old search',
      () async {
    final h = MatchHarness();
    addTearDown(h.model.dispose);
    await h.ready();
    final gate = Completer<Json>();
    h.api.interceptor = (method, path, body) async {
      if (path == '/matches') return gate.future;
      if (path == '/me/match') return {'request': null};
      return null;
    };
    final creating = h.model.start(language: 'ta', consent: true);
    h.owner = 'owner-b';
    h.api.baseUrl = 'https://different.example';
    h.model.reconcile();
    gate.complete(matchJson());
    await creating;
    await Future<void>.delayed(Duration.zero);
    expect(h.model.request, isNull);
    expect(h.model.uncertain, isNull);
  });

  test(
      'real generated transport freezes matching mutation across session refresh',
      () async {
    var owner = 'a', sends = 0;
    final gate = Completer<void>();
    final api = NightShiftApi(client: MockClient((request) async {
      sends++;
      return http.Response(jsonEncode(matchJson()), 200);
    }))
      ..baseUrl = 'https://api.example'
      ..token = 'token-a'
      ..sessionIdentity = (() => owner)
      ..prepareSession = () => gate.future;
    addTearDown(api.close);
    final pending =
        api.request('POST', '/matches', idempotencyKey: 'stable', body: {
      'language': 'ta',
      'mediaType': 'audio',
      'quoteId': 'test-audio-v1',
      'consent': true,
      'consentVersion': 'matching-search-v1'
    });
    owner = 'b';
    api.token = 'token-b';
    gate.complete();
    await expectLater(
        pending,
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'PRIVATE_SESSION_CHANGED')));
    expect(sends, 0);
  });

  test(
      'no supply and three declined attempts stay terminal without local charges',
      () async {
    for (final reason in ['no_supply', 'all_declined']) {
      final h = MatchHarness();
      h.server = matchJson(
          state: 'exhausted',
          version: 4,
          attempts: reason == 'no_supply' ? 0 : 3,
          reason: reason);
      await h.ready();
      for (var i = 0; i < 5; i++) {
        h.model.tick();
      }
      await Future<void>.delayed(Duration.zero);
      expect(h.model.blocked, false);
      expect(h.mutations, isEmpty);
      h.model.dispose();
    }
  });
}
