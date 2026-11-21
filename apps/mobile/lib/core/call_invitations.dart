import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'models.dart';

final _invitationId = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

class PushRegistration {
  PushRegistration.fromJson(Json value)
      : id = value['id'] as String,
        version = value['version'] as int,
        bindingId = value['bindingId'] as String,
        state = value['state'] as String,
        backgroundInvitations = value['backgroundInvitations'] as bool,
        serverTime = DateTime.parse(value['serverTime'] as String),
        expiresAt = value['leaseExpiresAt'] == null
            ? null
            : DateTime.parse(value['leaseExpiresAt'] as String) {
    if (!_invitationId.hasMatch(id) ||
        !_invitationId.hasMatch(bindingId) ||
        version < 1 ||
        !['prepared', 'active', 'revoked', 'expired'].contains(state) ||
        value['targetKind'] != 'fcm_token' ||
        value['testOnly'] != true ||
        (backgroundInvitations && state != 'active') ||
        (['prepared', 'active'].contains(state) && expiresAt == null) ||
        (expiresAt?.difference(serverTime).inMilliseconds ?? 0) >
            (state == 'prepared' ? 300000 : 1800000)) {
      throw const FormatException('Invalid invitation registration');
    }
  }
  final String id, bindingId, state;
  final int version;
  final bool backgroundInvitations;
  final DateTime serverTime;
  final DateTime? expiresAt;
  bool same(PushRegistration? other) =>
      id == other?.id &&
      version == other?.version &&
      bindingId == other?.bindingId;
  Json get binding => {
        'registrationId': id,
        'registrationVersion': version,
        'bindingId': bindingId,
        'serverTime': serverTime.toUtc().toIso8601String(),
        'leaseExpiresAt': expiresAt?.toUtc().toIso8601String(),
      };
}

class InvitationCapability {
  const InvitationCapability(
      {this.available = false,
      this.permission = false,
      this.channelEnabled = false,
      this.generation = 0,
      this.bindingId});
  factory InvitationCapability.fromJson(Json value) => InvitationCapability(
      available: value['available'] == true,
      permission: value['permission'] == true,
      channelEnabled: value['channelEnabled'] == true,
      generation: value['generation'] as int,
      bindingId: value['bindingId'] as String?);
  final bool available, permission, channelEnabled;
  final int generation;
  final String? bindingId;
  bool get granted => available && permission && channelEnabled;
}

abstract class InvitationDevice {
  VoidCallback? onChanged;
  Future<InvitationCapability> synchronize(String? ownerKey, String locale);
  Future<InvitationCapability> requestPermission(int generation);
  Future<String> token(int generation);
  Future<void> install(
      int generation, PushRegistration registration, int requestElapsedMs);
  Future<void> clear(int generation);
  Future<Json?> takeOpen(int generation);
  void dispose() {}
}

