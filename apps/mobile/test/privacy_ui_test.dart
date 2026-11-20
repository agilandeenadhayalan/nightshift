import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/privacy_screens.dart';
import 'fakes.dart';
import 'account_privacy_test.dart' show privacyNotice, deletionReceipt;

Future<AppController> mountPrivacy(WidgetTester tester, Widget child,
    {String locale = 'en',
    MemoryStore? receiptStore,
    bool signedIn = true}) async {
  final api = FakeApi();
  api.interceptor = (m, p, b) async {
    if (p == '/me/consents') {
      return {
        'items': [
          {
            'id': 'event',
            'purpose': 'adult_onboarding',
            'noticeVersion': 'adult-onboarding-v1',
            'granted': true,
            'createdAt': '2026-11-20T09:00:00Z'
          }
        ]
      };
    }
    if (p == '/me/deletion-notice') return privacyNotice;
    if (p == '/me/deletion-requests') return deletionReceipt(held: true);
    return null;
  };
  final app = AppController(
      api: api,
      store: receiptStore ?? MemoryStore(),
      audio: FakeAudio(),
      startTimers: false)
    ..user = signedIn ? UserProfile.fromJson(userJson()) : null
    ..initializing = false
    ..locale = locale;
  await app.privacy.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: child))));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  testWidgets('deletion action requires a separate unchecked confirmation',
      (tester) async {
    final app = await mountPrivacy(tester, const PrivacyScreen());
    await tester.scrollUntilVisible(find.text('Review deletion request'), 600,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Review deletion request'));
    await tester.pumpAndSettle();
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit request'));
    expect(submit.onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
        (app.api as FakeApi)
            .requests
            .where((r) => r['path'] == '/me/deletion-requests'),
        isEmpty);
  });
  testWidgets(
      'confirmation opened for one account cannot authorize another account',
      (tester) async {
    final app = await mountPrivacy(tester, const PrivacyScreen());
    await tester.scrollUntilVisible(find.text('Review deletion request'), 600,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Review deletion request'));
    await tester.pumpAndSettle();
    app.user = UserProfile.fromJson({...userJson(), 'id': 'account-b'});
    app.api.token = 'account-b-token';
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();
    expect(app.privacy.errorCode, 'PRIVATE_SESSION_CHANGED');
    expect(
        (app.api as FakeApi)
            .requests
            .where((request) => request['path'] == '/me/deletion-requests'),
        isEmpty);
    expect((app.store as MemoryStore).values['deletionReceipt'], isNull);
    expect(app.user?.id, 'account-b');
    expect(app.api.token, 'account-b-token');
  });
  testWidgets('listener review consent has a readable purpose label',
      (tester) async {
    final app = await mountPrivacy(tester, const PrivacyScreen());
    app.privacy.consents = [
      {
        'purpose': 'listener-review-material',
        'noticeVersion': 'listener-review-v1',
        'granted': true,
        'createdAt': '2026-11-20T09:00:00Z'
      }
    ];
    await app.setLocale('en');
    await tester.pumpAndSettle();
    expect(find.text('Listener review sample'), findsOneWidget);
  });
  testWidgets(
      'Tamil receipt distinguishes scrubbed profile from held evidence at 2x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app =
        await mountPrivacy(tester, const DeletionStatusScreen(), locale: 'ta');
    app.privacy.receipt = deletionReceipt(held: true);
    await app.setLocale('ta');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('கட்டுப்படுத்தப்பட்ட பதிவுகள் தக்கவைக்கப்பட்டுள்ளன'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('கட்டுப்படுத்தப்பட்ட பதிவுகள் தக்கவைக்கப்பட்டுள்ளன'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('கோரிக்கை நிலையை சரிபார்'), 500,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'signed-out receipt selector preserves capabilities without displaying owner IDs or secrets',
      (tester) async {
    final store = MemoryStore();
    store.values['deletionReceipt'] = jsonEncode({
      'version': 2,
      'receipts': [
        {
          'ownerId': 'private-owner-a',
          'origin': 'https://first.example.test',
          'receiptToken': 'a' * 64
        },
        {
          'ownerId': 'private-owner-b',
          'origin': 'https://second.example.test',
          'receiptToken': 'b' * 64
        }
      ]
    });
    final app = await mountPrivacy(tester, const DeletionStatusScreen(),
        receiptStore: store, signedIn: false);
    expect(find.byKey(const Key('deletion-receipt-selector')), findsOneWidget);
    expect(app.privacy.savedReceiptChoices.length, 2);
    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ');
    expect(visibleText, isNot(contains('private-owner-a')));
    expect(visibleText, isNot(contains('private-owner-b')));
    expect(visibleText, isNot(contains('a' * 64)));
    expect(visibleText, isNot(contains('b' * 64)));
    await tester
        .ensureVisible(find.byKey(const Key('deletion-receipt-selector')));
    await tester.tap(find.byKey(const Key('deletion-receipt-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved request 1 · first.example.test').last);
    await tester.pumpAndSettle();
    expect(app.privacy.selectedReceiptIndex, 0);
    expect(app.privacy.receipt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in privacy screen does not show another account receipt',
      (tester) async {
    final store = MemoryStore();
    store.values['deletionReceipt'] = jsonEncode({
      'ownerId': 'different-owner',
      'origin': 'https://first.example.test',
      'receiptToken': 'a' * 64
    });
    final app = await mountPrivacy(tester, const DeletionStatusScreen(),
        receiptStore: store);
    expect(app.privacy.savedReceiptChoices, isEmpty);
    expect(find.byKey(const Key('deletion-receipt-selector')), findsNothing);
    expect(
        find.text('There is no saved receipt on this device.'), findsOneWidget);
  });
}
