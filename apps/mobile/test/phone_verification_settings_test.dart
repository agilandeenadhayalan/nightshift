import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/native_firebase_identity.dart';

void main() {
  for (final debug in [false, true]) {
    for (final requested in [false, true]) {
      test(
          'browser verification debug=$debug requested=$requested keeps verification enabled',
          () async {
        final settings = <Map<String, bool>>[];
        final current = await configurePhoneAppVerification(
            applySettings: (
                {required appVerificationDisabledForTesting,
                required forceRecaptchaFlow}) async {
              settings.add({
                'disabled': appVerificationDisabledForTesting,
                'browser': forceRecaptchaFlow
              });
            },
            isCurrent: () => true,
            debugBuild: debug,
            forceRequested: requested);
        expect(current, true);
        expect(settings, [
          {'disabled': false, 'browser': debug && requested}
        ]);
      });
    }
  }
  test('withdrawing consent during settings prevents verification dispatch',
      () async {
    final pending = Completer<void>();
    var current = true, dispatched = false;
    final operation = () async {
      if (await configurePhoneAppVerification(
          applySettings: (
                  {required appVerificationDisabledForTesting,
                  required forceRecaptchaFlow}) =>
              pending.future,
          isCurrent: () => current,
          debugBuild: true,
          forceRequested: true)) {
        dispatched = true;
      }
    }();
    current = false;
    pending.complete();
    await operation;
    expect(dispatched, false);
  });
  test('settings failure is not automatically retried', () async {
    var attempts = 0;
    await expectLater(
        configurePhoneAppVerification(
            applySettings: (
                {required appVerificationDisabledForTesting,
                required forceRecaptchaFlow}) async {
              attempts++;
              throw StateError('synthetic SDK failure');
            },
            isCurrent: () => true,
            debugBuild: true,
            forceRequested: true),
        throwsStateError);
    expect(attempts, 1);
  });
  test('cancelled attempt does not configure the SDK', () async {
    var attempts = 0;
    final current = await configurePhoneAppVerification(
        applySettings: (
            {required appVerificationDisabledForTesting,
            required forceRecaptchaFlow}) async {
          attempts++;
        },
        isCurrent: () => false,
        debugBuild: true,
        forceRequested: true);
    expect(current, false);
    expect(attempts, 0);
  });
}
