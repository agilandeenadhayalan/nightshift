import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'audio.dart';
import 'models.dart';
import 'session_store.dart';
import 'firebase_identity_client.dart';
import 'phone_sign_in.dart';
import 'account_privacy.dart';
import 'listener_application.dart';
import 'review_sample_picker.dart';
import 'native_firebase_identity.dart';
import 'discovery.dart';
import 'directory_events.dart';

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
      FirebaseIdentityClient? identityClient,
      NightShiftApi? receiptApi,
      ReviewSamplePicker? samplePicker,
      DirectoryEvents? directoryEvents,
      this.startTimers = true,
      this.developmentEnabled = !kReleaseMode})
      : firebase = identityClient ?? NativeFirebaseIdentityClient() {
    discovery = Discovery(
        api: api,
        identity: () => (user?.id, _identityRevision),
        enabled: () =>
            !_disposed &&
            foreground &&
            user != null &&
            !needsOnboarding &&
            api.token != null,
        events:
            directoryEvents ?? (startTimers ? SocketDirectoryEvents() : null),
        startTimer: startTimers)
      ..addListener(_notify);
    audio.onChanged = _audioChanged;
    audio.onFailure = (code) => unawaited(_audioFailed(code));
    phoneSignIn = PhoneSignIn(
        api: api,
        firebase: firebase,
        deviceId: () => _deviceId,
        onAuthenticated: (tokens, result) {
          final attempt = phoneSignIn.attemptRevision;
          return _acceptPhoneSession(tokens, result,
              isCurrent: () => phoneSignIn.isCurrentAttempt(attempt));
        })
      ..addListener(_notify);
    api.prepareSession = _ensurePhoneSession;
    api.sessionIdentity = () => (user?.id, _identityRevision);
    listenerApplication = ListenerApplication(
        api: api, currentUserId: () => user?.id, picker: samplePicker)
      ..addListener(_notify);
    privacy = AccountPrivacy(
        api: api,
        store: store,
        backendUrl: phoneSignIn.backendUrl,
        currentUserId: () => user?.id,
        receiptApi: receiptApi,
        onDeleted: (owner) async {
          if (user?.id == owner) await _clearSession();
        })
      ..addListener(_notify);
  }
  late final Discovery discovery;
  Object get accountIdentity => (user?.id, _identityRevision, api.baseUrl);
  bool canCallListener(ListenerProfile listener) =>
      foreground &&
      user != null &&
      !isListener &&
      !hasCall &&
      !offline &&
      (discovery.tracking || discovery.observed(listener.id)
          ? discovery.callable(listener.id)
          : listener.available);
  final NightShiftApi api;
  final SessionStore store;
  final CallAudio audio;
  final bool startTimers;
  final bool developmentEnabled;
  final FirebaseIdentityClient firebase;
  late final PhoneSignIn phoneSignIn;
  late final AccountPrivacy privacy;
  late final ListenerApplication listenerApplication;
  FirebaseTokens? _phoneTokens;
  Future<void>? _phoneRenewal;
  Future<void> _phoneStorage = Future<void>.value();
  bool needsOnboarding = false, canRestorePhoneSession = false;
  Json? onboardingProfile;
  UserProfile? user;
  CallSession? activeCall, lastCall;
  List<ListenerProfile> listeners = [];
  List<CallSession> history = [];
  String? historyCursor;
  bool historyLoading = false, historyLoaded = false;
  ApiFailure? historyError;
  bool _historyRetryAppend = false;
  int _sessionRevision = 0, _historyRequest = 0, _snapshotRequest = 0;
  int _identityRevision = 0;
  int _availabilityIntent = 0;
  Future<void> _availabilityWork = Future<void>.value();
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
      await privacy.initialize();
      locale = await store.read('locale') ?? 'en';
      language = await store.read('language') ?? 'ta';
      if (!['en', 'ta'].contains(locale)) locale = 'en';
      if (!['en', 'ta'].contains(language)) language = 'ta';
      discovery.language = language;
      _abandonedCallId = await store.read('abandonedCallId');
      lastPath = await store.read('lastPath') ?? '/home';
      if (!['/home', '/history', '/profile'].contains(lastPath)) {
        lastPath = '/home';
      }
      api.baseUrl = await store.read('baseUrl') ?? api.baseUrl;
      _deviceId = await store.read('deviceId') ?? newId();
      await store.write('deviceId', _deviceId);
      canRestorePhoneSession = await store.read('phoneSession') != null;
      if (canRestorePhoneSession) {
        await _restorePhoneSession();
      } else {
        if (firebase is PhoneIdentityClient) {
          // SDK persistence alone is not an accepted NightShift session.
          await (firebase as PhoneIdentityClient).signOut();
        }
        api.token = await store.read('token');
      }
      if (api.token != null && !needsOnboarding) {
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
        phoneSignIn.reset();
        if (firebase is PhoneIdentityClient) {
          await (firebase as PhoneIdentityClient).signOut();
        }
        _phoneTokens = null;
        needsOnboarding = canRestorePhoneSession = false;
        onboardingProfile = null;
        await store.delete('phoneSession');
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

  Future<void> _acceptPhoneSession(FirebaseTokens tokens, Json result,
      {bool Function()? isCurrent}) async {
    final priorSession = _sessionRevision;
    await _sessionCleanup;
    if (_disposed ||
        priorSession != _sessionRevision ||
        isCurrent?.call() == false) {
      if (firebase is PhoneIdentityClient) {
        await (firebase as PhoneIdentityClient).discard(tokens);
      }
      return;
    }
    final UserProfile acceptedUser;
    try {
      if (result['token'] != tokens.idToken ||
          result['needsOnboarding'] is! bool) {
        throw const ApiFailure('INVALID_RESPONSE', 'Invalid identity session.');
      }
      acceptedUser = UserProfile.fromJson(result['user'] as Json);
    } catch (_) {
      if (firebase is PhoneIdentityClient) {
        await (firebase as PhoneIdentityClient).discard(tokens);
      }
      throw const ApiFailure('INVALID_RESPONSE', 'Invalid identity session.');
    }
    _invalidateSessionRequests();
    _resetHistory();
    final session = _sessionRevision;
    try {
      await _savePhoneTokens(tokens, session);
    } catch (_) {
      await _discardUnacceptedPhoneTokens(tokens, session);
      rethrow;
    }
    if (_disposed ||
        session != _sessionRevision ||
        isCurrent?.call() == false) {
      await _discardUnacceptedPhoneTokens(tokens, session);
      return;
    }
    _phoneTokens = tokens;
    api.token = tokens.idToken;
    needsOnboarding = result['needsOnboarding'] as bool;
    user = acceptedUser;
    canRestorePhoneSession = true;
    if (needsOnboarding) {
      await loadOnboarding();
    } else {
      await refresh();
    }
    _notify();
  }

  Future<void> _discardUnacceptedPhoneTokens(
      FirebaseTokens tokens, int session) async {
    final previous = _phoneStorage;
    final cleanup = (() async {
      await previous;
      if (session != _sessionRevision) return;
      await store.delete('token');
      await store.delete('phoneSession');
    })();
    // Any later accepted session writes after this deletion, never before it.
    _phoneStorage = cleanup.catchError((Object _) {});
    try {
      await cleanup;
    } finally {
      if (firebase is PhoneIdentityClient) {
        await (firebase as PhoneIdentityClient).discard(tokens);
      }
    }
  }

  Future<void> _restorePhoneSession() async {
    api.token = null;
    final session = _sessionRevision;
    final raw = await store.read('phoneSession');
    if (raw == null) return;
    try {
      final saved = jsonDecode(raw) as Json;
      // Refresh credentials must not be restored against a different backend.
      if (!phoneSignIn.safeBackend ||
          saved['baseUrl'] != phoneSignIn.backendUrl ||
          saved['baseUrl'] != api.baseUrl) {
        throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.',
            status: 401);
      }
      final FirebaseTokens tokens;
      if (firebase is PhoneIdentityClient) {
        if (saved['provider'] != 'firebase-native' || saved['uid'] is! String) {
          throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
              status: 401);
        }
        tokens = await (firebase as PhoneIdentityClient)
            .restore(saved['uid'] as String);
      } else {
        if (saved['refreshToken'] is! String) {
          throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
              status: 401);
        }
        tokens = await firebase.refresh(saved['refreshToken'] as String);
      }
      if (_disposed || session != _sessionRevision) return;
      final result = await api.request('POST', '/auth/exchange',
          body: {'idToken': tokens.idToken, 'deviceId': _deviceId});
      if (_disposed || session != _sessionRevision) return;
      await _acceptPhoneSession(tokens, result);
    } on ApiFailure catch (e) {
      if (e.status == 401 && !_disposed && session == _sessionRevision) {
        await _clearSession();
      }
      rethrow;
    }
  }

  Future<void> restorePhoneSession() => perform(_restorePhoneSession);

  Future<void> _ensurePhoneSession() async {
    final tokens = _phoneTokens;
    if (tokens != null &&
        (!phoneSignIn.safeBackend || api.baseUrl != phoneSignIn.backendUrl)) {
      throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.', status: 401);
    }
    if (tokens == null ||
        tokens.expiresAt.difference(DateTime.now()).inSeconds > 60) {
      return;
    }
    if (_phoneRenewal != null) return _phoneRenewal;
    final session = _sessionRevision;
    final renewal = Completer<void>();
    _phoneRenewal = renewal.future;
    try {
      final next =
          await firebase.refresh(tokens.nativeUid ?? tokens.refreshToken);
      if (_disposed || session != _sessionRevision) {
        throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
            status: 401);
      }
      final result = await api.request('POST', '/auth/exchange',
          body: {'idToken': next.idToken, 'deviceId': _deviceId});
      if (_disposed || session != _sessionRevision) {
        throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
            status: 401);
      }
      if (result['token'] != next.idToken || result['user']['id'] != user?.id) {
        throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.',
            status: 401);
      }
      _phoneTokens = next;
      api.token = next.idToken;
      // In-flight responses using the predecessor token lose authority here.
      // In particular, a delayed 401 must not erase the freshly renewed session.
      _sessionRevision++;
      await _savePhoneTokens(next, _sessionRevision);
      renewal.complete();
    } catch (e, stack) {
      renewal.completeError(e, stack);
    } finally {
      _phoneRenewal = null;
    }
    return renewal.future;
  }

  Future<void> _savePhoneTokens(FirebaseTokens tokens, int session) {
    final previous = _phoneStorage;
    final baseUrl = api.baseUrl;
    final write = (() async {
      await previous;
      if (_disposed || session != _sessionRevision) return;
      await store.write(
          'phoneSession',
          jsonEncode(tokens.nativeUid != null
              ? {
                  'provider': 'firebase-native',
                  'uid': tokens.nativeUid,
                  'baseUrl': baseUrl
                }
              : {'refreshToken': tokens.refreshToken, 'baseUrl': baseUrl}));
      if (_disposed || session != _sessionRevision) return;
      await store.write('token', tokens.idToken);
      if (_disposed || session != _sessionRevision) return;
      await store.write('baseUrl', baseUrl);
    })();
    _phoneStorage = write.catchError((Object _) {});
    return write;
  }

  Future<void> loadOnboarding() async {
    final identity = _identityRevision, owner = user?.id, origin = api.baseUrl;
    bool current() =>
        !_disposed &&
        identity == _identityRevision &&
        user?.id == owner &&
        api.baseUrl == origin;
    final result = await api.privateRequest('GET', '/me/onboarding',
        origin: origin, isCurrent: current);
    if (!current()) return;
    onboardingProfile = result['profile'] as Json;
    needsOnboarding = result['required'] == true;
    _notify();
  }

  Future<void> completeOnboarding(Json profile) => perform(() async {
        final identity = _identityRevision,
            owner = user?.id,
            origin = api.baseUrl;
        bool current() =>
            !_disposed &&
            identity == _identityRevision &&
            user?.id == owner &&
            api.baseUrl == origin;
        final birth = profile['dateOfBirth'];
        final parsed = birth is String ? DateTime.tryParse(birth) : null;
        if (birth is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birth) ||
            parsed == null ||
            parsed.toIso8601String().substring(0, 10) != birth) {
          throw const ApiFailure(
              'INVALID_BIRTH_DATE', 'Enter a valid date of birth.');
        }
        Json result;
        try {
          result = await api.privateRequest('PUT', '/me/onboarding',
              origin: origin,
              isCurrent: current,
              body: {...profile, 'consentVersion': 'adult-onboarding-v1'});
        } on ApiFailure catch (e) {
          if (current() && ['ADULT_ONLY', 'DOB_IMMUTABLE'].contains(e.code)) {
            try {
              await loadOnboarding();
            } catch (_) {/* Preserve the age-gate error. */}
          }
          rethrow;
        }
        if (!current()) return;
        onboardingProfile = result['profile'] as Json;
        needsOnboarding = result['required'] == true;
        if (needsOnboarding) return;
        await setLocale(profile['interfaceLanguage'] as String);
        await refresh();
      });

  Future<void> refresh() async {
    if (api.token == null ||
        needsOnboarding ||
        !foreground ||
        _polling ||
        _disposed) {
      return;
    }
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
    if (api.token == null || needsOnboarding || !foreground || _disposed) {
      return;
    }
    final session = _sessionRevision, intent = _availabilityIntent;
    final owner = user?.id, origin = api.baseUrl;
    try {
      await api.request('POST', '/presence/heartbeat', body: {});
    } catch (e) {
      if (_disposed ||
          !foreground ||
          session != _sessionRevision ||
          intent != _availabilityIntent ||
          owner != user?.id ||
          origin != api.baseUrl ||
          api.token == null) {
        return;
      }
      _showError(e);
      _notify();
    }
  }

  Future<Json?> _writeAvailability(bool online,
      {required bool Function() isCurrent}) {
    final previous = _availabilityWork;
    final operation = (() async {
      await previous;
      if (!isCurrent()) return null;
      return api.request('PUT', '/me/availability', body: {'online': online});
    })();
    // Serialize withdrawal after any dispatched enable. A newer explicit enable
    // then follows withdrawal, so an old background completion cannot undo it.
    _availabilityWork = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> setOnline(bool value) => perform(() async {
        if (value && !foreground) return;
        final identity = _identityRevision, intent = ++_availabilityIntent;
        final owner = user?.id, origin = api.baseUrl;
        bool current() =>
            !_disposed &&
            identity == _identityRevision &&
            intent == _availabilityIntent &&
            owner == user?.id &&
            origin == api.baseUrl &&
            api.token != null;
        final Json? result;
        try {
          result = await _writeAvailability(value, isCurrent: current);
        } catch (_) {
          if (!current()) return;
          rethrow;
        }
        if (!current() || result == null) return;
        final profile = UserProfile.fromJson(result);
        if (profile.id != owner) {
          throw const ApiFailure(
              'INVALID_RESPONSE', 'Invalid account response.');
        }
        _revision++;
        user = profile;
        if (value) await heartbeat();
        if (!current()) return;
        await refresh();
      });

  Future<void> switchMode() => perform(() async {
        if (!canSwitch &&
            !(busy && user?.listenerApproved == true && !hasCall)) {
          return;
        }
        final identity = _identityRevision;
        final owner = user?.id, origin = api.baseUrl;
        bool current() =>
            !_disposed &&
            identity == _identityRevision &&
            owner == user?.id &&
            origin == api.baseUrl &&
            api.token != null;
        final Json result;
        try {
          result = await api.request('PUT', '/me/mode',
              body: {'mode': isListener ? 'customer' : 'listener'});
        } catch (_) {
          if (!current()) return;
          rethrow;
        }
        if (!current()) return;
        final profile = UserProfile.fromJson(result);
        if (profile.id != owner) {
          throw const ApiFailure(
              'INVALID_RESPONSE', 'Invalid account response.');
        }
        // A poll already in flight must not undo the server-approved mode.
        _revision++;
        _availabilityIntent++;
        user = profile;
        lastPath = '/home';
        await store.write('lastPath', lastPath);
        if (!current()) return;
        await refresh();
      });

  Future<void> startCall(ListenerProfile listener,
          {bool video = false, bool cameraConsent = false}) =>
      perform(() async {
        final identity = accountIdentity;
        bool current() =>
            !_disposed && identity == accountIdentity && foreground;
        if (!canCallListener(listener)) {
          throw const ApiFailure(
              'LISTENER_UNAVAILABLE', 'Refresh availability before calling.');
        }
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
        if (!current()) return;
        if (!canCallListener(listener)) {
          throw const ApiFailure(
              'LISTENER_UNAVAILABLE', 'Listener is no longer available.');
        }
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
        final owner = accountIdentity, ownerId = user?.id;
        if (ownerId == null ||
            (call.customerId != ownerId && call.listenerId != ownerId)) {
          return;
        }
        if (block) {
          if (activeCall?.id == call.id) await _stopLocally(call);
          if (owner != accountIdentity) return;
          final target =
              call.customerId == user!.id ? call.listenerId : call.customerId;
          await api.request('PUT', '/blocks/$target', body: {});
          if (owner != accountIdentity) return;
          discovery.forget(target);
          await refresh();
        }
        if (reason.trim().isNotEmpty && owner == accountIdentity) {
          await api.request('POST', '/reports',
              body: {'callId': call.id, 'reason': reason.trim()},
              idempotencyKey: newId());
        }
      });

  Future<void> setForeground(bool value) async {
    if (foreground == value) return;
    foreground = value;
    discovery.reconcile();
    if (!value) {
      final identity = _identityRevision, intent = ++_availabilityIntent;
      final owner = user?.id, origin = api.baseUrl;
      final backgroundCall = activeCall;
      bool current() =>
          !_disposed &&
          identity == _identityRevision &&
          intent == _availabilityIntent &&
          owner == user?.id &&
          origin == api.baseUrl &&
          api.token != null;
      // Cached online=false can hide an enable still in flight. Queue withdrawal
      // now, for this owner only, and retain it across a quick foreground return.
      final withdrawal = isListener && user?.listenerApproved == true
          ? _writeAvailability(false, isCurrent: current)
              .catchError((Object _) {
              // Presence TTL expires when the control connection is unavailable.
              return null;
            })
          : Future<Json?>.value();
      _revision++;
      _videoConsentCallId = null;
      await closeVideoPreview();
      // First milestone is foreground-only; never imply unsupported background calling.
      await audio.leave();
      if (current() &&
          backgroundCall != null &&
          activeCall?.id == backgroundCall.id &&
          hasCall) {
        await _endAfterFailure();
      }
      final result = await withdrawal;
      if (current() && result != null && result['id'] == owner) {
        // A quick foreground return can have read online before withdrawal
        // committed. Publish this authoritative result and reject that old poll.
        _revision++;
        user = UserProfile.fromJson(result);
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
    await discovery.filter(language: language);
    await store.write('language', language);
    if (api.token != null) {
      await refresh();
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
      api.token = null;
      _phoneTokens = null;
      if (firebase is PhoneIdentityClient) {
        // Native SDK cleanup may still be blocked by its earlier operation.
        // App access and its durable acceptance marker are cleared independently.
        unawaited((firebase as PhoneIdentityClient)
            .signOut()
            .catchError((Object _) {}));
      }
      privacy.clearPrivateView();
      listenerApplication.clearPrivateView();
      phoneSignIn.reset();
      needsOnboarding = canRestorePhoneSession = false;
      onboardingProfile = null;
      user = null;
      activeCall = null;
      lastCall = null;
      listeners = [];
      _resetHistory();
      balance = 0;
      held = 0;
      _joinedId = '';
      lastPath = '/home';
      await _phoneStorage;
      await store.delete('token');
      await store.delete('phoneSession');
      await store.write('lastPath', lastPath);
      await closeVideoPreview();
      await audio.leave();
    } finally {
      // The caller still receives storage errors; this barrier only sequences
      // a later sign-in, whose token write can safely replace any old value.
      _sessionCleanup = null;
      cleanup.complete();
      _notify();
    }
  }

  void _invalidateSessionRequests() {
    discovery.reset();
    _identityRevision++;
    _sessionRevision++;
    _availabilityIntent++;
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
    if (!_disposed) {
      discovery.reconcile();
      notifyListeners();
    }
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
    discovery.removeListener(_notify);
    discovery.dispose();
    api.close();
    phoneSignIn.removeListener(_notify);
    phoneSignIn.dispose();
    firebase.close();
    privacy.removeListener(_notify);
    privacy.dispose();
    listenerApplication.removeListener(_notify);
    listenerApplication.dispose();
    super.dispose();
  }
}
