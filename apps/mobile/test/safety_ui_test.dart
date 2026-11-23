import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/app.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/features/screens.dart';
import 'discovery_state_test.dart' show FakeEvents;
import 'fakes.dart';

void main() {
  for (final signOut in [true, false]) {
    testWidgets(
        signOut
            ? 'late safety result after logout cannot show success from a still-mounted old route'
            : 'current-owner safety result still shows success',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = FakeApi()..historyItems = [callJson(state: 'ended')];
      final state = AppController(
          api: api,
          store: MemoryStore()
            ..values.addAll({'token': 'a', 'lastPath': '/history'}),
          audio: FakeAudio(),
          directoryEvents: FakeEvents(),
          startTimers: false);
      await state.initialize();
      await tester.pumpWidget(ProviderScope(
          overrides: [appControllerProvider.overrideWith((_) => state)],
          child: const NightShiftApp()));
      await tester.pumpAndSettle();
      final oldContext = tester.element(find.byType(HistoryScreen));
      final owner = state.accountIdentity;
      final admitted = Completer<void>(), response = Completer<Json>();
      api.interceptor = (method, path, body) async {
        if (method == 'POST' && path == '/reports') {
          admitted.complete();
          return response.future;
        }
        return null;
      };
      await tester.tap(find.byTooltip('Call details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Report or block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report or block'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetic safety report');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      // The submitted request intentionally stays busy; do not wait for its
      // progress animation to settle before changing the session.
      await tester.pump(const Duration(milliseconds: 300));
      await admitted.future;
      expect(state.busy, isTrue);
      expect(api.requests.where((r) => r['path'] == '/reports'), hasLength(1));

      if (signOut) {
        // No pump between real session invalidation and the response. GoRouter
        // has been notified, but its old route is still mounted until a frame.
        await state.logout();
        expect(state.user, isNull);
        expect(api.token, isNull);
        expect(state.accountIdentity, isNot(owner));
      }
      expect(oldContext.mounted, isTrue);
      response.complete({'saved': true});
      for (var i = 0; i < 20; i++) {
        await Future<void>.value();
      }
      expect(state.busy, isFalse);
      expect(state.error, isNull);
      expect(oldContext.mounted, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Your action was saved.'),
          signOut ? findsNothing : findsOneWidget);
      if (signOut) expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
