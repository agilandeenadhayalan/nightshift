import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/account_screens.dart';
import 'package:nightshift/features/redesign/design_system.dart';
import 'fakes.dart';

Json profile(String avatar) => {
      'dateOfBirth': '2000-01-01',
      'displayName': 'Private name',
      'avatarCode': avatar,
      'interfaceLanguage': 'en',
      'languages': ['ta'],
    };

Future<(AppController, FakeApi)> mount(WidgetTester tester,
    {bool editing = false,
    bool settle = true,
    Future<Json?> Function(String, String, Json?)? interceptor}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = FakeApi()
    ..token = 'test-session'
    ..interceptor = interceptor;
  final app = AppController(
      api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
    ..user = UserProfile.fromJson(userJson())
    ..initializing = false
    ..needsOnboarding = !editing
    ..onboardingProfile = profile('moon');
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: MaterialApp(
          theme: nightshiftTheme(), home: OnboardingScreen(editing: editing))));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (app, api);
}

Future<void> openPicker(WidgetTester tester) async {
  final picker = find.byKey(const Key('onboarding-avatar-picker'));
  await tester.scrollUntilVisible(picker, 220,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(picker);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'editing waits for fresh server profile rather than overwriting it from cache',
      (tester) async {
    final pending = Completer<Json?>();
    await mount(tester, editing: true, settle: false,
        interceptor: (method, path, body) async {
      if (method == 'GET' && path == '/me/onboarding') return pending.future;
      return null;
    });
    expect(find.byKey(const Key('onboarding-avatar-picker')), findsNothing);
    expect(find.text('Loading your profile…'), findsOneWidget);
    pending.complete({'required': false, 'profile': profile('female_30')});
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(NightshiftAvatar), 220,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<NightshiftAvatar>(find.byType(NightshiftAvatar))
            .avatarCode,
        'female_30');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed profile load offers retry and cannot submit cached data',
      (tester) async {
    var attempt = 0;
    final (_, api) = await mount(tester, editing: true,
        interceptor: (method, path, body) async {
      if (method == 'GET' && path == '/me/onboarding') {
        if (attempt++ == 0) throw const ApiFailure('OFFLINE', 'Test offline');
        return {'required': false, 'profile': profile('male_30')};
      }
      return null;
    });
    expect(find.byKey(const Key('onboarding-avatar-picker')), findsNothing);
    expect(find.text('Save and continue'), findsNothing);
    expect(api.requests.where((r) => r['method'] == 'PUT'), isEmpty);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(NightshiftAvatar), 220,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<NightshiftAvatar>(find.byType(NightshiftAvatar))
            .avatarCode,
        'male_30');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('portrait choice stays a draft until consent and server save',
      (tester) async {
    final (app, api) = await mount(tester);
    api.interceptor = (method, path, body) async {
      if (method == 'PUT' && path == '/me/onboarding') {
        api.user = {...api.user, 'avatarCode': body!['avatarCode']};
        return {'required': false, 'profile': body};
      }
      return null;
    };
    await openPicker(tester);
    await tester.tap(find.text('Female avatars'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-choice-female_02')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NightshiftAvatar>(find.byType(NightshiftAvatar))
            .avatarCode,
        'female_02');
    expect(app.onboardingProfile!['avatarCode'], 'moon');
    expect(api.requests, isEmpty);
    final save = find.widgetWithText(FilledButton, 'Save and continue');
    await tester.scrollUntilVisible(save, 240,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final writes = api.requests
        .where((r) => r['method'] == 'PUT' && r['path'] == '/me/onboarding');
    expect(writes, hasLength(1));
    expect((writes.single['body'] as Json)['avatarCode'], 'female_02');
    expect(app.onboardingProfile!['avatarCode'], 'female_02');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a picker opened by the previous account cannot change the next draft',
      (tester) async {
    final (app, api) = await mount(tester);
    await openPicker(tester);
    app.user = UserProfile.fromJson(userJson(listener: true));
    app.onboardingProfile = profile('wave');
    await app.setLocale('en');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('avatar-choice-male_01')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NightshiftAvatar>(find.byType(NightshiftAvatar))
            .avatarCode,
        'wave');
    expect(api.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
