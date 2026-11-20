import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/core/phone_sign_in.dart';
import 'fakes.dart';
import 'native_phone_auth_test.dart'
    show FakePhoneDriver, nativeAdmission, syntheticPhone;

void main() {
  for (final code in ['OTP_COOLDOWN', 'OTP_RATE_LIMITED']) {
    test('$code expires without automatically requesting another code',
        () async {
      var now = DateTime.utc(2026, 11, 20);
      final api = FakeApi(), driver = FakePhoneDriver();
      final identity = NativeFirebaseIdentityClient(driver: driver);
      var admissions = 0;
      api.interceptor = (method, path, body) async {
        expect(path, '/auth/firebase/admissions');
        admissions++;
        if (admissions == 1) {
          throw ApiFailure(code, 'Wait.', status: 429, retryAfterSeconds: 255);
        }
        return nativeAdmission(now);
      };
      final flow = PhoneSignIn(
          api: api,
          firebase: identity,
          deviceId: () => 'fixture-device',
          clock: () => now,
          onAuthenticated: (_, __) async {});
      addTearDown(flow.dispose);
      addTearDown(identity.close);
      flow.editPhone(syntheticPhone);
      flow.setConsent(true);
      await flow.requestCode();
      final deadline = flow.retryAt;
      expect(flow.errorCode, code);
      expect(flow.retrySeconds, 255);
      expect(flow.canRequest, false);
      expect(driver.sends, 0);

      now = now.add(const Duration(seconds: 254, milliseconds: 500));
      flow.tick();
      expect(flow.retrySeconds, 1);
      expect(flow.errorCode, code);
      expect(flow.canRequest, false);
      if (code == 'OTP_COOLDOWN') await flow.requestCode();
      expect(admissions, 1);
      expect(driver.sends, 0);
      expect(flow.retryAt, deadline);

      now = now.add(const Duration(milliseconds: 500));
      flow.tick();
      expect(flow.retrySeconds, 0);
      expect(flow.errorCode, isNull);
      expect(flow.canRequest, true);
      expect(flow.retryAt, deadline);
      flow.tick();
      expect(admissions, 1);
      expect(driver.sends, 0);

      await flow.requestCode();
      expect(admissions, 2);
      expect(driver.sends, 1);
    });
  }

  test('provider throttling survives the app admission cooldown expiry',
      () async {
    var now = DateTime.utc(2026, 11, 20);
    final api = FakeApi(), driver = FakePhoneDriver();
    final identity = NativeFirebaseIdentityClient(driver: driver);
    api.interceptor = (_, __, ___) async => nativeAdmission(now);
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'fixture-device',
        clock: () => now,
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    addTearDown(identity.close);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    driver.fail!('PHONE_PROVIDER_LIMIT');
    now = now.add(const Duration(seconds: 61));
    flow.tick();
    expect(flow.retrySeconds, 0);
    expect(flow.errorCode, 'PHONE_PROVIDER_LIMIT');
    expect(driver.sends, 1);
    expect(api.requests.length, 1);
  });

  test('old deadline cannot clear a later throttle with unknown retry time',
      () async {
    var now = DateTime.utc(2026, 11, 20);
    final api = FakeApi(), driver = FakePhoneDriver();
    final identity = NativeFirebaseIdentityClient(driver: driver);
    var admissions = 0;
    api.interceptor = (_, __, ___) async {
      admissions++;
      throw ApiFailure('OTP_RATE_LIMITED', 'Wait.',
          status: 429, retryAfterSeconds: admissions == 1 ? 60 : null);
    };
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'fixture-device',
        clock: () => now,
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    addTearDown(identity.close);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    now = now.add(const Duration(seconds: 61));
    await flow.requestCode();
    flow.tick();
    expect(flow.errorCode, 'OTP_RATE_LIMITED');
    expect(admissions, 2);
    expect(driver.sends, 0);
  });

  for (final failure in [
    const ApiFailure('OFFLINE', 'Unavailable.', retryAfterSeconds: 60),
    const ApiFailure('OTP_COOLDOWN', 'Wait.', status: 429),
  ]) {
    test('tick preserves ${failure.code} without an expired matching deadline',
        () async {
      var now = DateTime.utc(2026, 11, 20);
      final api = FakeApi(), driver = FakePhoneDriver();
      final identity = NativeFirebaseIdentityClient(driver: driver);
      api.interceptor = (_, __, ___) async => throw failure;
      final flow = PhoneSignIn(
          api: api,
          firebase: identity,
          deviceId: () => 'fixture-device',
          clock: () => now,
          onAuthenticated: (_, __) async {});
      addTearDown(flow.dispose);
      addTearDown(identity.close);
      flow.editPhone(syntheticPhone);
      flow.setConsent(true);
      await flow.requestCode();
      now = now.add(const Duration(seconds: 61));
      flow.tick();
      expect(flow.errorCode, failure.code);
      expect(driver.sends, 0);
      expect(api.requests.length, 1);
    });
  }
}
