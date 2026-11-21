import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nightshift_api/api.dart' as generated;
import 'api.dart';
import 'models.dart';

/// A server receipt, never a locally inferred call or charge.
class MatchRequest {
  MatchRequest._(this.data);
  factory MatchRequest.fromJson(Json json) {
    generated.MatchingRequest.fromJson(json);
    final value = MatchRequest._(Map.unmodifiable(json));
    if (value.version < 1 ||
        value.attemptCount < 0 ||
        value.attemptCount > 3 ||
        value.deadline.isBefore(value.created) ||
        value.deadline.difference(value.created) >
            const Duration(seconds: 90) ||
        (value.state == 'ringing' || value.state == 'matched') !=
            (value.callId != null) ||
        (value.active && json['endedAt'] != null) ||
        (!value.active && json['endedAt'] == null) ||
        (value.callId == null && value.reasons.isNotEmpty)) {
      throw const FormatException('Invalid matching state');
    }
    return value;
  }
  final Json data;
  String get id => data['id'] as String;
  int get version => data['version'] as int;
  String get state => data['state'] as String;
  String get language => data['language'] as String;
  String get quoteId => data['quoteId'] as String;
  String? get callId => data['currentCallId'] as String?;
  String? get reason => data['terminalReason'] as String?;
  int get attemptCount => data['attemptCount'] as int;
  List<String> get reasons =>
      List<String>.from(data['selectionReasons'] as List);
  DateTime get created => DateTime.parse(data['createdAt'] as String);
  DateTime get deadline => DateTime.parse(data['deadlineAt'] as String);
  DateTime get serverTime => DateTime.parse(data['serverTime'] as String);
  bool get active => state == 'searching' || state == 'ringing';
}

