import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/staff_session.dart';
import 'package:nightshift/core/staff_transport.dart';
import 'package:nightshift/core/staff_workspace.dart';
import 'package:nightshift/features/staff_workspace_screen.dart';
import 'fakes.dart';
import 'staff_fakes.dart';

void main() {
  test('navigation admits only fixed credential-free staff document', () {
    final origin = Uri.parse('https://staff.example');
    expect(staffNavigationAllowed(origin, 'https://staff.example/'), true);
    expect(staffNavigationAllowed(origin, 'https://staff.example/#main'), true);
    for (final denied in [
      'http://staff.example/',
      'https://other.example/',
      'https://staff.example:444/',
      'https://staff.example/?token=secret',
      'https://name@staff.example/',
      'file:///private',
      'content://private',
      'javascript:alert(1)',
      'data:text/html,private',
      'https://staff.example/api/staff/native/exchange'
    ]) {
      expect(staffNavigationAllowed(origin, denied), false, reason: denied);
    }
    for (final invalid in [
      '',
      'http://staff.example',
      'https://staff.example/',
      'https://staff.example?x=1',
      'https://name@staff.example'
    ]) {
      expect(fixedStaffOrigin(invalid), null);
    }
  });
  testWidgets(
      'Tamil pending access reference fits double text without a third mode',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FakeStaffTransport()
      ..approved = false
      ..savedReceipt = receipt();
    final cookies = FakeStaffCookies();
    final model = StaffWorkspace(
        identity: () => staffOwner,
        ownerId: () => staffOwner,
        enabled: () => true,
        proof: () async => 'fixture-proof',
        cookies: cookies,
        transport: transport,
        now: () => staffNow,
        startTimer: false);
    final app = AppController(
        api: FakeApi(),
        store: MemoryStore(),
        audio: FakeAudio(),
        staffWorkspace: model,
        startTimers: false)
      ..locale = 'ta';
    await tester.pumpWidget(ProviderScope(
        overrides: [appControllerProvider.overrideWith((_) => app)],
        child: MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(
                    size: Size(360, 800), textScaler: TextScaler.linear(2)),
                child: const StaffWorkspaceScreen()))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('அணுகல் கோரிக்கை நிலுவையில் உள்ளது'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('அணுகல் கோரிக்கை நிலுவையில் உள்ளது'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('கணக்கு குறிப்பு: $staffOwner'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('கணக்கு குறிப்பு: $staffOwner'), findsOneWidget);
    expect(find.byType(StaffBrowser), findsNothing);
    expect(cookies.installs, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(model.accessRequest, null);
  });
  for (final code in [
    'STAFF_FRESH_SIGN_IN_REQUIRED',
    'STAFF_UNAUTHENTICATED'
  ]) {
    testWidgets('$code explains fresh SMS sign-in without automatic retry',
        (tester) async {
      final transport = FakeStaffTransport();
      transport.handler = (operation) async {
        if (operation == StaffOperation.exchange) {
          throw ApiFailure(code, '',
              status: code == 'STAFF_UNAUTHENTICATED' ? 401 : 403);
        }
        return transport.response(operation);
      };
      final model = StaffWorkspace(
          identity: () => staffOwner,
          ownerId: () => staffOwner,
          enabled: () => true,
          proof: () async => 'fixture-proof',
          cookies: FakeStaffCookies(),
          transport: transport,
          now: () => staffNow,
          startTimer: false);
      final app = AppController(
          api: FakeApi(),
          store: MemoryStore(),
          audio: FakeAudio(),
          staffWorkspace: model,
          startTimers: false);
      await tester.pumpWidget(ProviderScope(
          overrides: [appControllerProvider.overrideWith((_) => app)],
          child: const MaterialApp(home: StaffWorkspaceScreen())));
      await tester.pumpAndSettle();
      expect(find.textContaining('new SMS code'), findsOneWidget);
      expect(find.text('Request staff access'), findsNothing);
      expect(find.byType(StaffBrowser), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(transport.calls, [
        StaffOperation.currentRequest,
        StaffOperation.challenge,
        StaffOperation.exchange
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
