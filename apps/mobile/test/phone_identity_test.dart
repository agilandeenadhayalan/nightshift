import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/features/message_copy.dart';
import 'package:nightshift_api/api.dart' as sdk;

const _phone = '+919876543210';
const _code = '462731';
const _challengeId = '5c2c0114-f8d6-4ed2-a3b7-6cb9d230dfb9';
const _userId = 'f16ff1da-8af1-4a7a-b6d6-aaf6c6f492fa';
const _customToken = 'fixture-custom-token-sensitive';
const _idToken = 'fixture-firebase-id-token-sensitive';
const _challenge = {
  'challengeId': _challengeId,
  'state': 'sent',
  'expiresAt': '2026-11-20T08:05:00.000Z',
  'retryAt': '2026-11-20T08:01:00.000Z',
};

void main() {
  test('OTP request uses generated body and stable header without phone in URL',
      () async {
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(),
          'https://identity.example.test/gateway/v1/auth/otp/request');
      expect(request.url.query, isEmpty);
      expect(request.headers['Idempotency-Key'], 'same-otp-attempt');
      expect(jsonDecode(request.body), {
        'phone': _phone,
        'deviceId': 'fixture-device',
        'consentVersion': 'phone-signin-v1',
      });
      return http.Response(jsonEncode(_challenge), 200);
    }))
      ..baseUrl = 'https://identity.example.test/gateway/';
    addTearDown(api.close);
    final response = await api.request('POST', '/auth/otp/request',
        body: {
          'phone': _phone,
          'deviceId': 'fixture-device',
          'consentVersion': 'phone-signin-v1',
        },
        idempotencyKey: 'same-otp-attempt');
    expect(response, _challenge);
    expect(api.token, isNull, reason: 'A challenge is not an app session.');
  });

  test('OTP request cannot send without an idempotency key', () async {
    var requests = 0;
    final api = NightShiftApi(client: MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(_challenge), 200);
    }));
    addTearDown(api.close);
    await expectLater(
        api.request('POST', '/auth/otp/request', body: {
          'phone': _phone,
          'deviceId': 'fixture-device',
          'consentVersion': 'phone-signin-v1',
        }),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'code', 'INVALID_REQUEST')));
    expect(requests, 0);
  });

  test('OTP proof and Firebase identity receipt do not create an app session',
      () async {
    var requests = 0;
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.query, isEmpty);
      requests++;
      if (requests == 1) {
        expect(request.url.path, '/v1/auth/otp/verify');
        expect(jsonDecode(request.body), {
          'challengeId': _challengeId,
          'phone': _phone,
          'code': _code,
          'deviceId': 'fixture-device',
        });
        return http.Response(
            jsonEncode({
              'customToken': _customToken,
              'userId': _userId,
              'needsOnboarding': true,
            }),
            200);
      }
      expect(request.url.path, '/v1/auth/firebase/verify');
      expect(jsonDecode(request.body), {'idToken': _idToken});
      return http.Response(
          jsonEncode({'userId': _userId, 'needsOnboarding': true}), 200);
    }));
    addTearDown(api.close);
    final proof = await api.request('POST', '/auth/otp/verify', body: {
      'challengeId': _challengeId,
      'phone': _phone,
      'code': _code,
      'deviceId': 'fixture-device',
    });
    expect(proof['customToken'], _customToken);
    expect(proof['needsOnboarding'], true);
    expect(api.token, isNull);
    final identity = await api
        .request('POST', '/auth/firebase/verify', body: {'idToken': _idToken});
    expect(identity, {'userId': _userId, 'needsOnboarding': true});
    expect(api.token, isNull,
        reason:
            'Client exchange/onboarding/session integration remains separate.');
  });

  test(
      'generated proof preserves existing onboarding status without granting roles',
      () async {
    final api = NightShiftApi(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'customToken': _customToken,
              'userId': _userId,
              'needsOnboarding': false,
            }),
            200)));
    addTearDown(api.close);
    final proof = await api.request('POST', '/auth/otp/verify', body: {
      'challengeId': _challengeId,
      'phone': _phone,
      'code': _code,
      'deviceId': 'fixture-device',
    });
    expect(proof['needsOnboarding'], false);
    expect(proof.containsKey('listenerApproved'), false);
    expect(api.token, isNull);
  });

  test(
      'generated phone identity models redact diagnostics and serialize only contract fields',
      () {
    final request = sdk.OtpRequest.fromJson({
      'phone': _phone,
      'deviceId': 'fixture-device',
      'consentVersion': 'phone-signin-v1',
      'listenerApproved': true,
    })!;
    final verification = sdk.OtpVerifyRequest.fromJson({
      'challengeId': _challengeId,
      'phone': _phone,
      'code': _code,
      'deviceId': 'fixture-device',
    })!;
    final idRequest =
        sdk.FirebaseVerifyRequest.fromJson({'idToken': _idToken})!;
    final proof = sdk.OtpProof.fromJson({
      'customToken': _customToken,
      'userId': _userId,
      'needsOnboarding': true,
    })!;
    for (final model in [request, verification, idRequest, proof]) {
      expect(model.toString(), contains('[redacted]'));
      for (final secret in [_phone, _code, _idToken, _customToken]) {
        expect(model.toString(), isNot(contains(secret)));
      }
    }
    expect(request.toJson().containsKey('listenerApproved'), false);
    expect(jsonDecode(jsonEncode(verification))['code'], _code);
    expect(idRequest.toJson(), {'idToken': _idToken});
  });

  test(
      'generated identity contracts reject malformed secrets and unknown challenge states',
      () {
    expect(
        () => sdk.OtpVerifyRequest.fromJson({
              'challengeId': _challengeId,
              'phone': _phone,
              'code': 462731,
              'deviceId': 'fixture-device',
            }),
        throwsA(isA<TypeError>()));
    expect(() => sdk.FirebaseVerifyRequest.fromJson({'idToken': null}),
        throwsFormatException);
    expect(
        () => sdk.OtpChallenge.fromJson({..._challenge, 'state': 'approved'}),
        throwsFormatException);
    expect(
        () => sdk.OtpProof.fromJson({
              'customToken': _customToken,
              'userId': _userId,
              'needsOnboarding': 'false',
            }),
        throwsFormatException);
  });

  test(
      'phone verification has a separate budget without creating an app session',
      () async {
    final api = NightShiftApi(
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (request.url.path.endsWith('/otp/verify')) {
            return http.Response(
                jsonEncode({
                  'customToken': _customToken,
                  'userId': _userId,
                  'needsOnboarding': true,
                }),
                200);
          }
          return http.Response(
              jsonEncode({'userId': _userId, 'needsOnboarding': true}), 200);
        }),
        requestTimeout: const Duration(milliseconds: 10),
        identityRequestTimeout: const Duration(milliseconds: 250));
    addTearDown(api.close);
    final proof = await api.request('POST', '/auth/otp/verify', body: {
      'challengeId': _challengeId,
      'phone': _phone,
      'code': _code,
      'deviceId': 'fixture-device',
    });
    expect(proof['customToken'], _customToken);
    final identity = await api
        .request('POST', '/auth/firebase/verify', body: {'idToken': _idToken});
    expect(identity['userId'], _userId);
    expect(api.token, isNull);
    await expectLater(
        api.request('GET', '/health'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'code', 'OFFLINE')));
  });

  test('phone verification deadline includes a stalled body and abort signal',
      () async {
    final client = _AbortObserver();
    final api = NightShiftApi(
        client: client,
        requestTimeout: const Duration(seconds: 1),
        identityRequestTimeout: const Duration(milliseconds: 10));
    addTearDown(api.close);
    await expectLater(
        api.request('POST', '/auth/otp/verify', body: {
          'challengeId': _challengeId,
          'phone': _phone,
          'code': _code,
          'deviceId': 'fixture-device',
        }),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'code', 'OFFLINE')));
    await client.aborted.future.timeout(const Duration(seconds: 1));
    expect(client.requests, 1,
        reason: 'The client must not retry OTP side effects.');
    await client.body.close();
  });

  test('wrong and expired codes have distinct Tamil and English recovery copy',
      () {
    expect(errorMessage('OTP_INVALID_CODE', 'en'), contains('incorrect'));
    expect(errorMessage('OTP_EXPIRED', 'en'), contains('expired'));
    expect(errorMessage('OTP_INVALID_CODE', 'ta'), contains('தவறாக'));
    expect(errorMessage('OTP_EXPIRED', 'ta'), contains('காலாவதியானது'));
    expect(errorMessage('OTP_UNKNOWN_OUTCOME', 'en'),
        contains('could not confirm'));
    expect(
        errorMessage('OTP_UNKNOWN_OUTCOME', 'en'), isNot(contains('not sent')));
  });

  test('all public phone identity failures have localized safe copy', () {
    const codes = [
      'OTP_INVALID_PHONE',
      'OTP_INVALID_INPUT',
      'OTP_INVALID_CONSENT',
      'OTP_INVALID_CODE',
      'OTP_EXPIRED',
      'OTP_CONSUMED',
      'OTP_NOT_FOUND',
      'OTP_COOLDOWN',
      'OTP_RATE_LIMITED',
      'OTP_LOCKED',
      'OTP_IN_PROGRESS',
      'OTP_UNKNOWN_OUTCOME',
      'OTP_UNAVAILABLE',
      'OTP_PROVIDER_UNAVAILABLE',
      'PHONE_AUTH_UNAVAILABLE',
      'IDENTITY_CONFIGURATION',
      'IDENTITY_UNAVAILABLE',
      'INVALID_ID_TOKEN',
      'ID_TOKEN_EXPIRED',
      'ID_TOKEN_REVOKED',
      'IDENTITY_DISABLED',
      'ACCOUNT_RESTRICTED',
      'IDEMPOTENCY_CONFLICT',
    ];
    for (final code in codes) {
      final english = errorMessage(code, 'en');
      final tamil = errorMessage(code, 'ta');
      expect(english, isNot(errorMessage(null, 'en')), reason: code);
      expect(tamil, isNot(errorMessage(null, 'ta')), reason: code);
      expect(tamil, matches(RegExp(r'[\u0B80-\u0BFF]')), reason: code);
      expect(tamil, isNot(contains(code)), reason: code);
    }
    expect(errorMessage('unknown-$idFixture', 'ta'), errorMessage(null, 'ta'));
    expect(errorMessage('IDEMPOTENCY_CONFLICT', 'en'), isNot(contains('call')));
  });
}

const idFixture = 'private-provider-diagnostic';

class _AbortObserver extends http.BaseClient {
  final aborted = Completer<void>();
  final body = StreamController<List<int>>();
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    expect(request, isA<http.AbortableRequest>());
    final abort = (request as http.AbortableRequest).abortTrigger;
    expect(abort, isNotNull);
    unawaited(abort!.then((_) => aborted.complete()));
    return Future.value(http.StreamedResponse(body.stream, 200));
  }
}
