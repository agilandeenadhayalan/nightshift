import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/features/account_screens.dart';
import 'fakes.dart';
import 'account_flow_test.dart' show FakeIdentity;

Future<AppController> mount(WidgetTester tester, Widget page,
    {String locale = 'en'}) async {
  final app = AppController(
      api: FakeApi(),
      store: MemoryStore(),
      audio: FakeAudio(),
      identityClient: FakeIdentity(),
      startTimers: false)
    ..locale = locale;
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(360, 800), textScaler: TextScaler.linear(2)),
              child: page))));
  await tester.pump();
  return app;
}

void main() {
  testWidgets('phone number edit revokes visible consent and pending code',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = await mount(tester, const PhoneLoginScreen());
    await tester.enterText(find.byKey(const Key('phone-number')), '9876543210');
    app.phoneSignIn.setConsent(true);
    await tester.pump();
    expect(app.phoneSignIn.consent, true);
    await tester.enterText(find.byKey(const Key('phone-number')), '9876543211');
    expect(app.phoneSignIn.consent, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Tamil onboarding age rejection is safe at double text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = await mount(tester, const OnboardingScreen(), locale: 'ta');
    app.errorCode = 'ADULT_ONLY';
    app.onboardingProfile = {
      'displayName': '',
      'avatarCode': 'moon',
      'interfaceLanguage': 'ta',
      'languages': ['ta'],
      'dateOfBirth': '2010-01-01'
    };
    await app.setLocale('ta');
    await tester.pump();
    await tester.scrollUntilVisible(
        find.byKey(const Key('onboarding-dob')), 300,
        scrollable: find.byType(Scrollable).first);
    final dob =
        tester.widget<TextField>(find.byKey(const Key('onboarding-dob')));
    expect(dob.enabled, false);
    await tester.scrollUntilVisible(find.text('சேமித்து தொடரவும்'), 600,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(
        find.text(
            'NightShift 18 வயது மற்றும் அதற்கு மேற்பட்ட பெரியவர்களுக்கு மட்டுமே கிடைக்கும்.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
