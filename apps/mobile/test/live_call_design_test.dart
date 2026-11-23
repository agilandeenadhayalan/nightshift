import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/screens.dart';
import 'package:nightshift/features/video_view.dart';
import 'call_allowance_ui_test.dart' show mountAllowance;
import 'video_ui_test.dart' show mountVideoApp, videoCallJson;
import 'fakes.dart';

class _RatingRoutes extends NavigatorObserver {
  final removed = <Route<dynamic>>[];
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removed.add(route);
  }
}

void main() {
  testWidgets('the unavailable game board never gates the live End action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (_, api) = await mountAllowance(tester, callJson(state: 'connected'));
    final before = api.requests.length;
    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('Play Ludo together'), findsOneWidget);
    expect(find.text('Games unavailable'), findsOneWidget);
    expect(api.requests.length, before);
    expect(find.text('End call').hitTestable(), findsOneWidget);
    await tester.tap(find.text('End call'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => (r['path'] as String).endsWith('/end')),
        hasLength(1));
  });

  testWidgets('covered feedback closes only its own route after logout',
      (tester) async {
    final api = FakeApi();
    final state = AppController(
        api: api,
        store: MemoryStore()..values['token'] = 'saved',
        audio: FakeAudio(),
        startTimers: false);
    await state.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
    final call = CallSession.fromJson(
        {...callJson(state: 'ended'), 'connectedMs': 60000});
    final routes = _RatingRoutes();
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [routes],
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showCallRating(context, state, call),
                    child: const Text('Feedback'))))));
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    expect(find.text('How was your conversation?'), findsOneWidget);
    final before = api.requests.length;
    await tester.tap(find.text('Rating unavailable'));
    await tester.pumpAndSettle();
    expect(api.requests.length, before);
    final context = tester.element(find.text('How was your conversation?'));
    final ratingRoute = ModalRoute.of(context)!;
    unawaited(showDialog<void>(
        context: context,
        builder: (context) =>
            AlertDialog(title: const Text('Cover dialog'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close cover'))
            ])));
    await tester.pumpAndSettle();
    await state.logout();
    await tester.pumpAndSettle();
    expect(routes.removed, contains(ratingRoute));
    expect(find.text('Cover dialog'), findsOneWidget);
    expect(find.text('How was your conversation?'), findsNothing);
    await tester.tap(find.text('Close cover'));
    await tester.pumpAndSettle();
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
    expect(find.text('Feedback').hitTestable(), findsOneWidget);
  });

  for (final (size, scale, locale) in [
    (const Size(360, 780), 2.0, 'ta'),
    (const Size(800, 600), 1.0, 'en')
  ]) {
    for (final video in [false, true]) {
      testWidgets(
          'live ${video ? 'video' : 'audio'} End remains reachable at $size/$scale',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          return tester.binding.setSurfaceSize(null);
        });
        if (video) {
          final (state, _, _) = await mountVideoApp(tester,
              call: videoCallJson(state: 'connected'), locale: locale);
          await state.joinConsentedVideo();
          await tester.pumpAndSettle();
        } else {
          await mountAllowance(tester, callJson(state: 'connected'),
              locale: locale);
        }
        expect(tester.takeException(), isNull);
        expect(
            find
                .text(locale == 'ta' ? 'அழைப்பை முடி' : 'End call')
                .hitTestable(),
            findsOneWidget);
      });
    }
  }
  testWidgets(
      'live audio keeps speaker, mute and End together in its fixed control row',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mountAllowance(tester, callJson(state: 'connected'));
      final end = find.text('End call');
      expect(end.hitTestable(), findsOneWidget);
      final muteY = tester.getCenter(find.text('Mute')).dy;
      expect((tester.getCenter(end).dy - muteY).abs(), lessThan(12));
      expect(find.text('Report or block').hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel('10000 test coins'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('live video uses the full stage without claiming face detection',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (state, _, _) =
        await mountVideoApp(tester, call: videoCallJson(state: 'connected'));
    await state.joinConsentedVideo();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(VideoCallView)).height, greaterThan(800));
    expect(find.text('End call').hitTestable(), findsOneWidget);
    expect(find.text('Face not visible'), findsNothing);
    expect(find.text('Camera hidden'), findsNothing);
  });
}
