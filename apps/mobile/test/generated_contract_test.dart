import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

void main() {
  Map<String, dynamic> eventFor(Map<String, dynamic> call) => {
        'id': 'event-id',
        'type': 'call.state_changed',
        'entityId': call['id'],
        'version': call['version'],
        'timestamp': '2026-11-21T00:00:00Z',
        'data': call,
      };

  for (final reason in ['test_credit_balance', 'test_duration_cap']) {
    test('generated call preserves duration limit reason $reason', () {
      final maximum = reason == 'test_credit_balance' ? 60 : 600;
      final decoded = sdk.Call.fromJson({
        ...callJson(state: 'connected'),
        'maxDurationSeconds': maximum,
        'durationLimitReason': reason,
      })!;
      final encoded = jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>;
      expect(encoded['durationLimitReason'], reason);
      expect(encoded['maxDurationSeconds'], maximum);
      expect(encoded['chargeMicrocredits'], 3600000);
    });
  }

  test('legacy call receipts remain reason-free in pages and durable events',
      () {
    final legacy = callJson(state: 'ended');
    final page = sdk.CallPage.fromJson({
      'items': [legacy],
      'nextCursor': null
    })!;
    final event = sdk.Event.fromJson(eventFor(legacy))!;
    for (final call in [page.items.single, event.data]) {
      final encoded = jsonDecode(jsonEncode(call)) as Map<String, dynamic>;
      expect(encoded.containsKey('durationLimitReason'), isFalse);
      expect(encoded['id'], legacy['id']);
      expect(encoded['chargeMicrocredits'], legacy['chargeMicrocredits']);
    }
  });

  test('new nested call reasons coexist with legacy page entries', () {
    final current = {
      ...callJson(state: 'connected'),
      'maxDurationSeconds': 60,
      'durationLimitReason': 'test_credit_balance',
    };
    final event = sdk.Event.fromJson(eventFor(current))!;
    final page = sdk.CallPage.fromJson({
      'items': [callJson(state: 'ended'), current],
      'nextCursor': null,
    })!;
    final encodedEvent = jsonDecode(jsonEncode(event)) as Map<String, dynamic>;
    final encodedPage = jsonDecode(jsonEncode(page)) as Map<String, dynamic>;
    expect(encodedEvent['data']['durationLimitReason'], 'test_credit_balance');
    expect(encodedPage['items'][0].containsKey('durationLimitReason'), isFalse);
    expect(
        encodedPage['items'][1]['durationLimitReason'], 'test_credit_balance');
  });

  test('unknown duration reasons fail without weakening existing call enums',
      () {
    for (final invalid in [
      'future_reason',
      7,
      <String>[],
      <String, dynamic>{}
    ]) {
      final call = {...callJson(), 'durationLimitReason': invalid};
      expect(() => sdk.Call.fromJson(call), throwsFormatException);
      expect(() => sdk.Event.fromJson(eventFor(call)), throwsFormatException);
      expect(
          () => sdk.CallPage.fromJson({
                'items': [call],
                'nextCursor': null
              }),
          throwsFormatException);
    }
    expect(() => sdk.Call.fromJson({...callJson(), 'mediaType': 'unsupported'}),
        throwsFormatException);
    expect(() => sdk.Call.fromJson({...callJson(), 'state': 'unsupported'}),
        throwsFormatException);
  });

  test('unknown duration reason becomes the facade safe invalid-response error',
      () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            jsonEncode({...callJson(), 'durationLimitReason': 'future_reason'}),
            200)));
    addTearDown(api.close);
    await expectLater(
        api.request('GET', '/calls/call-id'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'INVALID_RESPONSE')));
  });

  test('generated calls preserve explicit nullable fields and UTC instants',
      () {
    final decoded = sdk.Call.fromJson(callJson())!;
    final encoded = jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>;
    expect(encoded['acceptedAt'], isNull);
    expect(encoded.containsKey('acceptedAt'), isTrue);
    expect(encoded.containsKey('endedAt'), isTrue);
    expect(encoded['reason'], isNull);
    expect(encoded['testOnly'], true);
    expect(decoded.createdAt.isUtc, true);
    expect(decoded.chargeMicrocredits, 3600000);
  });

  test('required nullable keys remain required at runtime', () {
    final invalid = callJson()..remove('endedAt');
    expect(() => sdk.Call.fromJson(invalid), throwsFormatException);
  });

  test(
      'unknown roles and languages cannot silently become customer or disappear',
      () {
    expect(() => sdk.User.fromJson({...userJson(), 'mode': 'staff'}),
        throwsFormatException);
    expect(
        () => sdk.User.fromJson({
              ...userJson(),
              'languages': ['en', 'unsupported']
            }),
        throwsFormatException);
  });

  test(
      'test-only boolean constants are booleans and reject false or string substitutes',
      () {
    expect(jsonDecode(jsonEncode(sdk.Rate.fromJson(rateJson())))['testOnly'],
        true);
    expect(() => sdk.Rate.fromJson({...rateJson(), 'testOnly': false}),
        throwsFormatException);
    expect(() => sdk.Rate.fromJson({...rateJson(), 'testOnly': 'true'}),
        throwsFormatException);
  });

  test('fixed-point integers reject fractional and numeric-string coercion',
      () {
    expect(() => sdk.Call.fromJson({...callJson(), 'chargeMicrocredits': 1.5}),
        throwsFormatException);
    expect(
        () => sdk.Call.fromJson({...callJson(), 'chargeMicrocredits': '60000'}),
        throwsFormatException);
  });

  test('malformed nullable objects and dates are rejected', () {
    expect(() => sdk.Call.fromJson(123), throwsFormatException);
    expect(() => sdk.Call.fromJson({...callJson(), 'endedAt': 'not-a-date'}),
        throwsFormatException);
  });

  test('generated model and exception diagnostics redact credentials', () {
    const secret = 'synthetic-secret-that-must-not-appear';
    final login = sdk.Login.fromJson({
      'token': secret,
      'expiresAt': '2026-11-20T01:00:00Z',
      'user': userJson(),
      'testOnly': true,
    })!;
    final rtc = sdk.RtcToken.fromJson({
      'token': secret,
      'appId': 'synthetic-app-id',
      'channel': 'synthetic-channel',
      'uid': 1,
      'remoteUid': 2,
      'expiresAt': '2026-11-20T01:00:00Z',
    })!;
    final request = sdk.DevelopmentSignInRequest.fromJson({
      'handle': 'customer',
      'accessKey': secret,
      'deviceId': 'device',
    })!;
    for (final value in [login, rtc, request, sdk.ApiException(500, secret)]) {
      expect(value.toString(), isNot(contains(secret)));
    }
    // Serialization still sends the credential to its intended API/RTC consumer.
    expect(jsonDecode(jsonEncode(request))['accessKey'], secret);
    expect(jsonDecode(jsonEncode(rtc))['token'], secret);
  });
}
