import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/listener_application_screen.dart';
import 'fakes.dart';
import 'listener_application_test.dart' show applicationJson, FakePicker;
import 'listener_review_result_test.dart' show reviewResult;

Future<AppController> mountApplication(WidgetTester tester,
    {String locale = 'en', String status = 'draft', Json? review}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = FakeApi()..token = 'token';
  api.interceptor = (m, p, b) async => p.endsWith('/review')
      ? review ??
          {'applicationId': 'application-id', 'state': status, 'review': null}
      : m == 'GET'
          ? {
              'application':
                  applicationJson(state: status, uploadId: 'upload-id')
            }
          : applicationJson(state: status, consent: false);
  final app = AppController(
      api: api,
      store: MemoryStore(),
      audio: FakeAudio(),
      samplePicker: FakePicker(),
      startTimers: false)
    ..user = UserProfile.fromJson(userJson())
    ..locale = locale;
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(
                  size: Size(360, 800), textScaler: TextScaler.linear(2)),
              child: const ListenerApplicationScreen()))));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('Tamil review result and pending access fit at double text',
      (tester) async {
    final app = await mountApplication(tester,
        locale: 'ta', status: 'approved', review: reviewResult());
    await tester.scrollUntilVisible(
        find.byKey(const Key('application-review-message')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('சோதனை ஆய்வு முடிவு.'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('application-review-entitlement')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(app.user!.listenerApproved, false);
    expect(app.user!.online, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Tamil draft is usable at double text and consent withdrawal disables submit',
      (tester) async {
    final app = await mountApplication(tester, locale: 'ta');
    expect(app.listenerApplication.canSubmit, true);
    await tester.scrollUntilVisible(
        find.byKey(const Key('application-consent')), 500,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('application-consent'))),
        alignment: 0.2);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('application-consent')));
    await tester.pumpAndSettle();
    expect(app.listenerApplication.consent, false);
    await tester.scrollUntilVisible(
        find.byKey(const Key('application-submit')), 500,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('application-submit')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'approved review retains decision while explicit consent removal requires confirmation',
      (tester) async {
    final app = await mountApplication(tester, status: 'approved');
    await tester.scrollUntilVisible(
        find.text('Remove sample and withdraw consent'), 500,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        tester.element(find.text('Remove sample and withdraw consent')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove sample and withdraw consent'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw voice consent?'), findsOneWidget);
    await tester.tap(find.text('Keep application'));
    await tester.pumpAndSettle();
    expect(app.listenerApplication.consent, true);
    await tester.tap(find.text('Remove sample and withdraw consent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw consent'));
    await tester.pumpAndSettle();
    expect(app.listenerApplication.consent, false);
    expect(app.listenerApplication.application!['state'], 'approved');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'submitted status does not offer editing or imply Listener entitlement',
      (tester) async {
    final app =
        await mountApplication(tester, status: 'submitted', locale: 'ta');
    await tester.scrollUntilVisible(
        find.byKey(const Key('application-bio')), 500,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('application-bio')))
            .enabled,
        false);
    expect(app.user!.listenerApproved, false);
    expect(find.byKey(const Key('application-submit')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
