import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'fakes.dart';

Map<String, dynamic> profile() => {
      'displayName': 'New name',
      'avatarCode': 'moon',
      'interfaceLanguage': 'ta',
      'languages': ['ta', 'en'],
      'dateOfBirth': null
    };
void main() {
  test(
      'Firebase admission uses generated request and exchange carries admission only in body',
      () async {
    var step = 0;
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.followRedirects, false);
      expect(request.url.query, isEmpty);
      if (step++ == 0) {
        expect(request.url.path, '/v1/auth/firebase/admissions');
        expect(request.headers['Idempotency-Key'], 'stable-admission-key');
        expect(jsonDecode(request.body), {
          'phone': '+919876543210',
          'deviceId': 'device',
          'consentVersion': 'phone-signin-v1'
        });
        return http.Response(
            jsonEncode({
              'attemptId': 'private-admission',
              'expiresAt': '2026-11-20T10:05:00Z',
              'retryAt': '2026-11-20T10:01:00Z'
            }),
            200);
      }
      expect(request.url.path, '/v1/auth/exchange');
      expect(jsonDecode(request.body), {
        'idToken': 'fixture-id',
        'deviceId': 'device',
        'attemptId': 'private-admission'
      });
      return http.Response(
          jsonEncode({
            'token': 'fixture-id',
            'expiresAt': '2026-11-20T11:00:00Z',
            'user': userJson(),
            'needsOnboarding': true,
            'testOnly': true
          }),
          200);
    }));
    addTearDown(api.close);
    await api.request('POST', '/auth/firebase/admissions',
        idempotencyKey: 'stable-admission-key',
        body: {
          'phone': '+919876543210',
          'deviceId': 'device',
          'consentVersion': 'phone-signin-v1'
        });
    await api.request('POST', '/auth/exchange', body: {
      'idToken': 'fixture-id',
      'deviceId': 'device',
      'attemptId': 'private-admission'
    });
    final valid = {
      'attemptId': 'private-admission',
      'expiresAt': '2026-11-20T10:05:00Z',
      'retryAt': '2026-11-20T10:01:00Z'
    };
    for (final key in valid.keys) {
      expect(() => sdk.FirebasePhoneAdmission.fromJson({...valid}..remove(key)),
          throwsFormatException);
      expect(() => sdk.FirebasePhoneAdmission.fromJson({...valid, key: null}),
          throwsFormatException);
    }
    expect(sdk.FirebasePhoneAdmission.fromJson(valid).toString(),
        isNot(contains('private-admission')));
  });
  test('deletion capability is body-only, never diagnostic or URL data',
      () async {
    final token = 'c' * 64;
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.url.path, '/v1/account-deletion/status');
      expect(request.url.query, isEmpty);
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.followRedirects, false);
      expect(jsonDecode(request.body), {'receiptToken': token});
      return http.Response(
          jsonEncode({
            'requestId': 'fixture-request',
            'status': 'review_required',
            'requestedAt': '2026-11-20T10:00:00Z',
            'personalDataDeletedAt': null,
            'holds': [],
            'noticeVersion': 'account-deletion-test-v1',
            'testOnly': true,
            'retentionReviewRequired': true
          }),
          200);
    }));
    addTearDown(api.close);
    final result = await api.request('POST', '/account-deletion/status',
        body: {'receiptToken': token});
    expect(result.containsKey('receiptToken'), false);
    expect(
        sdk.DeletionReceiptRequest.fromJson({'receiptToken': token}).toString(),
        isNot(contains(token)));
  });
  test(
      'phone session requires trusted onboarding state and does not leak tokens',
      () {
    final json = {
      'token': 'synthetic-private-token',
      'expiresAt': '2026-11-20T01:00:00Z',
      'user': userJson(),
      'needsOnboarding': true,
      'testOnly': true
    };
    expect(sdk.PhoneSession.fromJson(json)!.toString(),
        isNot(contains('synthetic-private-token')));
    expect(
        () => sdk.PhoneSession.fromJson({...json}..remove('needsOnboarding')),
        throwsFormatException);
    expect(() => sdk.PhoneSession.fromJson({...json, 'needsOnboarding': null}),
        throwsFormatException);
    expect(() => sdk.PhoneSession.fromJson({...json, 'user': null}),
        throwsFormatException);
  });
  test('onboarding response enforces nullable key, enums and required state',
      () {
    expect(() => sdk.OnboardingState.fromJson({'profile': profile()}),
        throwsFormatException);
    expect(
        () => sdk.OnboardingState.fromJson(
            {'required': null, 'profile': profile()}),
        throwsFormatException);
    expect(
        () => sdk.OnboardingProfile.fromJson(profile()..remove('dateOfBirth')),
        throwsFormatException);
    expect(
        () => sdk.OnboardingProfile.fromJson(
            {...profile(), 'avatarCode': 'uploaded-photo'}),
        throwsFormatException);
    expect(
        () => sdk.OnboardingProfile.fromJson(
            {...profile(), 'interfaceLanguage': 'unsupported'}),
        throwsFormatException);
    expect(
        () => sdk.OnboardingProfile.fromJson({
              ...profile(),
              'languages': ['unsupported']
            }),
        throwsFormatException);
    expect(
        jsonDecode(jsonEncode(sdk.OnboardingState.fromJson(
            {'required': true, 'profile': profile()})))['required'],
        true);
  });
  test('onboarding wire request preserves calendar date and refuses redirects',
      () async {
    final api = NightShiftApi(client: MockClient((request) async {
      expect(request.followRedirects, false);
      expect(request.url.path, '/v1/me/onboarding');
      final body = jsonDecode(request.body);
      expect(body['dateOfBirth'], '2000-02-29');
      expect(body['consentVersion'], 'adult-onboarding-v1');
      return http.Response(
          jsonEncode({
            'required': false,
            'profile': {...profile(), 'dateOfBirth': '2000-02-29'}
          }),
          200);
    }));
    addTearDown(api.close);
    final result = await api.request('PUT', '/me/onboarding', body: {
      ...profile(),
      'dateOfBirth': '2000-02-29',
      'consentVersion': 'adult-onboarding-v1'
    });
    expect(result['profile']['dateOfBirth'], '2000-02-29');
  });
}
