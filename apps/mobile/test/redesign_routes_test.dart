import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/screens.dart';
import 'package:nightshift/features/redesign/commerce_designs.dart';
import 'package:nightshift/features/redesign/design_catalog.dart';
import 'fakes.dart';

Future<(AppController, ProviderContainer)> mount(WidgetTester tester,
    {bool signedIn = true, bool listener = false}) async {
  final store = MemoryStore();
  if (signedIn) store.values['token'] = 'test-session';
  final api = FakeApi()
    ..user = userJson(listener: listener, approved: listener);
  final app = AppController(
      api: api, store: store, audio: FakeAudio(), startTimers: false);
  await app.initialize();
  await tester.pumpWidget(ProviderScope(
      overrides: [appControllerProvider.overrideWith((_) => app)],
      child: const NightShiftApp()));
  await tester.pumpAndSettle();
  return (
    app,
    ProviderScope.containerOf(tester.element(find.byType(NightShiftApp)))
  );
}

void main() {
  testWidgets(
      'native filter sheet updates discovery and fences a stale owner callback',
      (tester) async {
    final (app, _) = await mount(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Conversation language'), findsOneWidget);
    final toggle =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!;
    toggle(true);
    await tester.pumpAndSettle();
    expect(app.discovery.availableOnly, isTrue);
    await app.logout();
    await tester.pumpAndSettle();
    final requests = (app.api as FakeApi).requests.length;
    toggle(false);
    await tester.pumpAndSettle();
    expect((app.api as FakeApi).requests.length, requests);
  });

  testWidgets('replacement home opens the server-backed wallet in the same app',
      (tester) async {
    final (_, scope) = await mount(tester);
    expect(Theme.of(tester.element(find.byType(HomeScreen))).brightness,
        Brightness.dark);
    await tester.tap(find.byTooltip('Open test wallet'));
    await tester.pumpAndSettle();
    expect(find.byType(CommerceDesignScreen), findsOneWidget);
    expect(
        tester
            .widget<CommerceDesignScreen>(find.byType(CommerceDesignScreen))
            .preview,
        isFalse);
    expect(
        scope
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        '/wallet');
  });

  testWidgets('Customer cannot navigate into Listener earnings',
      (tester) async {
    final (_, scope) = await mount(tester);
    scope.read(routerProvider).go('/earnings');
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(CommerceDesignScreen), findsNothing);
  });

  testWidgets('design review does not grant an unauthenticated wallet route',
      (tester) async {
    final (_, scope) = await mount(tester, signedIn: false);
    scope.read(routerProvider).go('/designs');
    await tester.pumpAndSettle();
    expect(find.byType(DesignCollectionScreen), findsOneWidget);
    scope.read(routerProvider).go('/wallet');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CommerceDesignScreen), findsNothing);
  });

  testWidgets(
      'active call still takes priority over new routes and design review',
      (tester) async {
    final (app, scope) = await mount(tester);
    app.activeCall = CallSession.fromJson(callJson(state: 'connected'));
    for (final path in ['/designs', '/wallet', '/support']) {
      scope.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(find.byType(CallScreen), findsOneWidget);
      expect(scope.read(routerProvider).routeInformationProvider.value.uri.path,
          '/call');
    }
  });
}
