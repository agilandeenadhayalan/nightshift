import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

void main() {
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
