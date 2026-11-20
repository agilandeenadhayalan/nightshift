import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/staff_session.dart';
import 'package:nightshift/core/staff_transport.dart';
import 'package:nightshift/core/staff_workspace.dart';
import 'staff_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStaffCookies cookies;
  late FakeStaffTransport transport;
  late StaffWorkspace model;
  Object? owner;
  var foreground = true;
  var now = staffNow;
  Future<String> Function() proof = () async => 'synthetic-native-proof';
  setUp(() {
    owner = staffOwner;
    foreground = true;
    now = staffNow;
    proof = () async => 'synthetic-native-proof';
    cookies = FakeStaffCookies();
    transport = FakeStaffTransport();
    model = StaffWorkspace(
        identity: () => owner,
        ownerId: () => owner as String?,
        enabled: () => foreground && owner != null,
        proof: () => proof(),
        cookies: cookies,
        transport: transport,
        now: () => now,
        startTimer: false);
  });
  tearDown(() => model.dispose());

  test(
      'only approved exchange installs opaque capability, expiry closes without retry',
      () async {
    await model.open();
    expect(model.ready, true);
    expect(cookies.installed, opaque('a'));
    expect(model.origin.toString(), 'https://staff.example');
    expect(transport.calls, [
      StaffOperation.currentRequest,
      StaffOperation.challenge,
      StaffOperation.exchange
    ]);
    now = now.add(const Duration(minutes: 30));
    model.tick();
    expect(model.ready, false);
    expect(model.error?.code, 'STAFF_SESSION_EXPIRED');
    expect(transport.calls.length, 3);
  });
  test(
      'denied account requires explicit pending request and exposes only own reference',
      () async {
    transport.approved = false;
    await model.open();
    expect(model.canRequest, true);
    expect(cookies.installs, 0);
    expect(transport.calls.contains(StaffOperation.accessRequest), false);
    await model.requestAccess();
    expect(model.accessRequest?.accountReference, staffOwner);
    expect(model.accessRequest?.status, 'pending');
    expect(model.ready, false);
    expect(model.canRequest, false);
  });
  test(
      'lost access request is recovered by read, never automatically resubmitted',
      () async {
    transport.approved = false;
    await model.open();
    transport.handler = (operation) async {
      if (operation == StaffOperation.accessRequest) {
        transport.savedReceipt = receipt();
        throw const ApiFailure('STAFF_CONNECTION_FAILED', '');
      }
      return transport.response(operation);
    };
    await model.requestAccess();
    expect(model.accessRequest, null);
    await model.open();
    expect(model.accessRequest?.requestId, requestId);
    expect(
        transport.calls
            .where((op) => op == StaffOperation.accessRequest)
            .length,
        1);
  });
  test('proof awaited across account switch cannot dispatch request', () async {
    final gate = Completer<String>();
    proof = () => gate.future;
    final opening = model.open();
    await Future<void>.delayed(Duration.zero);
    owner = otherStaffOwner;
    model.reconcile();
    gate.complete('old-proof');
    await opening;
    expect(transport.calls, isEmpty);
    expect(model.ready, false);
  });
  test('late exchange after logout cannot install cookie', () async {
    final gate = Completer<StaffResponse>(), reached = Completer<void>();
    transport.handler = (operation) async {
      if (operation == StaffOperation.exchange) {
        reached.complete();
        return gate.future;
      }
      return transport.response(operation);
    };
    final opening = model.open();
    await reached.future;
    owner = null;
    model.reconcile();
    gate.complete(transport.response(StaffOperation.exchange));
    await opening;
    expect(cookies.installs, 0);
    expect(model.ready, false);
  });
  test('owner changes during native install never exposes browser', () async {
    final gate = Completer<void>();
    cookies.installGate = gate.future;
    final opening = model.open();
    while (cookies.installs == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    owner = otherStaffOwner;
    model.reconcile();
    gate.complete();
    await opening;
    expect(model.ready, false);
    expect(cookies.installed, null);
  });
  test('background closes staff and foreground does not automatically reopen',
      () async {
    await model.open();
    foreground = false;
    model.reconcile();
    expect(model.ready, false);
    foreground = true;
    model.reconcile();
    model.tick();
    expect(model.ready, false);
    expect(transport.calls.length, 3);
  });
  test('wrong owner pending receipt and malformed capability fail closed',
      () async {
    transport.savedReceipt = receipt(owner: otherStaffOwner);
    await model.open();
    expect(model.ready, false);
    expect(cookies.installs, 0);
    expect(model.accessRequest, null);
    transport.savedReceipt = null;
    transport.handler = (operation) async {
      final response = transport.response(operation);
      return operation == StaffOperation.exchange
          ? StaffResponse(response.body,
              [cookie('__Host-nightshift_staff', opaque('a'), 1801)])
          : response;
    };
    await model.open();
    expect(model.ready, false);
    expect(cookies.installs, 0);
  });
  test('fresh sign-in requirement never requests SMS or grants access',
      () async {
    transport.handler = (_) async =>
        throw const ApiFailure('STAFF_FRESH_SIGN_IN_REQUIRED', '', status: 403);
    await model.open();
    expect(model.error?.code, 'STAFF_FRESH_SIGN_IN_REQUIRED');
    expect(model.canRequest, false);
    expect(cookies.installs, 0);
    expect(transport.calls.length, 1);
  });
  test('cookie scopes and duplicate attributes are rejected', () {
    final valid = cookie('__Host-nightshift_staff', opaque('a'), 1800);
    for (final bad in [
      valid.replaceFirst('; HttpOnly', ''),
      '$valid; Domain=staff.example',
      '$valid; Path=/other',
      '$valid; Max-Age=1',
      valid.replaceFirst('Strict', 'None')
    ]) {
      expect(() => staffCookie([bad], '__Host-nightshift_staff', 1800),
          throwsA(isA<ApiFailure>()));
    }
    expect(() => staffCookie([valid, valid], '__Host-nightshift_staff', 1800),
        throwsA(isA<ApiFailure>()));
  });
  test('native bridge origin mismatch never receives capability', () async {
    const channel = MethodChannel('test/staff-configuration');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'origin': 'https://other.example', 'generation': 8};
    });
    final bridge =
        NativeStaffCookies(origin: 'https://staff.example', channel: channel);
    await expectLater(
        bridge.install(
            opaque('a'), DateTime.now().toUtc().add(const Duration(minutes: 1)),
            isCurrent: () => true),
        throwsA(isA<ApiFailure>()));
    expect(calls.map((c) => c.method), ['configuration']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('clear supersedes pending bridge install with monotonic generations',
      () async {
    const channel = MethodChannel('test/staff-serialization');
    final gate = Completer<void>(), reached = Completer<void>();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'configuration') {
        return {'origin': 'https://staff.example', 'generation': 40};
      }
      if (call.method == 'install') {
        reached.complete();
        await gate.future;
      }
      return null;
    });
    final bridge =
        NativeStaffCookies(origin: 'https://staff.example', channel: channel);
    final installation = bridge.install(
        opaque('a'), DateTime.now().toUtc().add(const Duration(minutes: 1)),
        isCurrent: () => true);
    final failed = expectLater(installation, throwsA(isA<ApiFailure>()));
    await reached.future;
    await bridge.clear();
    gate.complete();
    await failed;
    expect(calls[1].arguments['generation'], 41);
    expect(calls[2].arguments['generation'], 42);
    expect(
        calls[1].arguments.keys.toSet(), {'token', 'expiresAt', 'generation'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
