import 'dart:async';
import 'dart:math';

enum DiagnosticMediaType { audio, video }

enum DiagnosticMilestone {
  callObserved,
  acceptedObserved,
  joinRequested,
  sdkJoined,
  localCaptureObserved,
  remoteDecodeObserved,
  callEndedObserved
}

enum DiagnosticMetric {
  localPacketLossPercent,
  localSentKbps,
  remoteFrameLossPercent,
  remoteReceivedKbps,
  networkTransportDelayMs,
  jitterBufferDelayMs,
  clientServerDelayMs
}

enum DiagnosticFailure {
  microphoneDenied,
  cameraDenied,
  credentialsUnavailable,
  joinFailed,
  connectionFailed,
  mediaFailure,
  cleanupFailed
}

enum DiagnosticCapture { unknown, active, stopRequested, stopped, uncertain }

enum DiagnosticCleanup { notRequested, requested, pending, failed, released }

enum DiagnosticMute { unknown, muted, unmuted }

enum DiagnosticSymptom {
  couldNotConnect,
  couldNotHearOther,
  otherCouldNotHearMe,
  interruptedAudio
}

class DiagnosticMetricSummary {
  const DiagnosticMetricSummary(
      {required this.latest,
      required this.minimum,
      required this.maximum,
      required this.samples,
      required this.observedAtMilliseconds});
  final double latest, minimum, maximum;
  final int samples, observedAtMilliseconds;
}

class MediaDiagnosticReceipt {
  MediaDiagnosticReceipt(
      {required this.receiptId,
      required this.callId,
      required this.mediaType,
      required this.attempt,
      required this.ageMilliseconds,
      required this.remainingMilliseconds,
      required Map<DiagnosticMilestone, int> milestones,
      required Map<DiagnosticMetric, DiagnosticMetricSummary> metrics,
      required this.failure,
      required this.capture,
      required this.cleanup,
      required this.localMute,
      required this.remoteMute,
      required this.reconnectCount,
      required this.previousCleanupAttempt,
      required this.previousCleanup})
      : milestones = Map.unmodifiable(milestones),
        metrics = Map.unmodifiable(metrics);
  final String receiptId, callId;
  final DiagnosticMediaType mediaType;
  final int attempt, ageMilliseconds, remainingMilliseconds, reconnectCount;
  final Map<DiagnosticMilestone, int> milestones;
  final Map<DiagnosticMetric, DiagnosticMetricSummary> metrics;
  final DiagnosticFailure? failure;
  final DiagnosticCapture capture;
  final DiagnosticCleanup cleanup;
  final DiagnosticMute localMute, remoteMute;
  final int? previousCleanupAttempt;
  final DiagnosticCleanup? previousCleanup;
}

class MediaDiagnostics {
  MediaDiagnostics(
      {required Object? Function() owner,
      required String Function() origin,
      void Function()? onChanged,
      Duration Function()? monotonicNow,
      Timer Function(Duration, void Function())? timerFactory})
      : _owner = owner,
        _origin = origin,
        _onChanged = onChanged,
        _timerFactory = timerFactory ?? Timer.new {
    _clock = monotonicNow ?? () => _watch.elapsed;
  }
  static const lifetime = Duration(minutes: 15);
  static const _maximumCount = 65535;
  static final _uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  final Object? Function() _owner;
  final String Function() _origin;
  final void Function()? _onChanged;
  final Timer Function(Duration, void Function()) _timerFactory;
  final Stopwatch _watch = Stopwatch()..start();
  late final Duration Function() _clock;
  Object? _scopeOwner;
  String? _scopeOrigin, _lastCallId;
  _Receipt? _receipt;
  Timer? _timer;
  int _lastNow = 0;
  bool _disposed = false, _notificationPending = false;

