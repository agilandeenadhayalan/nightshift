import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/features/account_screens.dart';
import 'package:nightshift/features/redesign/entry_components.dart';
import 'package:nightshift/features/redesign/home_components.dart';
import 'package:nightshift/features/screens.dart';
import 'account_flow_test.dart' show FakeIdentity;
import 'fakes.dart';
import 'listener_application_test.dart' show applicationJson, FakePicker;
import 'native_phone_auth_test.dart' show FakePhoneDriver, nativeAdmission;

Future<void> mountRoute(WidgetTester tester, AppController app, String path,
    {double scale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  app.initializing = false;
  app.lastPath = '/home';
  await tester.pumpWidget(ProviderScope(
    overrides: [appControllerProvider.overrideWith((_) => app)],
    child: const NightShiftApp(),
  ));
  await tester.pumpAndSettle();
  final scope =
      ProviderScope.containerOf(tester.element(find.byType(NightShiftApp)));
  scope.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 250,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(target), alignment: .4);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'saved application starts with status and editable bio, not introduction',
      (tester) async {
    final api = FakeApi()..token = 'synthetic-session';
    api.interceptor = (method, path, body) async => path.endsWith('/review')
        ? {'applicationId': 'application-id', 'state': 'draft', 'review': null}
        : path == '/me/listener-application'
            ? {'application': applicationJson()}
            : null;
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        samplePicker: FakePicker(),
        startTimers: false)
      ..user = UserProfile.fromJson(userJson());
    await mountRoute(tester, app, '/listener-application');
    expect(find.byType(NightshiftEntryPortraitScene), findsNothing);
    expect(find.byKey(const Key('application-status')), findsOneWidget);
    expect(
        find.byKey(const Key('application-bio')).hitTestable(), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(const Key('application-bio-guidance'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('30/1000')).dy));
    await tester.enterText(
        find.byKey(const Key('application-bio')), 'A private draft');
    expect(app.listenerApplication.bio, 'A private draft');
    expect(api.requests.every((request) => request['method'] == 'GET'), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'new application retains introduction without granting permission or access',
      (tester) async {
    final api = FakeApi()..token = 'synthetic-session';
    api.interceptor =
        (method, path, body) async => path == '/me/listener-application'
            ? {'application': null}
            : path.endsWith('/review')
                ? {'applicationId': null, 'state': null, 'review': null}
                : null;
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        samplePicker: FakePicker(),
        startTimers: false)
      ..user = UserProfile.fromJson(userJson());
    await mountRoute(tester, app, '/listener-application');
    expect(find.byType(NightshiftEntryPortraitScene), findsOneWidget);
    expect(app.user!.listenerApproved, false);
    expect(api.requests.every((request) => request['method'] == 'GET'), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('routed phone sheet uses one real OTP input and explicit consent',
      (tester) async {
    final api = FakeApi(), driver = FakePhoneDriver();
    api.interceptor = (method, path, body) async =>
        path == '/auth/firebase/admissions'
            ? nativeAdmission(DateTime.now())
            : null;
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    await mountRoute(tester, app, '/phone-login');
    expect(find.byType(NightshiftAuthLayout), findsOneWidget);
    expect(find.byKey(const Key('live-auth-sheet')), findsOneWidget);
    expect(driver.sends, 0);
    await tester.enterText(find.byKey(const Key('phone-number')), '9876543210');
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await reveal(tester, find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(driver.sends, 1);
    driver.sent!('synthetic-code-challenge', 1);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('phone-code')));
    expect(find.byType(NightshiftOtpField), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('otp-cell-$i')), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('phone-code')), '123456');
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('phone-code')))
            .controller!
            .text,
        '123456');
    expect(
        find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == '123456'),
        findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('phone-code')))
            .obscureText,
        true);
    expect(driver.signIns, 0);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(app.phoneSignIn.canVerify, false);
    expect(driver.signIns, 0);
    expect(api.requests.where((r) => r['path'] == '/auth/exchange'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'development login completion after route disposal cannot clear a disposed field',
      (tester) async {
    final pending = Completer<Json?>();
    final api = FakeApi()..user = userJson(listener: true, approved: true);
    api.interceptor = (method, path, body) async =>
        path.startsWith('/snapshot') ? pending.future : null;
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        identityClient: FakeIdentity(),
        startTimers: false);
    await mountRoute(tester, app, '/login');
    expect(find.byType(NightshiftEntryPortraitScene), findsOneWidget);
    await reveal(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listener · approved test B').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Development access key'));
    await tester.enterText(find.byType(TextField).last, 'synthetic-key');
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await reveal(tester, find.text('Continue to NightShift'));
    await tester.tap(find.text('Continue to NightShift'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoginScreen), findsNothing);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(app.isListener, true);
    expect(
        (api.requests.singleWhere((r) => r['path'] == '/auth/dev')['body']
            as Json)['handle'],
        'listener');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final status in ['draft', 'submitted']) {
    testWidgets(
        'routed $status application uses its live design without granting access',
        (tester) async {
      final api = FakeApi()..token = 'synthetic-session';
      api.interceptor = (method, path, body) async => path.endsWith('/review')
          ? {'applicationId': 'application-id', 'state': status, 'review': null}
          : path == '/me/listener-application'
              ? {'application': applicationJson(state: status)}
              : null;
      final app = AppController(
          api: api,
          store: MemoryStore(),
          audio: FakeAudio(),
          samplePicker: FakePicker(),
          startTimers: false)
        ..user = UserProfile.fromJson(userJson());
      await mountRoute(tester, app, '/listener-application', scale: 2);
      expect(
          find.byKey(Key(status == 'submitted'
              ? 'live-application-pending'
              : 'live-application-status')),
          findsOneWidget);
      await reveal(tester, find.byKey(const Key('live-voice-sample')));
      expect(find.byType(NightshiftVoiceSampleVisual), findsOneWidget);
      expect(api.requests.every((r) => r['method'] == 'GET'), true);
      expect(app.user!.listenerApproved, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'routed profile editor uses selected portrait without publishing draft',
      (tester) async {
    final api = FakeApi()..token = 'synthetic-session';
    api.interceptor = (method, path, body) async => path == '/me/onboarding'
        ? {
            'required': false,
            'profile': {
              'dateOfBirth': '2000-01-01',
              'displayName': 'Private nickname',
              'avatarCode': 'female_03',
              'interfaceLanguage': 'ta',
              'languages': ['ta']
            },
          }
        : null;
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..user = UserProfile.fromJson({...userJson(), 'avatarCode': 'male_01'})
      ..locale = 'ta';
    await mountRoute(tester, app, '/edit-profile', scale: 2);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
        tester
            .widget<NightshiftProfileHero>(find.byType(NightshiftProfileHero))
            .avatarCode,
        'female_03');
    await reveal(
        tester, find.byKey(const ValueKey('profile-quick-avatar-female_05')));
    await tester
        .tap(find.byKey(const ValueKey('profile-quick-avatar-female_05')));
    await tester.pump();
    expect(app.user!.avatarCode, 'male_01');
    expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
