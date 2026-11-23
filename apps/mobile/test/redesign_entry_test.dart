import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/features/redesign/design_system.dart';
import 'package:nightshift/features/redesign/entry_designs.dart';
import 'package:nightshift/features/screens.dart';
import 'package:permission_handler/permission_handler.dart';
import 'account_flow_test.dart' show FakeIdentity;
import 'fakes.dart';

AppController controller(FakeApi api, {String locale = 'en'}) => AppController(
    api: api,
    store: MemoryStore(),
    audio: FakeAudio(),
    identityClient: FakeIdentity(),
    startTimers: false)
  ..locale = locale;

Future<void> mount(WidgetTester tester, AppController app, Widget child,
    Future<PermissionStatus> Function(Permission) permission,
    {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((_) => app),
        entryPermissionRequestProvider.overrideWithValue(permission),
      ],
      child: MaterialApp(
          theme: nightshiftTheme(),
          home: MediaQuery(
            data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(scale)),
            child: child,
          ))));
  await tester.pump();
}

void main() {
  for (final id in [
    1,
    3,
    5,
    7,
    8,
    9,
    13,
    14,
    19,
    23,
    26,
    27,
    28,
    30,
    42,
    47,
    53
  ]) {
    testWidgets(
        'entry design $id renders Tamil 2x without requesting capabilities',
        (tester) async {
      final api = FakeApi();
      var requests = 0;
      final app = controller(api, locale: 'ta');
      await mount(tester, app, EntryDesignScreen(designId: id), (_) async {
        requests++;
        return PermissionStatus.granted;
      }, scale: 2);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(requests, 0);
      expect(api.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'permission is requested once by explicit tap and denial is honest',
      (tester) async {
    final result = Completer<PermissionStatus>();
    final requested = <Permission>[];
    final app = controller(FakeApi());
    await mount(
        tester, app, const EntryDesignScreen(designId: 13, preview: false),
        (permission) {
      requested.add(permission);
      return result.future;
    });
    expect(requested, isEmpty);
    final button = find.byKey(const ValueKey('entry-permission-13'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(requested, [Permission.microphone]);
    result.complete(PermissionStatus.denied);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entry-permission-result-13')),
        findsOneWidget);
    expect(find.textContaining('not granted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test(
      'combined permission stops after account replacement and never reports grant',
      () async {
    Object owner = 'first';
    final pending = Completer<PermissionStatus>();
    final requested = <Permission>[];
    final state = EntryPermissionController((permission) {
      requested.add(permission);
      return pending.future;
    }, () => owner);
    final work = state.request([Permission.camera, Permission.microphone]);
    owner = 'replacement';
    pending.complete(PermissionStatus.granted);
    await work;
    expect(requested, [Permission.camera]);
    expect(state.state.result, isNull);
    expect(state.state.busy, false);
    state.dispose();
  });

  test('combined permission requires both actual grants', () async {
    final state = EntryPermissionController(
        (permission) async => permission == Permission.camera
            ? PermissionStatus.granted
            : PermissionStatus.permanentlyDenied,
        () => 'owner');
    await state.request([Permission.camera, Permission.microphone]);
    expect(state.state.result, 'restricted');
    state.dispose();
  });

  testWidgets('unsupported platforms never simulate Android permission success',
      (tester) async {
    var requests = 0;
    await mount(tester, controller(FakeApi()),
        const EntryDesignScreen(designId: 47, preview: false), (_) async {
      requests++;
      return PermissionStatus.granted;
    });
    final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('entry-permission-47')));
    expect(button.onPressed, isNull);
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'OTP design preview neither sends nor resets a live phone challenge',
      (tester) async {
    final api = FakeApi();
    final app = controller(api);
    app.phoneSignIn.editPhone('9876543210');
    app.phoneSignIn.setConsent(true);
    app.phoneSignIn.challengeId = 'held-challenge';
    final showing = ValueNotifier(true);
    addTearDown(showing.dispose);
    await mount(
        tester,
        app,
        ValueListenableBuilder<bool>(
            valueListenable: showing,
            builder: (_, visible, __) => visible
                ? const EntryDesignScreen(designId: 27)
                : const SizedBox.shrink()),
        (_) async => PermissionStatus.denied);
    await tester.scrollUntilVisible(find.byKey(const Key('phone-code')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('phone-code')), findsOneWidget);
    expect(app.phoneSignIn.challengeId, 'held-challenge');
    expect(api.requests, isEmpty);
    // Keep the provider alive while disposing only the preview route.
    showing.value = false;
    await tester.pump();
    expect(app.phoneSignIn.challengeId, 'held-challenge');
    expect(app.phoneSignIn.consent, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live login opens native introduction without phone requests',
      (tester) async {
    final api = FakeApi();
    await mount(tester, controller(api), const LoginScreen(),
        (_) async => PermissionStatus.denied);
    final intro = find.byKey(const Key('entry-introduction'));
    await tester.ensureVisible(intro);
    await tester.tap(intro);
    await tester.pumpAndSettle();
    expect(find.byType(EntryDesignScreen), findsOneWidget);
    expect(api.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
