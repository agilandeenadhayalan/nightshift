import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'audio.dart';
import 'models.dart';
import 'session_store.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final controller = AppController(
      api: NightShiftApi(),
      store: DeviceSessionStore(),
      audio: AgoraCallAudio());
  unawaited(controller.initialize());
  return controller;
});

class AppController extends ChangeNotifier {
  AppController(
      {required this.api,
      required this.store,
      required this.audio,
      this.startTimers = true,
      this.developmentEnabled = !kReleaseMode}) {
    audio.onChanged = _audioChanged;
    audio.onFailure = (code) => unawaited(_audioFailed(code));
  }
  final NightShiftApi api;
  final SessionStore store;
  final CallAudio audio;
  final bool startTimers;
  final bool developmentEnabled;
  UserProfile? user;
  CallSession? activeCall, lastCall;
  List<ListenerProfile> listeners = [];
  List<CallSession> history = [];
  String? historyCursor;
  bool historyLoading = false, historyLoaded = false;
  ApiFailure? historyError;
  bool _historyRetryAppend = false;
  int _sessionRevision = 0, _historyRequest = 0, _snapshotRequest = 0;
  int balance = 0, held = 0;
  bool initializing = true, busy = false, offline = false, foreground = true;
  String locale = 'en', language = 'ta', lastPath = '/home';
  String? error, errorCode, diagnosticId;
  bool _errorFromSnapshot = false;
  Future<void>? _sessionCleanup;
  String _deviceId = '', _joiningId = '', _joinedId = '';
  String? _abandonedCallId;
  bool _stopping = false;
  int _revision = 0;
  bool _polling = false, _mediaPosting = false, _disposed = false;
  bool snapshotLoaded = false;
  bool get snapshotLoading => _polling;
  Timer? _pollTimer, _presenceTimer, _mediaTimer;
  DateTime? _lastServerContact;
  String text(String english, String tamil) => locale == 'ta' ? tamil : english;
  bool get isListener => user?.mode == AppMode.listener;
  bool get hasCall => activeCall != null && !activeCall!.ended;
  bool get endingLocally =>
      activeCall != null && activeCall!.id == _abandonedCallId;
  bool get canSwitch => user?.listenerApproved == true && !hasCall && !busy;

  Future<void> initialize() async {
    if (!developmentEnabled) {
      // A release install must not restore a debug token and join behind the
      // release-blocked screen, even when Android retains this app's data.
      api.token = null;
      initializing = false;
      _notify();
      return;
    }
    try {
      locale = await store.read('locale') ?? 'en';
      language = await store.read('language') ?? 'ta';
      if (!['en', 'ta'].contains(locale)) locale = 'en';
      if (!['en', 'ta'].contains(language)) language = 'ta';
      _abandonedCallId = await store.read('abandonedCallId');
      lastPath = await store.read('lastPath') ?? '/home';
      if (!['/home', '/history', '/profile'].contains(lastPath)) {
        lastPath = '/home';
      }
      api.baseUrl = await store.read('baseUrl') ?? api.baseUrl;
      _deviceId = await store.read('deviceId') ?? newId();
      await store.write('deviceId', _deviceId);
      api.token = await store.read('token');
      if (api.token != null) {
        await refresh();
        if (user != null && !hasCall && lastPath == '/history') {
          await loadHistory();
        }
      }
    } catch (e) {
      _showError(e);
    }
    initializing = false;
    _startTimers();
    _notify();
  }

