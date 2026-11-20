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
  int _joinAttempt = 0;
  String? _abandonedCallId;
  bool _stopping = false;
  int _revision = 0;
  bool _polling = false, _mediaPosting = false, _disposed = false;
  bool snapshotLoaded = false;
  bool get snapshotLoading => _polling;
  Timer? _pollTimer, _presenceTimer, _mediaTimer;
  int _videoPreviewRequest = 0;
  bool videoPreviewBusy = false, _videoPreviewRequested = false;
  String? videoPreviewError, _videoConsentCallId;
  DateTime? _lastServerContact;
  String text(String english, String tamil) => locale == 'ta' ? tamil : english;
  bool get isListener => user?.mode == AppMode.listener;
  bool get hasCall => activeCall != null && !activeCall!.ended;
  bool get endingLocally =>
      activeCall != null && activeCall!.id == _abandonedCallId;
  bool get canSwitch => user?.listenerApproved == true && !hasCall && !busy;
  CallVideo? get video => audio is CallVideo ? audio as CallVideo : null;
  bool get needsVideoConsent =>
      hasCall &&
      activeCall!.isVideo &&
      !activeCall!.ringing &&
      !endingLocally &&
      _videoConsentCallId != activeCall!.id;

  Future<void> prepareVideoPreview() async {
    if (_disposed || !foreground || videoPreviewBusy) return;
    final camera = video;
    final request = ++_videoPreviewRequest;
    final session = _sessionRevision;
    final callId = activeCall?.id;
    videoPreviewError = null;
    videoPreviewBusy = true;
    _videoPreviewRequested = true;
    _notify();
    bool current() =>
        !_disposed &&
        foreground &&
        request == _videoPreviewRequest &&
        session == _sessionRevision &&
        callId == activeCall?.id;
    try {
      if (camera == null ||
          api.token == null ||
          (hasCall &&
              (!activeCall!.isVideo ||
                  (!activeCall!.ringing && !needsVideoConsent)))) {
        throw const ApiFailure(
            'VIDEO_UNAVAILABLE', 'Video preview is unavailable.');
      }
      final config = await api.request('GET', '/rtc/config');
      if (!current()) return;
      final appId = config['appId'];
      if (config['videoEnabled'] != true || appId is! String || appId.isEmpty) {
        throw const ApiFailure(
            'VIDEO_UNAVAILABLE', 'Video is unavailable on this test server.');
      }
      await camera.startPreview(appId);
      // closeVideoPreview invalidates SDK ownership too; never let an older
      // completion stop a newer preview or an accepted call's media engine.
    } catch (e) {
      if (!current()) return;
      videoPreviewError = e is ApiFailure ? e.code : 'VIDEO_FAILED';
      _videoPreviewRequested = false;
      await camera?.stopPreview();
    } finally {
      if (request == _videoPreviewRequest) {
        videoPreviewBusy = false;
        _notify();
      }
    }
  }

  Future<void> closeVideoPreview() async {
    _videoPreviewRequest++;
    videoPreviewBusy = false;
    _videoPreviewRequested = false;
    await video?.stopPreview();
    _notify();
  }

  Future<void> joinConsentedVideo() => perform(() async {
        final call = activeCall;
        if (call == null ||
            !needsVideoConsent ||
            video == null ||
            !foreground) {
          return;
        }
        await closeVideoPreview();
        if (_disposed || activeCall?.id != call.id || !foreground) return;
        await audio.checkPermission();
        _videoConsentCallId = call.id;
        await _join(call);
      });

  Future<void> setCameraEnabled(bool enabled) => perform(() async {
        final call = activeCall;
        if (call == null ||
            !call.isVideo ||
            endingLocally ||
            _joinedId != call.id ||
            video == null ||
            !foreground) {
          return;
        }
        try {
          await video!.setCameraEnabled(enabled);
        } catch (_) {
          if (_disposed || activeCall?.id != call.id || endingLocally) return;
          rethrow;
        }
        await reportMedia();
        _notify();
      });

  Future<void> switchCamera() => perform(() async {
        final camera = video;
        if (camera == null ||
            !camera.cameraEnabled ||
            !foreground ||
            endingLocally) {
          return;
        }
        if (!camera.previewing &&
            (_joinedId != activeCall?.id || activeCall?.isVideo != true)) {
          return;
        }
        await camera.switchCamera();
        _notify();
      });

  Future<void> endVideoForAudio() async {
    if (activeCall?.isVideo == true) await transition('end');
  }

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
        await closeVideoPreview();
        _videoConsentCallId = null;
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
          _videoConsentCallId = null;
          await closeVideoPreview();
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
            (!next.isVideo || _videoConsentCallId == next.id) &&
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

  Future<void> startCall(ListenerProfile listener,
          {bool video = false, bool cameraConsent = false}) =>
      perform(() async {
        if (video && !cameraConsent) {
          throw const ApiFailure('VIDEO_CONSENT_REQUIRED',
              'Review the camera and consent before calling.');
        }
        final rate = video ? listener.videoRate : listener.rate;
        if (rate == null || (video && this.video == null)) {
          throw const ApiFailure(
              'VIDEO_UNAVAILABLE', 'Video calling is unavailable.');
        }
        await closeVideoPreview();
        await audio.checkPermission();
        if (_disposed || !foreground) return;
        _revision++;
        final session = _sessionRevision;
        final response = await api.request('POST', '/calls',
            body: {
              'listenerId': listener.id,
              'quoteId': rate.id,
              if (video) 'mediaType': 'video',
              if (video) 'videoConsent': true,
            },
            idempotencyKey: newId());
        if (_disposed || session != _sessionRevision) return;
        activeCall = CallSession.fromJson(response);
        _videoConsentCallId = video && foreground ? activeCall!.id : null;
        _revision++;
        if (!foreground) await _endAfterFailure();
      });

  Future<void> transition(String action, {bool cameraConsent = false}) {
    // End must remain available while permission, token or camera operations wait.
    if (['end', 'cancel', 'decline'].contains(action)) return _terminateCall();
    return perform(() async {
      final call = activeCall;
      if (call == null) return;
      final session = _sessionRevision;
      if (action == 'accept') {
        if (call.isVideo && !cameraConsent) {
          throw const ApiFailure('VIDEO_CONSENT_REQUIRED',
              'Review the camera and consent before accepting.');
        }
        if (call.isVideo && video == null) {
          throw const ApiFailure(
              'VIDEO_UNAVAILABLE', 'Video calling is unavailable.');
        }
        await closeVideoPreview();
        await audio.checkPermission();
        if (_disposed || !foreground || activeCall?.id != call.id) return;
      }
      _revision++;
      final result = await api.request('POST', '/calls/${call.id}/$action',
          body: {
            'expectedVersion': call.version,
            if (action == 'accept' && call.isVideo) 'videoConsent': true
          },
          idempotencyKey: newId());
      if (_disposed ||
          session != _sessionRevision ||
          activeCall?.id != call.id ||
          endingLocally) {
        return;
      }
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
        if (updated.isVideo && cameraConsent && foreground) {
          _videoConsentCallId = updated.id;
        }
        if (!updated.ringing) unawaited(_join(updated));
      }
      await refresh();
    });
  }

  Future<void> _terminateCall() async {
    final call = activeCall;
    if (_disposed || call == null || endingLocally) return;
    clearError();
    try {
      await _stopLocally(call);
      await _stopOnServer(call);
    } catch (e) {
      if (!_disposed && activeCall?.id == call.id) _showError(e);
    } finally {
      _notify();
    }
  }

  Future<void> _join(CallSession call) async {
    if (_joiningId == call.id ||
        _joinedId == call.id ||
        _abandonedCallId == call.id ||
        (call.isVideo && (_videoConsentCallId != call.id || video == null))) {
      return;
    }
    final attempt = ++_joinAttempt;
    _joiningId = call.id;
    final session = _sessionRevision;
    bool authorized() =>
        !_disposed &&
        foreground &&
        session == _sessionRevision &&
        activeCall?.id == call.id &&
        !activeCall!.ended &&
        _abandonedCallId != call.id &&
        (!call.isVideo || _videoConsentCallId == call.id);
    try {
      Future<RtcCredentials> token() async => RtcCredentials.fromJson(
          await api.request('POST', '/calls/${call.id}/rtc-token', body: {}));
      final credentials = await token();
      if (!authorized()) return;
      if (credentials.mediaType != call.mediaType) {
        throw const ApiFailure(
            'INVALID_RESPONSE', 'Media authorization does not match the call.');
      }
      if (call.isVideo) {
        await video!.joinVideo(credentials, token);
      } else {
        await audio.join(credentials, token);
      }
      if (!authorized()) {
        // An older SDK join can finish after End and a new call has joined.
        // Only the current attempt may tear down the shared media adapter.
        if (attempt == _joinAttempt) await audio.leave();
      } else {
        _joinedId = call.id;
      }
    } catch (e) {
      if (!authorized()) return;
      _showError(e);
      await audio.leave();
      if (activeCall?.id == call.id) await _endAfterFailure();
    } finally {
      if (attempt == _joinAttempt) _joiningId = '';
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
      await api.request('POST', '/calls/${call.id}/media', body: {
        'ready': foreground && _joinedId == call.id && audio.ready,
        if (call.isVideo)
          'videoReady': foreground &&
              _joinedId == call.id &&
              _videoConsentCallId == call.id &&
              video?.videoReady == true
      });
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
    if (!audio.ready ||
        (activeCall?.isVideo == true && video?.videoReady != true)) {
      unawaited(reportMedia());
    }
  }

  Future<void> _audioFailed(String code) async {
    if (!_disposed &&
        (_videoPreviewRequested ||
            videoPreviewBusy ||
            video?.previewing == true)) {
      _videoPreviewRequest++;
      _videoPreviewRequested = videoPreviewBusy = false;
      videoPreviewError = 'VIDEO_FAILED';
      await video?.stopPreview();
      _notify();
      return;
    }
    if (_disposed || activeCall == null || endingLocally) return;
    error = 'Audio connection failed. Try another call.';
    errorCode = activeCall!.isVideo ? 'VIDEO_FAILED' : 'AUDIO_FAILED';
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
    _videoConsentCallId = null;
    _revision++;
    _joinedId = '';
    await closeVideoPreview();
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
      _revision++;
      _videoConsentCallId = null;
      await closeVideoPreview();
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
        _videoConsentCallId = null;
        await closeVideoPreview();
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
      _videoConsentCallId = null;
      await closeVideoPreview();
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
    _videoPreviewRequest++;
    _videoPreviewRequested = videoPreviewBusy = false;
    _videoConsentCallId = null;
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