  int get _now => _lastNow = max(_lastNow, _clock().inMilliseconds);
  void _changed() {
    if (_disposed || _notificationPending || _onChanged == null) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (_disposed) return;
      try {
        _onChanged();
      } catch (_) {/* Diagnostics must never affect media. */}
    });
  }

  void _erase() {
    _timer?.cancel();
    _timer = null;
    _receipt = null;
    _changed();
  }

  void _resetScope() {
    _erase();
    _scopeOwner = null;
    _scopeOrigin = null;
    _lastCallId = null;
  }

  bool _valid() {
    if (_disposed || _scopeOwner == null) return false;
    try {
      if (_owner() != _scopeOwner || _origin() != _scopeOrigin) {
        _resetScope();
        return false;
      }
    } catch (_) {
      _resetScope();
      return false;
    }
    final receipt = _receipt;
    if (receipt != null && _now - receipt.created >= lifetime.inMilliseconds) {
      _erase();
    }
    return _receipt != null;
  }

  void _scheduleExpiry() {
    _timer?.cancel();
    final receipt = _receipt;
    if (receipt == null || _disposed) return;
    _timer = _timerFactory(
        Duration(
            milliseconds:
                max(0, lifetime.inMilliseconds - (_now - receipt.created))),
        () {
      _timer = null;
      if (_valid()) _scheduleExpiry();
    });
  }

  Object? get owner => _valid() ? _scopeOwner : null;
  MediaDiagnosticReceipt? get snapshot {
    if (!_valid()) return null;
    final r = _receipt!, age = _now - r.created;
    return MediaDiagnosticReceipt(
        receiptId: r.id,
        callId: r.callId,
        mediaType: r.mediaType,
        attempt: r.attempt,
        ageMilliseconds: age,
        remainingMilliseconds: max(0, lifetime.inMilliseconds - age),
        milestones: r.milestones,
        metrics: r.metrics,
        failure: r.failure,
        capture: r.capture,
        cleanup: r.cleanup,
        localMute: r.localMute,
        remoteMute: r.remoteMute,
        reconnectCount: r.reconnectCount,
        previousCleanupAttempt: r.previousCleanupAttempt,
        previousCleanup: r.previousCleanup);
  }

  MediaDiagnosticSink? begin(
      {required Object owner,
      required String callId,
      required DiagnosticMediaType mediaType}) {
    if (_disposed) return null;
    _valid();
    Object? current;
    String origin;
    try {
      current = _owner();
      origin = _origin();
    } catch (_) {
      _resetScope();
      return null;
    }
    if (current == null || current != owner) return null;
    _scopeOwner = current;
    _scopeOrigin = origin;
    if (!_uuid.hasMatch(callId)) {
      _erase();
      return null;
    }
    callId = callId.toLowerCase();
    if (callId != _lastCallId) {
      _erase();
      _lastCallId = callId;
      _receipt = _Receipt(_randomId(), callId, mediaType, _now);
      _scheduleExpiry();
    } else {
      final r = _receipt;
      if (r == null ||
          r.ended ||
          r.mediaType != mediaType ||
          r.attempt >= _maximumCount) {
        return null;
      }
      r.previousCleanupAttempt = r.attempt;
      r.previousCleanup = r.cleanup;
      r.attempt++;
      r.milestones.removeWhere((key, _) =>
          key != DiagnosticMilestone.callObserved &&
          key != DiagnosticMilestone.acceptedObserved);
      r.metrics.clear();
      r.failure = null;
      r.capture = DiagnosticCapture.unknown;
      r.cleanup = DiagnosticCleanup.notRequested;
      r.localMute = DiagnosticMute.unknown;
      r.remoteMute = DiagnosticMute.unknown;
      r.reconnectCount = 0;
    }
    final r = _receipt!;
    _changed();
    return MediaDiagnosticSink._(this, r.id, r.attempt);
  }

  _Receipt? _current(MediaDiagnosticSink sink, {bool allowEnded = false}) {
    if (!_valid()) return null;
    final r = _receipt!;
    if (sink._receiptId != r.id ||
        sink._attempt != r.attempt ||
        (!allowEnded && (r.ended || r.cleanup == DiagnosticCleanup.released))) {
      return null;
    }
    return r;
  }

  void _milestone(MediaDiagnosticSink sink, DiagnosticMilestone value) {
    // The server can acknowledge End after native release has completed.
    // This controller observation must not reopen any SDK facts or metrics.
    final r = _current(sink,
        allowEnded: value == DiagnosticMilestone.callEndedObserved);
    if (r == null || r.milestones.containsKey(value)) return;
    r.milestones[value] = _now - r.created;
    if (value == DiagnosticMilestone.callEndedObserved) r.ended = true;
    _changed();
  }

  void _metric(MediaDiagnosticSink sink, DiagnosticMetric metric, num? value) {
    final r = _current(sink);
    if (r == null || value == null || !value.isFinite) return;
    final maximum = switch (metric) {
      DiagnosticMetric.localPacketLossPercent ||
      DiagnosticMetric.remoteFrameLossPercent =>
        100,
      DiagnosticMetric.localSentKbps ||
      DiagnosticMetric.remoteReceivedKbps =>
        100000,
      _ => 60000
    };
    if (value < 0 || value > maximum) return;
    final old = r.metrics[metric], number = value.toDouble();
    r.metrics[metric] = DiagnosticMetricSummary(
        latest: number,
        minimum: min(old?.minimum ?? number, number),
        maximum: max(old?.maximum ?? number, number),
        samples: min(_maximumCount, (old?.samples ?? 0) + 1),
        observedAtMilliseconds: _now - r.created);
    _changed();
  }

  void _cleanup(MediaDiagnosticSink sink, DiagnosticCleanup value) {
    if (!_valid()) return;
    final r = _receipt!;
    if (r.id != sink._receiptId) return;
    if (sink._attempt == r.attempt) {
      if (!_cleanupProgress(r.cleanup, value)) return;
      r.cleanup = value;
    } else if (sink._attempt == r.previousCleanupAttempt &&
        (value == DiagnosticCleanup.failed ||
            value == DiagnosticCleanup.released)) {
      if (!_cleanupProgress(r.previousCleanup!, value)) return;
      r.previousCleanup = value;
    } else {
      return;
    }
    _changed();
  }

  static bool _cleanupProgress(DiagnosticCleanup old, DiagnosticCleanup next) =>
      old != DiagnosticCleanup.released && next.index > old.index;
  void _capture(MediaDiagnosticSink sink, DiagnosticCapture value) {
    final r = _current(sink, allowEnded: true);
    if (r == null || r.capture == DiagnosticCapture.stopped) return;
    if (value == DiagnosticCapture.active &&
        (r.ended ||
            r.cleanup != DiagnosticCleanup.notRequested ||
            r.capture == DiagnosticCapture.stopRequested ||
            r.capture == DiagnosticCapture.uncertain)) {
      return;
    }
    r.capture = value;
    _changed();
  }

  void _failure(MediaDiagnosticSink sink, DiagnosticFailure value) {
    final r = _current(sink);
    if (r == null) return;
    r.failure = value;
    _changed();
  }

  void _mute(MediaDiagnosticSink sink, DiagnosticMute value, bool local) {
    final r = _current(sink);
    if (r == null) return;
    if (local) {
      r.localMute = value;
    } else {
      r.remoteMute = value;
    }
    _changed();
  }

  void _reconnect(MediaDiagnosticSink sink) {
    final r = _current(sink);
    if (r == null) return;
    r.reconnectCount = min(_maximumCount, r.reconnectCount + 1);
    _changed();
  }

  /// Explicit allowlist, freshly copied. A symptom is user-selected for this
  /// export only; SDK observations never diagnose what either person heard.
  Map<String, Object?>? export({DiagnosticSymptom? symptom}) {
    final r = snapshot;
    if (r == null) return null;
    return {
      'receiptId': r.receiptId,
      'callId': r.callId,
      'mediaType': r.mediaType.name,
      'attempt': r.attempt,
      'ageMilliseconds': r.ageMilliseconds,
      'remainingMilliseconds': r.remainingMilliseconds,
      'milestones': {
        for (final entry in r.milestones.entries) entry.key.name: entry.value
      },
      'metrics': {
        for (final entry in r.metrics.entries)
          entry.key.name: {
            'latest': entry.value.latest,
            'minimum': entry.value.minimum,
            'maximum': entry.value.maximum,
            'samples': entry.value.samples,
            'observedAtMilliseconds': entry.value.observedAtMilliseconds
          }
      },
      'failure': r.failure?.name,
      'capture': r.capture.name,
      'cleanup': r.cleanup.name,
      'localMute': r.localMute.name,
      'remoteMute': r.remoteMute.name,
      'reconnectCount': r.reconnectCount,
      'previousCleanupAttempt': r.previousCleanupAttempt,
      'previousCleanup': r.previousCleanup?.name,
      if (symptom != null) 'userReportedSymptom': symptom.name
    };
  }

  /// Forget the receipt; the same scoped call cannot renew its original lease.
  void clear() {
    if (!_disposed) _erase();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resetScope();
    _watch.stop();
  }

  static String _randomId() {
    final random = Random.secure(),
        bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class MediaDiagnosticSink {
  const MediaDiagnosticSink._(this._recorder, this._receiptId, this._attempt);
  final MediaDiagnostics _recorder;
  final String _receiptId;
  final int _attempt;
  void milestone(DiagnosticMilestone value) =>
      _recorder._milestone(this, value);
  void metric(DiagnosticMetric metric, num? value) =>
      _recorder._metric(this, metric, value);
  void failure(DiagnosticFailure value) => _recorder._failure(this, value);
  void capture(DiagnosticCapture value) => _recorder._capture(this, value);
  void cleanup(DiagnosticCleanup value) => _recorder._cleanup(this, value);
  void localMute(DiagnosticMute value) => _recorder._mute(this, value, true);
  void remoteMute(DiagnosticMute value) => _recorder._mute(this, value, false);
  void reconnect() => _recorder._reconnect(this);
}

class _Receipt {
  _Receipt(this.id, this.callId, this.mediaType, this.created);
  final String id, callId;
  final DiagnosticMediaType mediaType;
  final int created;
  int attempt = 1, reconnectCount = 0;
  bool ended = false;
  final milestones = <DiagnosticMilestone, int>{
    DiagnosticMilestone.callObserved: 0
  };
  final metrics = <DiagnosticMetric, DiagnosticMetricSummary>{};
  DiagnosticFailure? failure;
  DiagnosticCapture capture = DiagnosticCapture.unknown;
  DiagnosticCleanup cleanup = DiagnosticCleanup.notRequested;
  DiagnosticMute localMute = DiagnosticMute.unknown,
      remoteMute = DiagnosticMute.unknown;
  int? previousCleanupAttempt;
  DiagnosticCleanup? previousCleanup;
}