  void _startTimers() {
    if (!startTimers) return;
    _pollTimer ??=
        Timer.periodic(const Duration(seconds: 2), (_) => unawaited(refresh()));
    // Snapshot latency must not starve the independently metered media lease.
    _mediaTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (foreground && _joinedId == activeCall?.id) {
        unawaited(reportMedia());
      }
    });
    _presenceTimer ??= Timer.periodic(
        const Duration(seconds: 15), (_) => unawaited(heartbeat()));
  }

  Future<void> login(String url, String handle, String accessKey) =>
      perform(() async {
        // A revoked session may still be deleting its persisted token. Never
        // let that older cleanup erase the token issued by this sign-in.
        await _sessionCleanup;
        if (!developmentEnabled) {
          throw const ApiFailure('TEST_ONLY',
              'Development sign-in is unavailable in release builds.');
        }
        final uri = Uri.tryParse(url.trim());
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const ApiFailure(
              'INVALID_URL', 'Enter a valid backend HTTP or HTTPS address.');
        }
        api.baseUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
        _invalidateSessionRequests();
        _resetHistory();
        api.token = null;
        final result = await api.request('POST', '/auth/dev', body: {
          'handle': handle,
          'accessKey': accessKey,
          'deviceId': _deviceId,
        });
        api.token = result['token'] as String;
        await store.write('token', api.token!);
        await store.write('baseUrl', api.baseUrl);
        user = UserProfile.fromJson(result['user'] as Json);
        await heartbeat();
        await refresh();
      });

  Future<void> refresh() async {
    if (api.token == null || !foreground || _polling || _disposed) return;
    _polling = true;
    final revision = _revision;
    final session = _sessionRevision;
    final request = ++_snapshotRequest;
    if (!snapshotLoaded) _notify();
    try {
      final snapshot = await api.request('GET', '/snapshot?language=$language');
      if (revision != _revision || session != _sessionRevision || _disposed) {
        return;
      }
      final profile = UserProfile.fromJson(snapshot['user'] as Json);
      final wallet = snapshot['wallet'] as Json;
      final walletBalance = number(wallet['balanceMicrocredits']);
      final walletHeld = number(wallet['heldMicrocredits']);
      final directory = (snapshot['listeners'] as List)
          .map((j) => ListenerProfile.fromJson(j as Json))
          .toList();
      final previous = activeCall;
      final next = snapshot['activeCall'] == null
          ? null
          : CallSession.fromJson(snapshot['activeCall'] as Json);
      _lastServerContact = DateTime.now();
      offline = false;
      user = profile;
      balance = walletBalance;
      held = walletHeld;
      listeners = directory;
      snapshotLoaded = true;
      if (_errorFromSnapshot) {
        error = null;
        errorCode = null;
        diagnosticId = null;
        _errorFromSnapshot = false;
      }
      // Snapshot is authoritative; terminal sessions cannot retain the microphone.
      if (next == null || next.ended) {
        activeCall = null;
        _abandonedCallId = null;
        await store.delete('abandonedCallId');
        if (previous != null && !previous.ended) {
          await audio.leave();
          _joinedId = '';
          lastPath = '/history';
          await store.write('lastPath', lastPath);
          await loadHistory();
        }
        if (next != null) lastCall = next;
        activeCall = null;
      } else {
        activeCall = next;
        if (endingLocally) {
          if (!_stopping) await _stopOnServer(next);
        } else if (!next.ringing &&
            _joiningId != next.id &&
            _joinedId != next.id) {
          unawaited(_join(next));
        }
      }
    } catch (e) {
      if (session != _sessionRevision || _disposed) return;
      _showError(e, fromSnapshot: true);
      if (e is ApiFailure && e.status == 401) await _clearSession();
      // Control connectivity loss must not leave media running indefinitely.
      if (hasCall &&
          _lastServerContact != null &&
          DateTime.now().difference(_lastServerContact!) >
              const Duration(seconds: 8)) {
        await audio.leave();
        _joinedId = '';
      }
    } finally {
      if (request == _snapshotRequest) {
        _polling = false;
        _notify();
      }
    }
  }

  Future<void> heartbeat() async {
    if (api.token == null || !foreground || _disposed) return;
    try {
      await api.request('POST', '/presence/heartbeat', body: {});
    } catch (e) {
      _showError(e);
      _notify();
    }
  }

  Future<void> setOnline(bool value) => perform(() async {
        await api.request('PUT', '/me/availability', body: {'online': value});
        if (value) await heartbeat();
        await refresh();
      });

  Future<void> switchMode() => perform(() async {
        if (!canSwitch &&
            !(busy && user?.listenerApproved == true && !hasCall)) {
          return;
        }
        final result = await api.request('PUT', '/me/mode',
            body: {'mode': isListener ? 'customer' : 'listener'});
        // A poll already in flight must not undo the server-approved mode.
        _revision++;
        user = UserProfile.fromJson(result);
        lastPath = '/home';
        await store.write('lastPath', lastPath);
        await refresh();
      });

  Future<void> startCall(ListenerProfile listener) => perform(() async {
        await audio.checkPermission();
        _revision++;
        final response = await api.request('POST', '/calls',
            body: {
              'listenerId': listener.id,
              'quoteId': 'test-audio-v1',
            },
            idempotencyKey: newId());
        activeCall = CallSession.fromJson(response);
        _revision++;
      });

  Future<void> transition(String action) => perform(() async {
        final call = activeCall;
        if (call == null) return;
        if (['end', 'cancel', 'decline'].contains(action)) {
          await _stopLocally(call);
          await _stopOnServer(call);
          return;
        }
        if (action == 'accept') await audio.checkPermission();
        _revision++;
        final result = await api.request('POST', '/calls/${call.id}/$action',
            body: {'expectedVersion': call.version}, idempotencyKey: newId());
        final updated = CallSession.fromJson(result);
        _revision++;
        if (updated.ended) {
          activeCall = null;
          await audio.leave();
          _joinedId = '';
          lastCall = updated;
          activeCall = null;
          lastPath = '/history';
          await store.write('lastPath', lastPath);
          await loadHistory();
        } else {
          activeCall = updated;
          if (!updated.ringing) unawaited(_join(updated));
        }
        await refresh();
      });

  Future<void> _join(CallSession call) async {
    if (_joiningId == call.id ||
        _joinedId == call.id ||
        _abandonedCallId == call.id) {
      return;
    }
    _joiningId = call.id;
    try {
      Future<RtcCredentials> token() async => RtcCredentials.fromJson(
          await api.request('POST', '/calls/${call.id}/rtc-token', body: {}));
      final credentials = await token();
      if (!foreground ||
          activeCall?.id != call.id ||
          _disposed ||
          _abandonedCallId == call.id) {
        return;
      }
      await audio.join(credentials, token);
      if (!foreground ||
          activeCall?.id != call.id ||
          _disposed ||
          _abandonedCallId == call.id) {
        await audio.leave();
      } else {
        _joinedId = call.id;
      }
    } catch (e) {
      _showError(e);
      await audio.leave();
      if (activeCall?.id == call.id) await _endAfterFailure();
    } finally {
      _joiningId = '';
      _notify();
    }
  }

  Future<void> reportMedia() async {
    final call = activeCall;
    if (_disposed ||
        call == null ||
        call.ringing ||
        call.ended ||
        _mediaPosting ||
        api.token == null ||
        endingLocally) {
      return;
    }
    _mediaPosting = true;
    final session = _sessionRevision;
    try {
      await api.request('POST', '/calls/${call.id}/media',
          body: {'ready': foreground && _joinedId == call.id && audio.ready});
    } catch (e) {
      if (_disposed ||
          session != _sessionRevision ||
          activeCall?.id != call.id ||
          endingLocally) {
        return;
      }
      _showError(e);
      _notify();
    } finally {
      _mediaPosting = false;
    }
  }

  void _audioChanged() {
    if (_disposed) return;
    _notify();
    // Send readiness losses immediately; the media timer corroborates healthy intervals.
    if (!audio.ready) unawaited(reportMedia());
  }

  Future<void> _audioFailed(String code) async {
    if (_disposed || activeCall == null || endingLocally) return;
    error = 'Audio connection failed. Try another call.';
    errorCode = 'AUDIO_FAILED';
    diagnosticId = null;
    _errorFromSnapshot = false;
    await audio.leave();
    await _endAfterFailure();
    _notify();
  }

  Future<void> _endAfterFailure() async {
    final call = activeCall;
    if (call == null) return;
    await _stopLocally(call);
    try {
      await _stopOnServer(call);
    } catch (_) {
      // Keep persisted local hangup intent; the next snapshot retries without joining.
    }
  }

  Future<void> _stopLocally(CallSession call) async {
    // Release capture before any network or disk operation, including offline hangup.
    _abandonedCallId = call.id;
    _revision++;
    _joinedId = '';
    await audio.leave();
    _notify();
    await store.write('abandonedCallId', call.id);
  }

  Future<void> _stopOnServer(CallSession initial) async {
    if (_stopping) return;
    _stopping = true;
    try {
      var call = initial;
      for (var attempt = 0; attempt < 2; attempt++) {
        final action = call.ringing
            ? (call.listenerId == user?.id ? 'decline' : 'cancel')
            : 'end';
        try {
          final result = await api.request('POST', '/calls/${call.id}/$action',
              body: {'expectedVersion': call.version}, idempotencyKey: newId());
          final ended = CallSession.fromJson(result);
          if (!ended.ended) {
            throw const ApiFailure(
                'END_PENDING', 'Waiting for the server to end the call.');
          }
          _revision++;
          activeCall = null;
          lastCall = ended;
          _abandonedCallId = null;
          await store.delete('abandonedCallId');
          lastPath = '/history';
          await store.write('lastPath', lastPath);
          await loadHistory();
          return;
        } on ApiFailure catch (e) {
          if (e.status != 409 || attempt != 0) rethrow;
          call = CallSession.fromJson(
              await api.request('GET', '/calls/${call.id}'));
        }
      }
    } finally {
      _stopping = false;
      _notify();
    }
  }

  Future<void> loadHistory({bool append = false}) async {
    if (api.token == null ||
        _disposed ||
        historyLoading ||
        (append && historyCursor == null)) {
      return;
    }
    historyLoading = true;
    historyError = null;
    _historyRetryAppend = append;
    final session = _sessionRevision;
    final request = ++_historyRequest;
    _notify();
    try {
      final result = await api.request(
          'GET',
          append
              ? '/calls?cursor=${Uri.encodeQueryComponent(historyCursor!)}'
              : '/calls');
      if (session != _sessionRevision || _disposed) return;
      final page = (result['items'] as List)
          .map((j) => CallSession.fromJson(j as Json))
          .where((c) => c.ended)
          .toList();
      final unique = <String, CallSession>{
        for (final call in (append ? history : <CallSession>[])) call.id: call
      };
      for (final call in page) {
        unique[call.id] = call;
      }
      // Validate the full response before replacing previously loaded rows.
      final cursor = result['nextCursor'] as String?;
      history = unique.values.toList();
      historyCursor = cursor;
      historyLoaded = true;
      if (history.isNotEmpty) lastCall = history.first;
    } catch (e) {
      if (session != _sessionRevision || _disposed) return;
      historyError = e is ApiFailure
          ? e
          : const ApiFailure('INVALID_RESPONSE',
              'The server returned an unreadable response.');
      if (e is ApiFailure && e.status == 401) {
        _showError(e);
        await _clearSession();
      }
    } finally {
      if (request == _historyRequest) {
        historyLoading = false;
        _notify();
      }
    }
  }

  Future<void> retryHistory() => loadHistory(append: _historyRetryAppend);

  void clearHistoryError() {
    historyError = null;
    _notify();
  }

  Future<void> submitSafety(CallSession call, String reason,
          {required bool block}) =>
      perform(() async {
        if (block) {
          if (activeCall?.id == call.id) await _stopLocally(call);
          final target =
              call.customerId == user!.id ? call.listenerId : call.customerId;
          await api.request('PUT', '/blocks/$target', body: {});
          await refresh();
        }
        if (reason.trim().isNotEmpty) {
          await api.request('POST', '/reports',
              body: {'callId': call.id, 'reason': reason.trim()},
              idempotencyKey: newId());
        }
      });

  Future<void> setForeground(bool value) async {
    if (foreground == value) return;
    foreground = value;
    if (!value) {
      // First milestone is foreground-only; never imply unsupported background calling.
      await audio.leave();
      if (hasCall) await _endAfterFailure();
      if (user?.online == true) {
        try {
          await api.request('PUT', '/me/availability', body: {'online': false});
        } catch (_) {/* Presence TTL expires even when network is gone. */}
      }
    } else {
      await heartbeat();
      await refresh();
    }
    _notify();
  }

  Future<void> setLocale(String value) async {
    locale = ['en', 'ta'].contains(value) ? value : 'en';
    await store.write('locale', locale);
    _notify();
  }

  Future<void> setLanguage(String value) async {
    language = ['en', 'ta'].contains(value) ? value : 'ta';
    await store.write('language', language);
    if (api.token != null) {
      await perform(() async {
        await api.request('PUT', '/me/languages', body: {
          'languages': [language]
        });
        await refresh();
      });
    }
    _notify();
  }

  Future<void> navigate(String path) async {
    if (hasCall) return;
    lastPath =
        ['/home', '/history', '/profile'].contains(path) ? path : '/home';
    await store.write('lastPath', lastPath);
    if (lastPath == '/history') await loadHistory();
    _notify();
  }

  Future<void> logout() => perform(() async {
        await audio.leave();
        if (hasCall) await _endAfterFailure();
        try {
          await api.request('POST', '/auth/logout', body: {});
        } finally {
          await _clearSession();
        }
      });

  Future<void> _clearSession() async {
    final pending = _sessionCleanup;
    if (pending != null) return pending;
    final cleanup = Completer<void>();
    _sessionCleanup = cleanup.future;
    try {
      _invalidateSessionRequests();
      api.token = null;
      user = null;
      activeCall = null;
      lastCall = null;
      listeners = [];
      _resetHistory();
      balance = 0;
      held = 0;
      _joinedId = '';
      lastPath = '/home';
      await audio.leave();
      await store.delete('token');
      await store.write('lastPath', lastPath);
    } finally {
      // The caller still receives storage errors; this barrier only sequences
      // a later sign-in, whose token write can safely replace any old value.
      _sessionCleanup = null;
      cleanup.complete();
      _notify();
    }
  }

  void _invalidateSessionRequests() {
    _sessionRevision++;
    _snapshotRequest++;
    _polling = false;
    snapshotLoaded = false;
  }

  void _resetHistory() {
    _historyRequest++;
    history = [];
    historyCursor = null;
    historyLoading = false;
    historyLoaded = false;
    historyError = null;
    _historyRetryAppend = false;
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (busy) return;
    busy = true;
    error = null;
    errorCode = null;
    _errorFromSnapshot = false;
    diagnosticId = null;
    _notify();
    try {
      await operation();
    } catch (e) {
      _showError(e);
      await refresh();
    } finally {
      busy = false;
      _notify();
    }
  }

  void clearError() {
    error = null;
    errorCode = null;
    _errorFromSnapshot = false;
    diagnosticId = null;
    _notify();
  }

  void _showError(Object error, {bool fromSnapshot = false}) {
    _errorFromSnapshot = fromSnapshot;
    if (error is ApiFailure) {
      this.error = error.message;
      errorCode = error.code;
      diagnosticId = error.requestId;
      offline = error.code == 'OFFLINE';
    } else {
      this.error = 'Something went wrong. Try again.';
      errorCode = 'UNKNOWN';
      diagnosticId = null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _mediaTimer?.cancel();
    audio.onChanged = null;
    audio.onFailure = null;
    unawaited(audio.leave());
    api.close();
    super.dispose();
  }
}
