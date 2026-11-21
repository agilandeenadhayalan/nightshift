import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/call_invitations.dart';
import 'package:nightshift/core/models.dart';

const registrationId = '30000000-0000-4000-8000-000000000001';
const bindingId = '40000000-0000-4000-8000-000000000001';
final server = DateTime.utc(2026, 11, 21);
Json receipt({String state = 'prepared', int version = 1}) => {
      'id': registrationId,
      'version': version,
      'bindingId': bindingId,
      'targetKind': 'fcm_token',
      'state': state,
      'backgroundInvitations': state == 'active',
      'serverTime': server.toIso8601String(),
      'leaseExpiresAt': server
          .add(Duration(minutes: state == 'prepared' ? 5 : 30))
          .toIso8601String(),
      'testOnly': true,
    };

class FakeInvitationDevice extends InvitationDevice {
  String? owner, binding;
  int generation = 1, installs = 0, clears = 0, tokens = 0, permissions = 0;
  bool granted = true, installFails = false;
  Completer<void>? permissionGate, installGate;
  Json? hint;
  InvitationCapability get capability => InvitationCapability(
      available: true,
      permission: granted,
      channelEnabled: granted,
      generation: generation,
      bindingId: binding);
  @override
  Future<InvitationCapability> synchronize(
      String? ownerKey, String locale) async {
    if (owner != ownerKey) {
      owner = ownerKey;
      binding = null;
      generation++;
    }
    return capability;
  }

  @override
  Future<InvitationCapability> requestPermission(int generation) async {
    permissions++;
    await permissionGate?.future;
    return capability;
  }

  @override
  Future<String> token(int generation) async {
    tokens++;
    return 'synthetic-fcm-token';
  }

  @override
  Future<void> install(int generation, PushRegistration registration,
      int requestElapsedMs) async {
    installs++;
    await installGate?.future;
    if (installFails || generation != this.generation) {
      throw StateError('storage');
    }
    binding = registration.bindingId;
  }

  @override
  Future<void> clear(int generation) async {
    clears++;
    if (generation == this.generation) {
      binding = null;
      this.generation++;
    }
  }

  @override
  Future<Json?> takeOpen(int generation) async {
    final saved = hint;
    hint = null;
    return saved;
  }
}

class InvitationApi extends NightShiftApi {
  InvitationApi() {
    baseUrl = 'https://private.example';
    token = 'synthetic';
  }
  Json? current;
  final requests = <({String method, String path, Json? body, String? key})>[];
  Future<Json> Function(String, Json?)? action;
  Completer<void>? readGate;
  @override
  Future<Json> privateRequest(String method, String path,
      {required String origin,
      required bool Function() isCurrent,
      Json? body,
      String? idempotencyKey,
      dynamic sample,
      String? uploadToken}) async {
    if (method == 'GET') await readGate?.future;
    if (!isCurrent()) {
      throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Changed');
    }
    requests.add((
      method: method,
      path: path,
      body: body == null ? null : Map.of(body),
      key: idempotencyKey
    ));
    if (method == 'GET') return {'registration': current};
    if (action != null) return action!(path, body);
    current = receipt(
        state: method == 'DELETE'
            ? 'revoked'
            : path.endsWith('activate')
                ? 'active'
                : 'prepared');
    return current!;
  }
}

class Rig {
  final api = InvitationApi(), device = FakeInvitationDevice();
  Object? owner = 'A';
  bool visible = true, eligible = true;
  int ms = 0, wallShift = 0, opened = 0;
  late final model = CallInvitations(
      api: api,
      identity: () => owner,
      ownerKey: () => owner?.toString(),
      eligible: () => eligible && owner != null,
      foreground: () => visible,
      locale: () => 'en',
      device: device,
      now: () => server.add(Duration(milliseconds: ms + wallShift)),
      elapsed: () => ms,
      startTimer: false,
      onOpen: (_) async {
        opened++;
      });
  void close() {
    model.dispose();
    api.close();
  }
}

