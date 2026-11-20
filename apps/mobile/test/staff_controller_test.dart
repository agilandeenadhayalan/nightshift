import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/core/staff_workspace.dart';
import 'fakes.dart';
import 'native_phone_auth_test.dart'
    show FakePhoneDriver, nativeSession, nativeBackendSession;
import 'staff_fakes.dart';

void main() {
  test(
      'each explicit staff opening refreshes native proof and registers app session without SMS',
      () async {
    final driver = FakePhoneDriver()
      ..user = nativeSession(token: 'restored-proof');
    final api = FakeApi(), store = MemoryStore(), cookies = FakeStaffCookies();
    final transport = FakeStaffTransport()
      ..currentTime = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true);
    store.values['phoneSession'] = jsonEncode({
      'provider': 'firebase-native',
      'uid': 'opaque-firebase-uid',
      'baseUrl': api.baseUrl
    });
    api.interceptor = (method, path, body) async => path == '/auth/exchange'
        ? {
            ...nativeBackendSession(body!['idToken'] as String),
            'needsOnboarding': false
          }
        : null;
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        staffCookies: cookies,
        staffTransport: transport,
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(driver.refreshes, 1);
    final identity = app.accountIdentity;
    for (final proof in ['fresh-proof-1', 'fresh-proof-2']) {
      driver.user = nativeSession(token: proof);
      await app.staffWorkspace.open();
      expect(app.staffWorkspace.ready, true);
      expect(transport.proofs.last, proof);
      expect(api.token, proof);
      expect(
          api.requests.lastWhere((r) => r['path'] == '/auth/exchange')['body'],
          containsPair('idToken', proof));
      expect(app.accountIdentity, identity);
      app.staffWorkspace.close();
    }
    expect(driver.refreshes, 3);
    expect(driver.sends, 0);
  });
  test('staff closes before a delayed local media logout completes', () async {
    final modelTransport = FakeStaffTransport();
    final audio = DelayedLogoutAudio();
    final app = AppController(
        api: FakeApi(),
        store: MemoryStore(),
        audio: audio,
        staffCookies: FakeStaffCookies(),
        staffTransport: modelTransport,
        startTimers: false);
    addTearDown(app.dispose);
    // Any outstanding staff request must be fenced before media teardown.
    final cancellationCount = modelTransport.cancellations;
    final logout = app.logout();
    await Future<void>.delayed(Duration.zero);
    expect(modelTransport.cancellations, greaterThan(cancellationCount));
    expect(app.staffWorkspace.ready, false);
    audio.gate.complete();
    await logout;
  });
  test(
      'background hides staff before delayed media teardown, resume needs explicit open',
      () async {
    late AppController app;
    final audio = DelayedLogoutAudio();
    final transport = FakeStaffTransport();
    final model = StaffWorkspace(
        identity: () => staffOwner,
        ownerId: () => staffOwner,
        enabled: () => app.foreground,
        proof: () async => 'fixture-proof',
        cookies: FakeStaffCookies(),
        transport: transport,
        now: () => staffNow,
        startTimer: false);
    app = AppController(
        api: FakeApi(),
        store: MemoryStore(),
        audio: audio,
        staffWorkspace: model,
        startTimers: false);
    addTearDown(app.dispose);
    await model.open();
    expect(model.ready, true);
    final background = app.setForeground(false);
    expect(model.ready, false);
    audio.gate.complete();
    await background;
    await app.setForeground(true);
    expect(model.ready, false);
    expect(transport.calls.length, 3);
  });
}

class DelayedLogoutAudio extends FakeAudio {
  final gate = Completer<void>();
  @override
  Future<void> leave() => gate.future;
}