class NativeInvitationDevice extends InvitationDevice {
  bool _listening = false;
  static const _channel = MethodChannel('nightshift/call_invitations');
  Future<InvitationCapability> _cap(String method, Json arguments) async {
    if (!Platform.isAndroid) return const InvitationCapability();
    if (!_listening) {
      try {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'changed') onChanged?.call();
        });
        _listening = true;
      } catch (_) {
        return const InvitationCapability();
      }
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>(method, arguments);
      return InvitationCapability.fromJson(result!);
    } on MissingPluginException {
      return const InvitationCapability();
    }
  }

  @override
  Future<InvitationCapability> synchronize(String? ownerKey, String locale) =>
      _cap('synchronize', {'ownerKey': ownerKey, 'locale': locale});
  @override
  Future<InvitationCapability> requestPermission(int generation) =>
      _cap('requestPermission', {'generation': generation});
  @override
  Future<String> token(int generation) async => (await _channel
      .invokeMethod<String>('token', {'generation': generation}))!;
  @override
  Future<void> install(int generation, PushRegistration registration,
          int requestElapsedMs) =>
      _channel.invokeMethod('install', {
        'generation': generation,
        ...registration.binding,
        'requestElapsedMs': requestElapsedMs,
      });
  @override
  Future<void> clear(int generation) async {
    if (!_listening) return;
    try {
      await _channel.invokeMethod<void>('clear', {'generation': generation});
    } on MissingPluginException {
      // Unsupported platforms never advertise invitation capability.
    }
  }

  @override
  Future<Json?> takeOpen(int generation) async {
    if (!_listening) return null;
    try {
      return await _channel.invokeMapMethod<String, dynamic>(
          'takeOpen', {'generation': generation});
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void dispose() {
    if (_listening) _channel.setMethodCallHandler(null);
  }
}

/// Only explicit enable/renew actions can create or activate an invitation lease.
/// Reads recover receipts; they never renew consent or replay uncertain mutations.
class CallInvitations extends ChangeNotifier {
  CallInvitations({
    required this.api,
    required this.identity,
    required this.ownerKey,
    required this.eligible,
    required this.foreground,
    required this.locale,
    required this.onOpen,
    InvitationDevice? device,
    DateTime Function()? now,
    int Function()? elapsed,
    bool startTimer = true,
  })  : device = device ?? NativeInvitationDevice(),
        now = now ?? DateTime.now {
    _clock.start();
    this.elapsed = elapsed ?? () => _clock.elapsedMilliseconds;
    this.device.onChanged = () {
      // Token rotation / permission changes invalidate native binding first.
      _deadline = null;
      _notify();
      if (foreground()) unawaited(recover());
    };
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }
  final NightShiftApi api;
  final Object? Function() identity;
  final String? Function() ownerKey;
  final bool Function() eligible, foreground;
  final String Function() locale;
  final Future<void> Function(Json hint) onOpen;
  final InvitationDevice device;
  final DateTime Function() now;
  late final int Function() elapsed;
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  Object? _owner;
  String? _origin;
  int _revision = 0;
  bool _disposed = false, _disabledIntent = false;
  bool busy = false, loading = false, loaded = false, retryAllowed = false;
  InvitationCapability capability = const InvitationCapability();
  PushRegistration? registration;
  ApiFailure? error;
  String? uncertain;
  String? _method, _path, _key;
  Json? _body;
  int? _deadline, _anchorElapsed;
  DateTime? _anchorWall;
  Future<void>? _recovery;
  int get remainingSeconds => _deadline == null
      ? 0
      : ((_deadline! - elapsed() + 999) ~/ 1000).clamp(0, 1800);
  bool get eligibleSession => eligible();
  bool get active =>
      eligible() &&
      !_disabledIntent &&
      capability.granted &&
      registration?.state == 'active' &&
      registration?.backgroundInvitations == true &&
      remainingSeconds > 0 &&
      _anchorWall != null &&
      _anchorElapsed != null &&
      (now().difference(_anchorWall!).inMilliseconds -
                  (elapsed() - _anchorElapsed!))
              .abs() <=
          5000;
  bool _current(int revision, Object? owner, String origin) =>
      !_disposed &&
      revision == _revision &&
      owner == identity() &&
      origin == api.baseUrl;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  ApiFailure _failure(Object value) => value is ApiFailure
      ? value
      : const ApiFailure('PUSH_UNAVAILABLE', 'Invitations are unavailable.');

  void invalidate() {
    _revision++;
    _deadline = null;
    registration = null;
    loaded = busy = loading = retryAllowed = false;
    _disabledIntent = true;
    uncertain = _method = _path = _key = null;
    _body = null;
    _recovery = null;
    // Send immediately; expected native generation cannot clear a newer owner.
    unawaited(device.clear(capability.generation).catchError((Object _) {}));
  }

  void tick() {
    if (_owner != identity() || _origin != api.baseUrl) {
      invalidate();
      _owner = identity();
      _origin = api.baseUrl;
    }
    if (_deadline != null && (!active || remainingSeconds == 0)) {
      _deadline = null;
      unawaited(device.clear(capability.generation).catchError((Object _) {}));
    }
    if (registration != null) _notify();
  }

  Future<void> recover() {
    final existing = _recovery;
    if (existing != null) return existing;
    late final Future<void> work;
    work = _recover().whenComplete(() {
      if (identical(_recovery, work)) _recovery = null;
    });
    _recovery = work;
    return work;
  }

  Future<void> _recover() async {
    if (_disposed || !foreground() || busy) return;
    if (_owner != identity() || _origin != api.baseUrl) {
      _revision++;
      _owner = identity();
      _origin = api.baseUrl;
      registration = null;
      _deadline = null;
      uncertain = _method = _path = _key = null;
      _body = null;
      _disabledIntent = false;
    }
    final revision = _revision, owner = identity(), origin = api.baseUrl;
    bool current() => _current(revision, owner, origin);
    loading = true;
    _notify();
    final started = elapsed();
    try {
      final next =
          await device.synchronize(eligible() ? ownerKey() : null, locale());
      if (!current()) return;
      capability = next;
      if (!eligible() || !next.available) {
        loaded = true;
        return;
      }
      final result = await api.privateRequest('GET', '/me/push/registration',
          origin: origin, isCurrent: current);
      if (!current()) return;
      final value = result['registration'];
      final received =
          value == null ? null : PushRegistration.fromJson(value as Json);
      final previous = registration;
      registration = received;
      if (!_disabledIntent &&
          next.granted &&
          received != null &&
          next.bindingId == received.bindingId &&
          received.state == 'active' &&
          (uncertain != 'activate' || received.same(previous))) {
        await device.install(next.generation, received, elapsed() - started);
        if (!current()) return;
        _acceptLease(received, elapsed() - started);
        if (uncertain == 'activate') _clearMutation();
      } else {
        _deadline = null;
      }
      if (uncertain == 'revoke' &&
          (received == null || received.state != 'active')) {
        _clearMutation();
      }
      retryAllowed = uncertain != null;
      loaded = true;
      error = null;
      if (next.granted && current()) {
        final hint = await device.takeOpen(next.generation);
        if (current() && foreground() && hint != null) await onOpen(hint);
      }
    } catch (failure) {
      if (!current()) return;
      _deadline = null;
      retryAllowed = false;
      error = _failure(failure);
    } finally {
      if (current()) {
        loading = false;
        _notify();
      }
    }
  }

  void _acceptLease(PushRegistration value, int duration) {
    final remaining =
        (value.expiresAt?.difference(value.serverTime).inMilliseconds ?? 0) -
            duration;
    _deadline = elapsed() + remaining.clamp(0, 1800000);
    _anchorElapsed = elapsed();
    _anchorWall = now();
  }

  void _clearMutation() {
    uncertain = _method = _path = _key = null;
    _body = null;
    retryAllowed = false;
  }

  void _mutation(String phase, String method, String path, Json body) {
    uncertain = phase;
    _method = method;
    _path = path;
    _body = Map.of(body);
    _key = newId();
    retryAllowed = false;
  }

  Future<void> enable({required bool consent}) async {
    if (!consent || !eligible() || !foreground() || busy || uncertain != null) {
      return;
    }
    final consentingOwner = identity(), consentingOrigin = api.baseUrl;
    await recover();
    if (consentingOwner != identity() ||
        consentingOrigin != api.baseUrl ||
        !eligible() ||
        !foreground() ||
        busy ||
        uncertain != null) {
      return;
    }
    if (!capability.available) {
      error = const ApiFailure(
          'PUSH_UNAVAILABLE', 'Invitations are unavailable on this device.');
      _notify();
      return;
    }
    final revision = _revision, owner = identity(), origin = api.baseUrl;
    bool current() => _current(revision, owner, origin) && eligible();
    busy = true;
    error = null;
    _disabledIntent = false;
    _notify();
    try {
      final granted = await device.requestPermission(capability.generation);
      if (!current() || !foreground()) return;
      capability = granted;
      if (!capability.granted) {
        throw const ApiFailure('PUSH_PERMISSION_REQUIRED',
            'Enable invitation notifications in Android settings.');
      }
      final token = await device.token(capability.generation);
      if (!current() || !foreground()) return;
      if (!RegExp(r'^[!-~]{1,4096}$').hasMatch(token)) {
        throw const FormatException();
      }
      _mutation('prepare', 'PUT', '/me/push/registration', {
        'targetKind': 'fcm_token',
        'token': token,
        'expectedVersion': registration?.version
      });
      await _send(current);
    } catch (failure) {
      if (current()) _mutationFailure(failure);
    } finally {
      if (_current(revision, owner, origin)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> retry() async {
    if (!retryAllowed ||
        uncertain == null ||
        busy ||
        !foreground() ||
        !eligible()) {
      return;
    }
    final revision = _revision, owner = identity(), origin = api.baseUrl;
    bool current() => _current(revision, owner, origin) && eligible();
    busy = true;
    retryAllowed = false;
    error = null;
    _notify();
    try {
      await _send(current);
    } catch (failure) {
      if (current()) _mutationFailure(failure);
    } finally {
      if (_current(revision, owner, origin)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> _send(bool Function() current) async {
    final phase = uncertain!, origin = api.baseUrl, started = elapsed();
    final result = await api.privateRequest(_method!, _path!,
        origin: origin, isCurrent: current, body: _body, idempotencyKey: _key);
    if (!current()) return;
    final received = PushRegistration.fromJson(result);
    registration = received;
    if ((phase == 'prepare' &&
            !['prepared', 'active'].contains(received.state)) ||
        (phase == 'activate' &&
            (received.state != 'active' || !received.backgroundInvitations))) {
      throw const ApiFailure(
          'PUSH_REGISTRATION_CHANGED', 'Invitation setup expired or changed.',
          status: 409);
    }
    if (phase == 'revoke') {
      _deadline = null;
      _clearMutation();
      return;
    }
    if (!capability.granted || !foreground() || _disabledIntent) return;
    await device.install(capability.generation, received, elapsed() - started);
    if (!current() || !foreground() || _disabledIntent) return;
    if (phase == 'prepare') {
      _mutation('activate', 'POST', '/me/push/registration/activate', {
        'registrationId': received.id,
        'expectedVersion': received.version,
        'bindingId': received.bindingId,
        'notificationPermission': 'granted',
        'backgroundInvitations': true,
        'capabilityVersion': 'android-audio-invitations-v1',
        'consentVersion': 'background-invitations-v1',
      });
      await _send(current);
    } else {
      _acceptLease(received, elapsed() - started);
      _clearMutation();
    }
  }

  void _mutationFailure(Object failure) {
    error = _failure(failure);
    // A parsed definitive rejection cannot become a permanently replayed stale
    // CAS. Network/5xx/unreadable successful outcomes retain the frozen intent.
    if (error!.status >= 400 && error!.status < 500) {
      _clearMutation();
      _deadline = null;
    }
  }

  Future<void> disable() async {
    final saved = registration;
    _revision++;
    _deadline = null;
    _disabledIntent = true;
    loading = false;
    _recovery = null;
    busy = false;
    _clearMutation();
    _notify();
    final revision = _revision, owner = identity(), origin = api.baseUrl;
    bool current() => _current(revision, owner, origin);
    try {
      await device.clear(capability.generation);
      if (!current() || saved == null || !eligible()) return;
      capability = await device.synchronize(ownerKey(), locale());
      if (!current()) return;
      _mutation('revoke', 'DELETE', '/me/push/registration',
          {'registrationId': saved.id, 'expectedVersion': saved.version});
      busy = true;
      await _send(current);
    } catch (failure) {
      if (current()) _mutationFailure(failure);
    } finally {
      if (current()) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    device.onChanged = null;
    device.dispose();
    super.dispose();
  }
}
