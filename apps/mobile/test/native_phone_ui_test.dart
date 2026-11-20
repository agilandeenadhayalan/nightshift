import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/features/account_screens.dart';
import 'fakes.dart';
import 'native_phone_auth_test.dart'
    show FakePhoneDriver, nativeAdmission, syntheticPhone;

void main() {
  testWidgets(
      'Tamil Firebase consent and manual code remain reachable at double text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi(), driver = FakePhoneDriver();
    api.interceptor = (m, p, b) async => nativeAdmission(DateTime.now());
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false)
      ..locale = 'ta';
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => app)],
        child: MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: const PhoneLoginScreen()))));
    app.phoneSignIn.editPhone(syntheticPhone);
    app.phoneSignIn.setConsent(true);
    await app.phoneSignIn.requestCode();
    driver.sent!('fixture-verification', 1);
    driver.timedOut!();
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const Key('phone-code')), 450,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(app.phoneSignIn.canVerify, true);
    expect(app.phoneSignIn.expired, false);
    expect(
        find.text(
            'தானாக குறியீடு படிப்பது முடிந்தது. குறியீட்டை நீங்களே இன்னும் உள்ளிடலாம்.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
