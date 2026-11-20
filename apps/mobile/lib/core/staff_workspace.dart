import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';
import 'staff_session.dart';
import 'staff_transport.dart';

class StaffAccessRequest {
  StaffAccessRequest(Json value, String owner)
      : requestId =
            value['requestId'] is String ? value['requestId'] as String : '',
        accountReference = value['accountReference'] is String
            ? value['accountReference'] as String
            : '',
        status = value['status'] is String ? value['status'] as String : '',
        expiresAt = staffTime(value['expiresAt']) {
    if (value.length != 4 ||
        !staffUuid.hasMatch(requestId) ||
        !staffUuid.hasMatch(accountReference) ||
        accountReference != owner ||
        !['pending', 'provisioned'].contains(status)) {
      throw staffUnavailable;
    }
  }
  final String requestId, accountReference, status;
  final DateTime expiresAt;
}

class StaffWorkspace extends ChangeNotifier {
  StaffWorkspace({
    required this.identity,
    required this.ownerId,
    required this.enabled,
    required this.proof,
    StaffCookies? cookies,
    StaffTransport? transport,
    DateTime Function()? now,
    bool startTimer = true,
  })  : cookies = cookies ?? NativeStaffCookies(),
        now = now ?? DateTime.now {
    this.transport = transport ?? NativeStaffTransport(this.cookies);
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }
  final Object? Function() identity;
  final String? Function() ownerId;
  final bool Function() enabled;
  final Future<String> Function() proof;
  final StaffCookies cookies;
  final DateTime Function() now;
  late final StaffTransport transport;
  Object? _owner;
  int _revision = 0;
  bool _disposed = false, _active = false;
  Timer? _timer;
  bool busy = false, ready = false;
  int? cookieGeneration;
  Uri? origin;
  DateTime? expiresAt;
  ApiFailure? error;
  StaffAccessRequest? accessRequest;

  bool get canRequest =>
      !busy &&
      !ready &&
      error?.code == 'STAFF_ACCESS_NOT_APPROVED' &&
      accessRequest == null;
  bool _current(int revision, Object? owner) =>
      !_disposed &&
      _active &&
      enabled() &&
      revision == _revision &&
      owner == identity();

  Future<void> open() async {
    if (busy || _disposed) return;
    close();
    _active = true;
    _owner = identity();
    final owner = _owner, id = ownerId(), revision = ++_revision;
    busy = true;
    error = null;
    bool current() => _current(revision, owner);
    notifyListeners();
    try {
      if (!enabled() || owner == null || id == null) throw staffUnavailable;
      await cookies.clear();
      if (!current()) return;
      final config = await cookies.configuration();
      if (!current()) return;
      final token = await proof();
      if (!current()) return;
      try {
        final receipt = await transport.request(StaffOperation.currentRequest,
            proof: token, isCurrent: current);
        if (!current()) return;
        accessRequest = StaffAccessRequest(receipt.body, id);
        if (!accessRequest!.expiresAt.isAfter(now())) accessRequest = null;
      } on ApiFailure catch (failure) {
        if (failure.code != 'STAFF_ACCESS_REQUEST_NOT_FOUND') rethrow;
      }
      if (!current()) return;
      final challenge = await transport.request(StaffOperation.challenge,
          proof: token, isCurrent: current);
      if (!current()) return;
      final csrf = challenge.body['csrfToken'];
      final challengeExpiry = staffTime(challenge.body['expiresAt']);
      if (challenge.body.length != 2 ||
          csrf is! String ||
          !staffHex.hasMatch(csrf) ||
          !challengeExpiry.isAfter(now()) ||
          challengeExpiry.difference(now()) > const Duration(seconds: 120)) {
        throw staffUnavailable;
      }
      final challengeToken = staffCookie(
          challenge.cookies, '__Host-nightshift_staff_challenge', 120);
      final exchange = await transport.request(StaffOperation.exchange,
          proof: token,
          isCurrent: current,
          challenge: challengeToken,
          csrf: csrf);
      if (!current()) return;
      final body = exchange.body, staff = body['staff'];
      final permissions = body['permissions'];
      final expiry = staffTime(body['expiresAt']);
      const knownPermissions = {
        'listener.review.read',
        'listener.review.evidence.read',
        'listener.review.decide',
        'staff.access.manage'
      };
      if (body.length != 4 ||
          staff is! Json ||
          staff.length != 1 ||
          staff['id'] is! String ||
          !staffUuid.hasMatch(staff['id'] as String) ||
          permissions is! List ||
          permissions.any((p) => !knownPermissions.contains(p)) ||
          permissions.toSet().length != permissions.length ||
          body['csrfToken'] is! String ||
          !staffHex.hasMatch(body['csrfToken'] as String) ||
          !expiry.isAfter(now()) ||
          expiry.difference(now()) > const Duration(minutes: 30)) {
        throw staffUnavailable;
      }
      final tokenCookie =
          staffCookie(exchange.cookies, '__Host-nightshift_staff', 1800);
      final generation =
          await cookies.install(tokenCookie, expiry, isCurrent: current);
      if (!current()) return;
      cookieGeneration = generation;
      origin = config.origin;
      expiresAt = expiry;
      ready = true;
      error = null;
    } catch (failure) {
      if (current()) {
        error = failure is ApiFailure ? failure : staffUnavailable;
        unawaited(cookies.clear().catchError((Object _) {}));
      }
    } finally {
      if (current()) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> requestAccess() async {
    if (!canRequest || !_active) return;
    final owner = _owner, id = ownerId(), revision = _revision;
    bool current() => _current(revision, owner);
    if (!current() || id == null) return;
    busy = true;
    notifyListeners();
    try {
      final token = await proof();
      if (!current()) return;
      final response = await transport.request(StaffOperation.accessRequest,
          proof: token, isCurrent: current);
      if (!current()) return;
      accessRequest = StaffAccessRequest(response.body, id);
      if (!accessRequest!.expiresAt.isAfter(now())) throw staffUnavailable;
    } catch (failure) {
      if (current()) error = failure is ApiFailure ? failure : staffUnavailable;
    } finally {
      if (current()) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void tick() {
    reconcile();
    if (ready && expiresAt != null && !expiresAt!.isAfter(now())) {
      close();
      error =
          const ApiFailure('STAFF_SESSION_EXPIRED', 'Staff access expired.');
      if (!_disposed) notifyListeners();
    }
  }

  void reconcile() {
    if (_active && (_owner != identity() || !enabled())) close();
  }

  void browserFailed() {
    close();
    error = const ApiFailure(
        'STAFF_BROWSER_FAILED', 'The staff workspace could not open.');
    if (!_disposed) notifyListeners();
  }

  void close({bool notify = true}) {
    final hadState = _active || ready || busy || accessRequest != null;
    _revision++;
    _active = ready = busy = false;
    _owner = null;
    origin = null;
    expiresAt = null;
    cookieGeneration = null;
    accessRequest = null;
    error = null;
    transport.cancel();
    if (hadState) unawaited(cookies.clear().catchError((Object _) {}));
    if (hadState && !_disposed && notify) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    close();
    super.dispose();
  }
}
