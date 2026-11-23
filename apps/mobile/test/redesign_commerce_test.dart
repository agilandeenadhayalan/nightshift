import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/redesign/commerce_designs.dart';
import 'package:nightshift/features/redesign/design_system.dart';

import 'fakes.dart';

AppController _controller(FakeApi api) => AppController(
      api: api,
      store: MemoryStore(),
      audio: FakeAudio(),
      startTimers: false,
    )
      ..initializing = false
      ..user = UserProfile.fromJson(userJson())
      ..snapshotLoaded = true
      ..balance = 6000000
      ..held = 1200000;

Future<void> _mount(
  WidgetTester tester,
  AppController app,
  int id, {
  bool preview = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [appControllerProvider.overrideWith((ref) => app)],
    child: MaterialApp(
      theme: nightshiftTheme(),
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844), textScaler: TextScaler.linear(scale)),
        child: CommerceDesignScreen(designId: id, preview: preview),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'live wallet keeps sample packs secondary and never starts a purchase',
      (tester) async {
    final api = FakeApi();
    final app = _controller(api);
    await _mount(tester, app, 15);
    expect(find.byKey(const Key('commerce-wallet-balance')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const Key('commerce-pack-0')), findsNothing);
    final toggle = find.byKey(const Key('commerce-pack-previews'));
    await tester.scrollUntilVisible(toggle, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('commerce-pack-0')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('commerce-pack-0')));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('commerce-disabled-payment')))
            .onPressed,
        isNull);
    expect(find.text('₹62'), findsNothing);
    expect(api.requests, isEmpty);
  });

  test('drafts are scoped by account and isolated from previews', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = commerceDesignProvider(('account-a', false));
    final second = commerceDesignProvider(('account-b', false));
    final preview = commerceDesignProvider(('account-a', true));
    final subscription = container.listen(first, (_, __) {});
    container.read(first.notifier)
      ..selectBank('HDFC Bank')
      ..searchBanks('HDFC')
      ..selectPack(2)
      ..selectMethod('GPay')
      ..selectSupport('Payment Support');
    expect(container.read(first).bank, 'HDFC Bank');
    expect(container.read(second).bank, isNull);
    expect(container.read(second).supportCategory, isNull);
    expect(container.read(preview).pack, 4);
    container.read(first.notifier).showPackPreviews(true);
    expect(container.read(first).packPreviewsOpen, true);
    expect(container.read(second).packPreviewsOpen, false);
    expect(container.read(preview).packPreviewsOpen, false);
    expect(container.read(preview).method, 'Any UPI app');
    subscription.close();
    await container.pump();
    expect(container.read(first).bank, isNull);
    expect(container.read(first).bankQuery, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    for (final id in [2, 4, 10, 12, 15, 16, 21, 25, 35]) {
      testWidgets(
          'design $id renders at 390px and scale $scale without requests',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FakeApi();
        await _mount(tester, _controller(api), id, preview: true, scale: scale);
        expect(find.textContaining('DESIGN PREVIEW'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(api.requests, isEmpty);
      });
    }
  }

  testWidgets(
      'live wallet uses server test balance and never offers fixture prices',
      (tester) async {
    final api = FakeApi();
    await _mount(tester, _controller(api), 15);
    expect(find.byKey(const Key('commerce-wallet-balance')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const Key('commerce-wallet-balance')),
                matching: find.byType(Text)))
            .data,
        '100');
    expect(find.text('20 held for a call'), findsOneWidget);
    expect(find.text('Flat ₹3000 off'), findsNothing);
    expect(find.text('₹1,055'), findsNothing);
    expect(find.text('133'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('commerce-disabled-payment')))
            .onPressed,
        isNull);
    expect(api.requests, isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('live wallet fits 390px at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, _controller(FakeApi()), 15, scale: scale);
      expect(find.byKey(const Key('commerce-wallet-balance')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bank search and local selection never start payment',
      (tester) async {
    final api = FakeApi();
    final app = _controller(api);
    await _mount(tester, app, 2);
    await tester.enterText(
        find.byKey(const Key('commerce-bank-search')), 'hdfc');
    await tester.pumpAndSettle();
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('ICICI Bank'), findsNothing);
    await tester.tap(find.text('HDFC Bank'));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(CommerceDesignScreen)));
    expect(
        container
            .read(commerceDesignProvider((app.accountIdentity, false)))
            .bank,
        'HDFC Bank');
    expect(api.requests, isEmpty);
  });

  for (final id in [4, 12]) {
    testWidgets('card design $id cannot collect card numbers or CVV',
        (tester) async {
      final api = FakeApi();
      await _mount(tester, _controller(api), id);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Card entry is disabled'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const Key('commerce-disabled-payment')))
              .onPressed,
          isNull);
      expect(api.requests, isEmpty);
    });
  }

  testWidgets('earnings show only current Listener server settlements',
      (tester) async {
    final api = FakeApi();
    final app = _controller(api)
      ..user = UserProfile.fromJson(userJson(listener: true))
      ..historyLoaded = true
      ..history = [
        CallSession.fromJson(callJson(state: 'ended')),
        CallSession.fromJson({
          ...callJson(state: 'ended'),
          'id': 'another-account-call',
          'listenerId': 'another-listener',
          'earningPaise': 999999,
        }),
      ];
    await _mount(tester, app, 10);
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const Key('commerce-test-earnings')),
                matching: find.byType(Text)))
            .data,
        '₹8.33');
    expect(find.text('₹20.35'), findsNothing);
    expect(find.text('Withdrawn'), findsNothing);
    expect(find.textContaining('not redeemable'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('support choice is a draft and cannot submit a ticket',
      (tester) async {
    final api = FakeApi();
    final app = _controller(api);
    await _mount(tester, app, 35);
    await tester.tap(find.text('Payment Support'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.textContaining('No request has been sent'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('commerce-disabled-payment')))
            .onPressed,
        isNull);
    expect(api.requests, isEmpty);
  });

  testWidgets('live status screen does not invent a pending payment',
      (tester) async {
    final api = FakeApi();
    await _mount(tester, _controller(api), 21);
    expect(find.text('No payment in progress'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Payment Processing…'), findsNothing);
    expect(api.requests, isEmpty);
  });

  for (final id in [15, 10, 35, 2, 4, 12, 25]) {
    testWidgets('Tamil live design $id fits 390px at 2x text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeApi();
      final app = _controller(api)
        ..locale = 'ta'
        ..historyLoaded = true;
      await _mount(tester, app, id, scale: 2);
      final title = switch (id) {
        15 => 'பணப்பை',
        10 => 'வருமானம்',
        35 => 'உதவி மற்றும் ஆதரவு',
        2 => 'இணைய வங்கி',
        4 || 12 => 'அட்டை சேர்க்கவும்',
        _ => 'பணம் செலுத்தும் முறைகள்',
      };
      expect(find.text(title), findsWidgets);
      expect(tester.takeException(), isNull);
      if (id == 15) {
        await tester.scrollUntilVisible(
            find.byKey(const Key('commerce-pack-previews')), 250,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.byKey(const Key('commerce-pack-previews')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(const Key('commerce-pack-2')), 250,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('commerce-pack-2')));
        await tester.pumpAndSettle();
        final scope = ProviderScope.containerOf(
            tester.element(find.byType(CommerceDesignScreen)));
        expect(
            scope
                .read(commerceDesignProvider((app.accountIdentity, false)))
                .pack,
            2);
        expect(find.text('450 மாதிரி நாணயங்கள்'), findsOneWidget);
      } else if (id == 35) {
        await tester.scrollUntilVisible(find.text('பணப்பரிவர்த்தனை உதவி'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('பணப்பரிவர்த்தனை உதவி'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.text('உதவி கோரிக்கை அனுப்ப இயலாது'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.textContaining('எந்தக் கோரிக்கையும் அனுப்பப்படவில்லை'),
            findsOneWidget);
      } else if (id == 2) {
        expect(find.text('உங்கள் வங்கியைத் தேடுங்கள்'), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('commerce-bank-search')), 'HDFC');
        await tester.pumpAndSettle();
        await tester.tap(find.text('HDFC Bank'));
        await tester.pumpAndSettle();
      } else if (id == 25) {
        await tester.scrollUntilVisible(find.text('GPay'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('GPay'));
        await tester.pumpAndSettle();
      } else if (id == 4 || id == 12) {
        expect(find.byType(EditableText), findsNothing);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.requests, isEmpty);
    });
  }
}
