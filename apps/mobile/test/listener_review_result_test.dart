import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/listener_application.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';
import 'listener_application_test.dart' show applicationJson;

Json reviewResult(
        {String state = 'approved', String entitlement = 'pending'}) =>
    {
      'applicationId': 'application-id',
      'state': state,
      'review': {
        'applicationId': 'application-id',
        'decisionId': 'decision-id',
        'outcome': state,
        'reasonCode': 'fixture-reviewed',
        'message': {
          'en': 'Synthetic review result.',
          'ta': 'சோதனை ஆய்வு முடிவு.'
        },
        'missingChecks': <Json>[],
        'recordedAt': '2026-11-21T01:00:00Z',
        'entitlement': entitlement,
        'notification': null,
      },
    };

void main() {
  test(
      'generated owner result HTTP operation decodes localized outcome privately',
      () async {
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/me/listener-application/review');
      expect(request.headers['authorization'], 'Bearer private-token');
      expect(request.followRedirects, false);
      return http.Response(jsonEncode(reviewResult()), 200,
          headers: {'content-type': 'application/json'});
    }))
      ..token = 'private-token';
    api.baseUrl = 'https://api.example';
    final result = await api.privateRequest(
        'GET', '/me/listener-application/review',
        origin: api.baseUrl, isCurrent: () => true);
    expect(result['review']['message']['ta'], 'சோதனை ஆய்வு முடிவு.');
    expect(result['review']['entitlement'], 'pending');
  });
  test('approval result never changes the account or infers active entitlement',
      () async {
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async => p.endsWith('/review')
        ? reviewResult()
        : {'application': applicationJson(state: 'approved')};
    final flow = ListenerApplication(api: api, currentUserId: () => 'owner');
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.reviewOutcome?['entitlement'], 'pending');
    expect(api.user['listenerApproved'], false);
    expect(api.requests.where((r) => r['method'] != 'GET'), isEmpty);
  });

  test('a late owner result is discarded after account switch', () async {
    final api = FakeApi()..token = 'token';
    final pending = Completer<Json>();
    var owner = 'owner';
    api.interceptor = (m, p, b) async => p.endsWith('/review')
        ? pending.future
        : {'application': applicationJson(state: 'rejected')};
    final flow = ListenerApplication(api: api, currentUserId: () => owner);
    addTearDown(flow.dispose);
    final loading = flow.load();
    await Future<void>.delayed(Duration.zero);
    owner = 'different-owner';
    flow.clearPrivateView();
    pending.complete(
        reviewResult(state: 'rejected', entitlement: 'not_applicable'));
    await loading;
    expect(flow.reviewOutcome, isNull);
    expect(flow.application, isNull);
    expect(flow.reviewErrorCode, isNull);
  });

  test('resubmitted application cannot display an old information request',
      () async {
    final api = FakeApi()..token = 'token';
    var state = 'needs_information';
    api.interceptor = (m, p, b) async => p.endsWith('/review')
        ? reviewResult(
            state: 'needs_information', entitlement: 'not_applicable')
        : {'application': applicationJson(state: state)};
    final flow = ListenerApplication(api: api, currentUserId: () => 'owner');
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.reviewOutcome?['outcome'], 'needs_information');
    state = 'submitted';
    await flow.load();
    expect(flow.reviewOutcome, isNull);
  });

  test('inconsistent application result is hidden and requests a reload',
      () async {
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async => p.endsWith('/review')
        ? {...reviewResult(), 'applicationId': 'another-application'}
        : {'application': applicationJson(state: 'approved')};
    final flow = ListenerApplication(api: api, currentUserId: () => 'owner');
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.reviewOutcome, isNull);
    expect(flow.reviewErrorCode, 'APPLICATION_REVIEW_CHANGED');
    expect(flow.application?['state'], 'approved');
  });

  test('result read failure does not make a completed mutation uncertain',
      () async {
    final api = FakeApi()..token = 'token';
    api.interceptor = (m, p, b) async {
      if (p.endsWith('/review')) {
        throw const ApiFailure('OFFLINE', 'offline');
      }
      if (m == 'GET') {
        return {'application': applicationJson(state: 'approved')};
      }
      return applicationJson(state: 'approved', consent: false);
    };
    final flow = ListenerApplication(api: api, currentUserId: () => 'owner');
    addTearDown(flow.dispose);
    await flow.load();
    await flow.withdraw(confirmed: true);
    expect(flow.application?['voiceSampleConsent'], false);
    expect(flow.uncertain, false);
    expect(flow.reviewErrorCode, 'APPLICATION_REVIEW_UNAVAILABLE');
  });
}