/// One consented request. A timer can only read, never create, retry or cancel.
/// Mutation keys and bodies stay frozen until authoritative recovery settles
/// an unknown outcome. Account/origin changes invalidate every continuation.
class Matching extends ChangeNotifier {
  Matching(
      {required this.api,
      required this.identity,
      required this.enabled,
      required this.foreground,
      DateTime Function()? now,
      bool startTimer = true})
      : now = now ?? DateTime.now {
    if (startTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }
  final NightShiftApi api;
  final Object? Function() identity;
  final bool Function() enabled, foreground;
  final DateTime Function() now;
  Timer? _timer;
  Future<void>? _recovery;
  Object? _owner;
  String? _origin;
  int _generation = 0, _read = 0;
  int presentationRevision = 0;
  bool _disposed = false, _restoreAttempted = false, _wasForeground = true;
  bool restored = false, loading = false, busy = false, presented = false;
  MatchRequest? request;
  CallRate? rate;
  ApiFailure? error;
  String? uncertain;
  String? _key, _path;
  Json? _body;
  bool retryAllowed = false;
  DateTime? _localDeadline;
  bool get blocked => request?.active == true || uncertain != null || busy;
  bool get ownsScreen => presented || blocked;
  int get remainingSeconds => _localDeadline == null
      ? 0
      : ((_localDeadline!.difference(now()).inMilliseconds + 999) ~/ 1000)
          .clamp(0, 90);

  void reconcile() {
    if (_disposed) return;
    if (_owner != identity() || _origin != api.baseUrl) {
      reset();
      _owner = identity();
      _origin = api.baseUrl;
    }
    final visible = foreground();
    if (!visible && _wasForeground) {
      _read++;
      loading = false;
    }
    if (visible && !_wasForeground) _restoreAttempted = false;
    _wasForeground = visible;
    if (enabled() && visible && !_restoreAttempted && !loading && !busy) {
      _restoreAttempted = true;
      // Avoid notifying the parent during its own notification/build phase.
      scheduleMicrotask(recover);
    }
  }

  void reset() {
    _generation++;
    presentationRevision++;
    _read++;
    restored = loading = busy = presented = retryAllowed = false;
    _recovery = null;
    _restoreAttempted = false;
    request = null;
    rate = null;
    error = null;
    uncertain = _key = _path = null;
    _body = null;
    _beforeCreate = null;
    _localDeadline = null;
  }

  bool _current(int generation, Object? owner, String origin) =>
      !_disposed &&
      generation == _generation &&
      owner == identity() &&
      origin == api.baseUrl &&
      enabled();

  void tick() {
    reconcile();
    if (!enabled() || !foreground()) return;
    if (request?.active == true && uncertain == null && !busy && !loading) {
      unawaited(recover());
    }
    if (ownsScreen) _notify();
  }

  Future<void> open() async {
    reconcile();
    if (!enabled() || !foreground()) return;
    presentationRevision++;
    presented = true;
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    final presentation = presentationRevision;
    _notify();
    await recover();
    if (_current(generation, owner, origin) &&
        presented &&
        presentation == presentationRevision &&
        !blocked) {
      await loadRate();
    }
  }

  void dismiss() {
    if (blocked) return;
    presentationRevision++;
    presented = false;
    _notify();
  }

  Future<void> loadRate() async {
    if (!enabled() || !foreground() || busy) return;
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    try {
      final result = await api.request('GET', '/rates');
      if (!_current(generation, owner, origin) || !foreground()) return;
      final rates = (result['items'] as List).cast<Json>();
      rate = CallRate.fromJson(
          rates.singleWhere((r) => r['id'] == 'test-audio-v1'));
      error = null;
    } catch (failure) {
      if (!_current(generation, owner, origin) || !foreground()) return;
      rate = null;
      error = _failure(failure);
    }
    _notify();
  }

  Future<void> recover() {
    final pending = _recovery;
    if (pending != null && loading) return pending;
    final operation = _recover();
    _recovery = operation;
    return operation.whenComplete(() {
      if (identical(_recovery, operation)) _recovery = null;
    });
  }

  Future<void> _recover() async {
    if (!enabled() || !foreground() || loading || busy || _disposed) return;
    _restoreAttempted = true;
    loading = true;
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    final read = ++_read;
    _notify();
    bool current() =>
        _current(generation, owner, origin) && read == _read && foreground();
    try {
      final result = await api.request('GET', '/me/match');
      if (!current()) return;
      if (!result.containsKey('request')) {
        throw const FormatException('Missing request');
      }
      final next = result['request'] == null
          ? null
          : MatchRequest.fromJson(result['request'] as Json);
      // A late read cannot regress a known version or replace a current request
      // with an older completed one. Mutations also invalidate all older reads.
      if (next != null &&
          (request == null ||
              request!.id == next.id ||
              !next.created.isBefore(request!.created))) {
        _accept(next);
      } else if (next == null && request == null) {
        _localDeadline = null;
      }
      restored = true;
      error = null;
      if (uncertain == 'create') {
        // Any returned request with the frozen intent is authoritative recovery.
        // A previous terminal receipt is not evidence this new POST committed.
        if (next != null &&
            next.id != _beforeCreate &&
            next.language == _body?['language'] &&
            next.quoteId == _body?['quoteId']) {
          _settled();
        } else {
          retryAllowed = true;
        }
      } else if (uncertain == 'cancel') {
        if (next != null && next.id == request?.id && !next.active) {
          _settled();
        } else {
          retryAllowed = true;
        }
      }
    } catch (failure) {
      if (!current()) return;
      error = _failure(failure);
      retryAllowed = false;
    } finally {
      if (current()) {
        loading = false;
        _notify();
      }
    }
  }

  String? _beforeCreate;
  Future<void> start({required String language, required bool consent}) async {
    reconcile();
    if (!enabled() ||
        !foreground() ||
        blocked ||
        !restored ||
        rate == null ||
        !consent ||
        !['ta', 'en'].contains(language)) {
      return;
    }
    _beforeCreate = request?.id;
    _key = newId();
    _path = '/matches';
    _body = {
      'language': language,
      'mediaType': 'audio',
      'quoteId': rate!.id,
      'consent': true,
      'consentVersion': 'matching-search-v1'
    };
    uncertain = 'create';
    presented = true;
    await _send();
  }

  Future<void> cancel() async {
    if (!enabled() ||
        !foreground() ||
        busy ||
        uncertain != null ||
        request?.active != true) {
      return;
    }
    _key = newId();
    _path = '/matches/${request!.id}/cancel';
    _body = {'expectedVersion': request!.version};
    uncertain = 'cancel';
    await _send();
  }

  Future<void> retry() async {
    if (!retryAllowed ||
        uncertain == null ||
        busy ||
        !enabled() ||
        !foreground()) {
      return;
    }
    await _send();
  }

  Future<void> _send() async {
    busy = true;
    loading = false;
    _read++;
    retryAllowed = false;
    error = null;
    final generation = _generation, owner = identity(), origin = api.baseUrl;
    final path = _path!, key = _key!, body = Map<String, dynamic>.from(_body!);
    _notify();
    try {
      final response =
          await api.request('POST', path, body: body, idempotencyKey: key);
      if (!_current(generation, owner, origin)) return;
      final next = MatchRequest.fromJson(response);
      if ((path != '/matches' && next.id != request?.id) ||
          (path == '/matches' &&
              (next.language != body['language'] ||
                  next.quoteId != body['quoteId']))) {
        throw const FormatException('Mismatched receipt');
      }
      _accept(next);
      _settled();
      restored = true;
    } catch (failure) {
      if (!_current(generation, owner, origin)) return;
      error = _failure(failure);
      // Only explicit authoritative rejection settles intent. Transport/5xx/
      // unreadable success remains uncertain and must be recovered before retry.
      if (failure is ApiFailure &&
          failure.status >= 400 &&
          failure.status < 500) {
        _settled();
        if (['MATCH_ACTIVE', 'MATCH_STALE_VERSION', 'CALL_ACTIVE']
            .contains(failure.code)) {
          restored = false;
        }
      }
    } finally {
      if (_current(generation, owner, origin)) {
        busy = false;
        _notify();
      }
    }
  }

  void _accept(MatchRequest next) {
    if (request?.id == next.id && next.version < request!.version) return;
    // Map server time once; subsequent reads must never extend a known deadline.
    final remaining = next.deadline.difference(next.serverTime);
    final deadline =
        now().add(remaining.isNegative ? Duration.zero : remaining);
    _localDeadline = request?.id == next.id &&
            _localDeadline != null &&
            _localDeadline!.isBefore(deadline)
        ? _localDeadline
        : deadline;
    request = next;
  }

  void _settled() {
    uncertain = _key = _path = null;
    _body = null;
    retryAllowed = false;
  }

  ApiFailure _failure(Object value) => value is ApiFailure
      ? value
      : const ApiFailure('INVALID_RESPONSE', 'Status could not be verified.');
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
