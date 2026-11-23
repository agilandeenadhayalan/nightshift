import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/features/redesign/call_designs.dart';
import 'package:nightshift/features/redesign/design_system.dart';
import 'package:nightshift/features/video_view.dart';
import 'fakes.dart';

Future<void> mountDesign(WidgetTester tester, int id,
    {double scale = 1, ProviderContainer? container}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final app = MaterialApp(
      theme: nightshiftTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: CallDesignScreen(designId: id));
  await tester.pumpWidget(container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 190,
      scrollable: find.byType(Scrollable).last, maxScrolls: 20);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final callState in ['ringing', 'connected']) {
    testWidgets(
        '$callState exit action is tappable without scrolling at 800x600',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeApi()..call = callJson(state: callState);
      final app = AppController(
          api: api,
          store: MemoryStore()..values['token'] = 'saved-session',
          audio: FakeAudio(),
          startTimers: false);
      await app.initialize();
      await tester.pumpWidget(ProviderScope(
          overrides: [appControllerProvider.overrideWith((_) => app)],
          child: const NightShiftApp()));
      await tester.pumpAndSettle();
      final action =
          find.text(callState == 'ringing' ? 'Cancel call' : 'End call');
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      final transition = callState == 'ringing' ? 'cancel' : 'end';
      expect(
          api.requests.where(
              (request) => request['path'] == '/calls/call-id/$transition'),
          hasLength(1));
      expect(app.hasCall, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  test('rating choices stay bounded, immutable and local to one design', () {
    final rating = CallDesignController();
    final call = CallDesignController();
    addTearDown(rating.dispose);
    addTearDown(call.dispose);
    rating.rate(6);
    expect(rating.state.rating, 0);
    rating.rate(5);
    rating.toggleTag('Friendly');
    final before = rating.state.tags;
    rating.toggleTag('Clear audio');
    expect(before, {'Friendly'});
    expect(rating.state.tags, {'Friendly', 'Clear audio'});
    rating.selectRating();
    expect(rating.state.ratingSelected, isTrue);
    rating.rate(4);
    expect(rating.state.ratingSelected, isFalse);
    expect(call.state.rating, 0);
  });

  test('local board controls never create earnings or a remote turn', () {
    final controller = CallDesignController();
    addTearDown(controller.dispose);
    for (var i = 0; i < 12; i++) {
      controller.rollPreviewDice();
      expect(controller.state.dice, inInclusiveRange(1, 6));
    }
    expect(controller.state.moves, greaterThan(0));
    expect(controller.state.invitationAccepted, isFalse);
    controller.acceptInvitation();
    expect(controller.state.invitationAccepted, isTrue);
    controller.toggleMute();
    expect(controller.state.muted, isTrue);
    controller.endPreview();
    expect(controller.state.ended, isTrue);
  });

  for (final scale in [1.0, 2.0]) {
    for (final id in CallDesignScreen.designIds) {
      testWidgets('native design $id renders at ${scale}x text',
          (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mountDesign(tester, id, scale: scale);
        expect(find.byType(CallDesignScreen), findsOneWidget);
        expect(find.text('Preview'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -1100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('rating selection explicitly stays unsent', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await mountDesign(tester, 18, container: container);
    await reveal(tester, find.byKey(const ValueKey('rating-4')));
    await tester.tap(find.byKey(const ValueKey('rating-4')));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Keep preview rating'));
    await tester.tap(find.text('Keep preview rating'));
    await tester.pumpAndSettle();
    expect(container.read(callDesignProvider(18)).rating, 4);
    expect(find.text('Rating selected locally. Nothing was submitted.'),
        findsOneWidget);
  });

  testWidgets('game invitation opens only a local board', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await mountDesign(tester, 49, container: container);
    await reveal(tester, find.text('Try local board'));
    await tester.tap(find.text('Try local board'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('roll-preview-dice')));
    await tester.tap(find.byKey(const ValueKey('roll-preview-dice')));
    await tester.pumpAndSettle();
    expect(container.read(callDesignProvider(49)).dice, 2);
    expect(container.read(callDesignProvider(49)).moves, 2);
    expect(find.text('Local moves only · no winnings'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailed-ludo-board')), findsOneWidget);
  });

  test('preview state is cleared when its last screen subscription leaves',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(callDesignProvider(50), (_, __) {});
    container.read(callDesignProvider(50).notifier).toggleMute();
    expect(container.read(callDesignProvider(50)).muted, isTrue);
    subscription.close();
    await container.pump();
    expect(container.read(callDesignProvider(50)).muted, isFalse);
  });

  testWidgets(
      'video preview uses edge-to-edge supplied portraits and local controls',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await mountDesign(tester, 52, container: container);
    final portraits =
        tester.widgetList<AvatarPortrait>(find.byType(AvatarPortrait));
    expect(
        portraits.map((portrait) => portrait.assetPath),
        containsAll([
          'assets/avatars/female/avatar_01.png',
          'assets/avatars/male/avatar_01.png',
        ]));
    final background = find.byType(AvatarPortrait).first;
    expect(tester.getSize(background), const Size(390, 844));
    await reveal(tester, find.byTooltip('Camera on'));
    await tester.tap(find.byTooltip('Camera on'));
    await tester.pumpAndSettle();
    expect(container.read(callDesignProvider(52)).camera, isFalse);
    expect(find.byTooltip('Camera off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live video placeholder only uses the selected avatar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: nightshiftTheme(),
        home: const Scaffold(
            body: SizedBox(
                width: 350,
                child: VideoCameraPane(
                    controller: null,
                    label: 'Companion',
                    placeholder: 'Waiting for video',
                    avatarCode: 'male_04')))));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for video'), findsOneWidget);
    expect(tester.widget<AvatarPortrait>(find.byType(AvatarPortrait)).assetPath,
        'assets/avatars/male/avatar_04.png');
    await tester.pumpWidget(MaterialApp(
        theme: nightshiftTheme(),
        home: const Scaffold(
            body: SizedBox(
                width: 350,
                child: VideoCameraPane(
                    controller: null,
                    label: 'Companion',
                    placeholder: 'Waiting for video')))));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPortrait), findsNothing);
    expect(find.text('Waiting for video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