void main() {
  test(
      'prepare is durably bound before activation; explicit lease does not auto renew',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.api.action = (path, body) async {
      if (path.endsWith('activate')) expect(r.device.binding, bindingId);
      return r.api.current =
          receipt(state: path.endsWith('activate') ? 'active' : 'prepared');
    };
    await r.model.enable(consent: true);
    expect(r.model.active, isTrue);
    expect(r.device.installs, 2);
    expect(r.api.requests.where((v) => v.method != 'GET').length, 2);
    r.ms = 1800001;
    r.model.tick();
    await Future<void>.delayed(Duration.zero);
    expect(r.model.active, isFalse);
    expect(r.device.binding, isNull);
    expect(r.api.requests.where((v) => v.method != 'GET').length, 2);
  });
  test('missing consent and denied channel never register a token', () async {
    final r = Rig();
    addTearDown(r.close);
    await r.model.enable(consent: false);
    expect(r.api.requests, isEmpty);
    r.device.granted = false;
    await r.model.enable(consent: true);
    expect(r.device.tokens, 0);
    expect(r.model.error?.code, 'PUSH_PERMISSION_REQUIRED');
  });
  test(
      'binding write failure cannot activate; retry requires successful read and explicit action',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.device.installFails = true;
    await r.model.enable(consent: true);
    expect(r.api.requests.any((v) => v.path.endsWith('activate')), isFalse);
    expect(r.model.uncertain, 'prepare');
    expect(r.model.retryAllowed, isFalse);
    await r.model.recover();
    expect(r.model.retryAllowed, isTrue);
    final key = r.api.requests.singleWhere((v) => v.method == 'PUT').key;
    r.device.installFails = false;
    await r.model.retry();
    expect(r.api.requests.where((v) => v.method == 'PUT').map((v) => v.key),
        [key, key]);
    expect(r.model.active, isTrue);
  });
  test(
      'lost activation response recovers confirmed active lease without another mutation',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.api.action = (path, body) async {
      r.api.current =
          receipt(state: path.endsWith('activate') ? 'active' : 'prepared');
      if (path.endsWith('activate')) throw const ApiFailure('OFFLINE', 'Lost');
      return r.api.current!;
    };
    await r.model.enable(consent: true);
    expect(r.model.uncertain, 'activate');
    expect(r.model.active, isFalse);
    await r.model.recover();
    expect(r.model.active, isTrue);
    expect(r.model.uncertain, isNull);
    expect(r.api.requests.where((v) => v.path.endsWith('activate')).length, 1);
  });
  test('unknown revoke cannot re-enable from an active read', () async {
    final r = Rig();
    addTearDown(r.close);
    await r.model.enable(consent: true);
    r.api.action = (_, __) async => throw const ApiFailure('OFFLINE', 'Lost');
    await r.model.disable();
    await r.model.recover();
    expect(r.model.active, isFalse);
    expect(r.device.binding, isNull);
    expect(r.model.uncertain, 'revoke');
    expect(r.model.retryAllowed, isTrue);
  });
  test('confirmed stale CAS settles intent and allows new explicit setup',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.api.action = (_, __) async => throw const ApiFailure(
        'PUSH_REGISTRATION_CHANGED', 'Changed',
        status: 409);
    await r.model.enable(consent: true);
    expect(r.model.uncertain, isNull);
    expect(r.model.retryAllowed, isFalse);
    r.api.action = null;
    await r.model.enable(consent: true);
    expect(r.model.active, isTrue);
  });
  test('expired cached preparation settles retry instead of trapping old key',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.api.action = (_, __) async => throw const ApiFailure('OFFLINE', 'Lost');
    await r.model.enable(consent: true);
    r.api.current = receipt(state: 'expired');
    await r.model.recover();
    r.api.action = (_, __) async => receipt(state: 'expired');
    await r.model.retry();
    expect(r.model.uncertain, isNull);
    expect(r.model.error?.code, 'PUSH_REGISTRATION_CHANGED');
    expect(r.device.installs, 0);
  });
  test(
      'account change during permission cannot register or overwrite new capability',
      () async {
    final r = Rig();
    addTearDown(r.close);
    final gate = r.device.permissionGate = Completer<void>();
    final work = r.model.enable(consent: true);
    while (r.device.permissions == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    r.owner = 'B';
    r.model.invalidate();
    gate.complete();
    await work;
    expect(r.device.tokens, 0);
    expect(r.api.requests.where((v) => v.method != 'GET'), isEmpty);
  });
  test('consent cannot cross owner change while initial status read waits',
      () async {
    final r = Rig();
    addTearDown(r.close);
    final gate = r.api.readGate = Completer<void>();
    final work = r.model.enable(consent: true);
    await Future<void>.delayed(Duration.zero);
    r.owner = 'B';
    gate.complete();
    await work;
    expect(r.device.permissions, 0);
    expect(r.device.tokens, 0);
  });
  test('late binding persistence after logout cannot activate', () async {
    final r = Rig();
    addTearDown(r.close);
    final gate = r.device.installGate = Completer<void>();
    final work = r.model.enable(consent: true);
    while (r.device.installs == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    r.owner = null;
    r.model.invalidate();
    gate.complete();
    await work;
    expect(r.api.requests.any((v) => v.path.endsWith('activate')), isFalse);
    expect(r.model.active, isFalse);
  });
  test('wall rollback and elapsed budget cannot extend confirmed lease',
      () async {
    final r = Rig();
    addTearDown(r.close);
    await r.model.enable(consent: true);
    r.wallShift = -6000;
    expect(r.model.active, isFalse);
    r.model.tick();
    r.wallShift = 0;
    expect(r.model.active, isFalse);
  });
  test('server active receipt without native binding never restores consent',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.api.current = receipt(state: 'active');
    await r.model.recover();
    expect(r.model.active, isFalse);
    expect(r.device.installs, 0);
  });
  test(
      'foreground recovery consumes a native hint but sends no accept or RTC mutation',
      () async {
    final r = Rig();
    addTearDown(r.close);
    r.device.hint = {
      'callId': '10000000-0000-4000-8000-000000000001',
      'callVersion': '1'
    };
    await r.model.recover();
    expect(r.opened, 1);
    expect(r.api.requests.every((v) => v.method == 'GET'), isTrue);
    r.visible = false;
    await r.model.recover();
    expect(r.opened, 1);
  });
  test(
      'registration validation rejects malformed authority and oversized lease',
      () {
    expect(() => PushRegistration.fromJson({...receipt(), 'version': 0}),
        throwsFormatException);
    expect(
        () => PushRegistration.fromJson({
              ...receipt(),
              'leaseExpiresAt':
                  server.add(const Duration(hours: 1)).toIso8601String()
            }),
        throwsFormatException);
    expect(
        () => PushRegistration.fromJson(
            {...receipt(), 'backgroundInvitations': true}),
        throwsFormatException);
  });
}
