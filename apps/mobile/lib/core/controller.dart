import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
import 'staff_workspace.dart';
import 'staff_session.dart';
import 'staff_transport.dart';
import 'matching.dart';
import 'call_invitations.dart';
import 'call_stop_intent.dart';
import 'media_diagnostics.dart';

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
      StaffWorkspace? staffWorkspace,
      StaffCookies? staffCookies,
      StaffTransport? staffTransport,
      InvitationDevice? invitationDevice,
      Duration Function()? diagnosticsNow,
      Timer Function(Duration, void Function())? diagnosticsTimerFactory,
      this.startTimers = true,
      this.developmentEnabled = !kReleaseMode})
      : firebase = identityClient ?? NativeFirebaseIdentityClient() {
    _mediaDiagnostics = MediaDiagnostics(
        owner: () => _disposed || user == null ? null : accountIdentity,
        origin: () => api.baseUrl,
        monotonicNow: diagnosticsNow,
        timerFactory: diagnosticsTimerFactory,
        onChanged: () {
          // Observation never enters _notify's discovery/matching reconciler.
          if (!_disposed) notifyListeners();
        });
    this.staffWorkspace = staffWorkspace ??
        StaffWorkspace(
            identity: () => user == null ? null : accountIdentity,
            ownerId: () => user?.id,
            enabled: () =>
                !_disposed &&
                foreground &&
                user != null &&
                !needsOnboarding &&
                !hasCall,
            proof: _staffProof,
            cookies: staffCookies,
            transport: staffTransport,
            startTimer: startTimers);
    this.staffWorkspace.addListener(_notify);
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
    matching = Matching(
        api: api,
        identity: () => user == null ? null : accountIdentity,
        enabled: () =>
            !_disposed &&
            user != null &&
            snapshotLoaded &&
            !needsOnboarding &&
            !isListener &&
            api.token != null,
        foreground: () => foreground,
        startTimer: startTimers)
      ..addListener(_matchingChanged);
    invitations = CallInvitations(
        api: api,
        identity: () => user == null ? null : accountIdentity,
        ownerKey: _invitationOwnerKey,
        eligible: () =>
            !_disposed &&
            user != null &&
            !needsOnboarding &&
            isListener &&
            user!.listenerApproved &&
            _invitationOwnerKey() != null,
        foreground: () => foreground,
        locale: () => locale,
        onOpen: _openInvitation,
        device: invitationDevice,
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
  late final Matching matching;
  late final CallInvitations invitations;
  late final StaffWorkspace staffWorkspace;
  Object get accountIdentity => (user?.id, _identityRevision, api.baseUrl);
  late final MediaDiagnostics _mediaDiagnostics;
  MediaDiagnosticSink? _callDiagnosticSink;
  Object? _diagnosticOwner;
  String? _diagnosticCallId;
  bool _diagnosticJoinAttempted = false;

  MediaDiagnosticReceipt? get mediaDiagnostics => _mediaDiagnostics.snapshot;

  MediaDiagnosticReceipt? mediaDiagnosticsFor(String callId) {
    final receipt = mediaDiagnostics;
    return receipt?.callId == callId ? receipt : null;
  }

  String? exportMediaDiagnostics(
      {required Object expectedOwner,
      required String callId,
      required String receiptId,
      DiagnosticSymptom? symptom}) {
    if (_disposed || user == null || expectedOwner != accountIdentity) {
      return null;
    }
    final receipt = mediaDiagnosticsFor(callId);
    if (receipt == null || receipt.receiptId != receiptId) return null;
    final value = _mediaDiagnostics.export(symptom: symptom);
    return value == null ? null : jsonEncode(value);
  }

  void _observeDiagnosticCall(CallSession call) {
    final ownerId = user?.id;
    if (_disposed ||
        ownerId == null ||
        (call.customerId != ownerId && call.listenerId != ownerId)) {
      return;
    }
    if (_diagnosticOwner != accountIdentity || _diagnosticCallId != call.id) {
      _diagnosticOwner = accountIdentity;
      _diagnosticCallId = call.id;
      _diagnosticJoinAttempted = false;
      _callDiagnosticSink = _mediaDiagnostics.begin(
          owner: accountIdentity,
          callId: call.id,
          mediaType: call.isVideo
              ? DiagnosticMediaType.video
              : DiagnosticMediaType.audio);
      _callDiagnosticSink?.milestone(DiagnosticMilestone.callObserved);
    }
    // An ended, declined, cancelled or timed-out invitation does not establish
    // acceptance. This is an observation, never a claimed server timestamp.
    if (['connecting', 'connected', 'reconnecting'].contains(call.state)) {
      _callDiagnosticSink?.milestone(DiagnosticMilestone.acceptedObserved);
    }
    if (call.ended) {
      _callDiagnosticSink?.milestone(DiagnosticMilestone.callEndedObserved);
    }
  }

  MediaDiagnosticSink? _beginDiagnosticJoin(CallSession call) {
    _observeDiagnosticCall(call);
    if (_diagnosticOwner != accountIdentity || _diagnosticCallId != call.id) {
      return null;
    }
    if (_diagnosticJoinAttempted) {
      _callDiagnosticSink = _mediaDiagnostics.begin(
          owner: accountIdentity,
          callId: call.id,
          mediaType: call.isVideo
              ? DiagnosticMediaType.video
              : DiagnosticMediaType.audio);
    }
    _diagnosticJoinAttempted = true;
    return _callDiagnosticSink;
  }

  bool canCallListener(ListenerProfile listener, {bool video = false}) =>
      foreground &&
      user != null &&
      !isListener &&
      !hasCall &&
      !matching.blocked &&
      !offline &&
      (!video ||
          (discovery.lookup(listener.id) ?? listener).reachability ==
              'foreground') &&
      (discovery.tracking || discovery.observed(listener.id)
          ? discovery.callable(listener.id)
          : listener.available);

  String? _invitationOwnerKey() {
    if (_phoneTokens == null || user == null) return null;
    try {
      final claims = jsonDecode(utf8.decode(base64Url.decode(
          base64Url.normalize(_phoneTokens!.idToken.split('.')[1])))) as Json;
      final authTime = claims['auth_time'];
      if (authTime is! int || authTime <= 0) return null;
      // Local association only; the server verifies canonical identity and lineage.
      return sha256
          .convert(
              utf8.encode('${user!.id}|$_deviceId|$authTime|${api.baseUrl}'))
          .toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openInvitation(Json hint) async {
    final owner = accountIdentity, origin = api.baseUrl;
    final id = hint['callId'];
    final remaining = hint['remainingMilliseconds'];
    final opening = Stopwatch()..start();
    if (id is! String ||
        remaining is! int ||
        remaining <= 0 ||
        remaining > 30000 ||
        !foreground ||
        !isListener ||
        user?.listenerApproved != true) {
      return;
    }
    bool current() =>
        !_disposed && foreground && owner == accountIdentity && isListener;
    final result = await api.privateRequest('GET', '/calls/$id',
        origin: origin, isCurrent: current);
    if (!current() || opening.elapsedMilliseconds >= remaining) return;
    final call = CallSession.fromJson(result);
    if (call.id != id ||
        call.listenerId != user?.id ||
        !call.ringing ||
        call.isVideo ||
        call.version != int.tryParse('${hint['callVersion']}')) {
      return;
    }
    // GET is only a hint refresh; the normal Answer action performs the server
    // expected-version/deadline transition and permission check separately.
    await refresh();
  }

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
  String? _abandonedCallId, _legacyStopCallId;
  CallStopIntent? _stopIntent, _storedStopIntent;
  Object? _stopOwner;
  Future<void> _stopStorage = Future<void>.value();
  final Map<(Object, String), Future<void>> _stopRequests = {};
  Future<void>? _logoutWork;
  Object? _logoutOwner;
  Future<void> _pathStorage = Future<void>.value();
  int _cleanupRevision = 0;
  Object? _cleanupOwner;
  String? _cleanupCallId;
  Future<void>? _cleanupWork;
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
  bool get canSwitch =>
      user?.listenerApproved == true && !hasCall && !busy && !matching.blocked;
  bool get showMatching =>
      !isListener && matching.ownsScreen && !(hasCall && !activeCall!.ringing);

  Object? _matchCallSeen;
  void _matchingChanged() {
    _notify();
    final request = matching.request;
    final signature = (request?.id, request?.version, request?.callId);
    if (request?.callId != null && foreground && signature != _matchCallSeen) {
      _matchCallSeen = signature;
      unawaited(refresh());
    }
  }

  Future<void> startMatching(
          {required String language, required bool consent}) =>
      perform(() async {
        final owner = accountIdentity;
        final presentation = matching.presentationRevision;
        if (!consent ||
            !matching.presented ||
            hasCall ||
            isListener ||
            !foreground ||
            matching.blocked ||
            user?.languages.contains(language) != true) {
          return;
        }
        await closeVideoPreview();
        await audio.checkPermission();
        if (_disposed ||
            owner != accountIdentity ||
            !foreground ||
            hasCall ||
            !matching.presented ||
            presentation != matching.presentationRevision ||
            user?.languages.contains(language) != true) {
          return;
        }
        await matching.start(language: language, consent: consent);
      });
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
      _legacyStopCallId = await store.read('abandonedCallId');
      final stop = await store.read('callStopIntent');
      if (stop != null) {
        try {
          if (stop.length > 8192) throw const FormatException();
          _storedStopIntent = CallStopIntent.fromJson(jsonDecode(stop) as Json);
        } catch (_) {
          // A malformed scoped record cannot fall back to an unowned mutation.
          _legacyStopCallId = null;
        }
      }
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
        await matching.recover();
        if (user != null && !hasCall && lastPath == '/history') {
          await loadHistory();
        }
      }
      await invitations.recover();
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
        await matching.recover();
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
      await matching.recover();
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

  Future<void> _ensurePhoneSession({bool force = false}) async {
    final tokens = _phoneTokens;
    if (tokens != null &&
        (!phoneSignIn.safeBackend || api.baseUrl != phoneSignIn.backendUrl)) {
      throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.', status: 401);
    }
    if (tokens == null ||
        (!force &&
            tokens.expiresAt.difference(DateTime.now()).inSeconds > 60)) {
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

  Future<String> _staffProof() async {
    final identity = accountIdentity;
    if (_phoneTokens?.nativeUid == null || firebase is! PhoneIdentityClient) {
      throw const ApiFailure(
          'STAFF_PHONE_SIGN_IN_REQUIRED', 'Sign in by phone.');
    }
    // Staff proof is one-use. Refresh and register the new native token for
    // each explicit opening; this does not change the original SMS auth_time.
    await _ensurePhoneSession(force: true);
    if (_disposed ||
        identity != accountIdentity ||
        user == null ||
        _phoneTokens?.nativeUid == null ||
        api.token == null ||
        api.token != _phoneTokens!.idToken ||
        !foreground ||
        hasCall) {
      throw const ApiFailure('STAFF_STALE', 'Staff access has closed.');
    }
    return api.token!;
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
      if (next != null) _observeDiagnosticCall(next);
      if (_errorFromSnapshot) {
        error = null;
        errorCode = null;
        diagnosticId = null;
        _errorFromSnapshot = false;
      }
      // Snapshot is authoritative; terminal sessions cannot retain the microphone.
      if (next == null || next.ended) {
        final owner = accountIdentity, origin = api.baseUrl;
        activeCall = null;
        if (_storedStopIntent == null ||
            (_storedStopIntent!.ownerId == user!.id &&
                _storedStopIntent!.origin == origin)) {
          _forgetStop(owner, origin);
        }
        if (previous != null && !previous.ended) {
          _requestCleanup(callId: previous.id);
          if (next != null) lastCall = next;
          lastPath = '/history';
          await _savePath();
          if (!_sameOwner(owner, origin) || activeCall != null) return;
          await loadHistory();
        }
        if (_sameOwner(owner, origin) && activeCall == null && next != null) {
          lastCall = next;
        }
      } else {
        activeCall = next;
        _recoverStop(next);
        if (endingLocally) {
          await _stopOnServer(next);
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
        _requestCleanup(callId: activeCall!.id);
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
        if (matching.blocked) return;
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
        await _savePath();
        if (!current()) return;
        await refresh();
      });

  Future<void> startCall(ListenerProfile listener,
          {bool video = false, bool cameraConsent = false}) =>
      perform(() async {
        final identity = accountIdentity;
        bool current() =>
            !_disposed && identity == accountIdentity && foreground;
        if (!matching.restored && !isListener) await matching.recover();
        if (!current()) return;
        if (!matching.restored) {
          throw const ApiFailure(
              'MATCH_STATUS_UNKNOWN', 'Recover search status first.');
        }
        if (!canCallListener(listener, video: video)) {
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
        if (!canCallListener(listener, video: video)) {
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
        _observeDiagnosticCall(activeCall!);
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
      final owner = accountIdentity, origin = api.baseUrl;
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
        try {
          await audio.checkPermission();
        } catch (failure) {
          if (_sameOwner(owner, origin) && activeCall?.id == call.id) {
            _observeDiagnosticCall(call);
            _callDiagnosticSink?.failure(_diagnosticFailure(failure));
          }
          rethrow;
        }
        if (!_sameOwner(owner, origin) ||
            !foreground ||
            activeCall?.id != call.id ||
            endingLocally) {
          return;
        }
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
      _observeDiagnosticCall(updated);
      _revision++;
      if (updated.ended) {
        activeCall = null;
        _requestCleanup(callId: call.id);
        lastCall = updated;
        lastPath = '/history';
        await _savePath();
        if (!_sameOwner(owner, origin) || activeCall != null) return;
        await loadHistory();
      } else {
        activeCall = updated;
        if (updated.isVideo && cameraConsent && foreground) {
          _videoConsentCallId = updated.id;
        }
        if (!updated.ringing) unawaited(_join(updated));
      }
      if (_sameOwner(owner, origin)) await refresh();
    });
  }

  bool _sameOwner(Object owner, String origin) =>
      !_disposed && owner == accountIdentity && origin == api.baseUrl;

  /// Admission invalidates readiness synchronously. Completion is observed, never
  /// used as permission to resume media or as a prerequisite for server End.
  void _requestCleanup({String? callId}) {
    final owner = accountIdentity, origin = api.baseUrl;
    if (_cleanupOwner == owner &&
        _cleanupCallId == callId &&
        _cleanupWork != null) {
      return;
    }
    final revision = ++_cleanupRevision;
    _cleanupOwner = owner;
    _cleanupCallId = callId;
    _joinedId = '';
    _joiningId = '';
    _joinAttempt++;
    _videoConsentCallId = null;
    _videoPreviewRequest++;
    _videoPreviewRequested = videoPreviewBusy = false;
    late final Future<void> work;
    work = Future<void>.sync(audio.leave).catchError((Object failure) {
      if (revision != _cleanupRevision ||
          !_sameOwner(owner, origin) ||
          (activeCall != null && activeCall!.id != callId)) {
        return;
      }
      _showError(failure is ApiFailure &&
              ['RTC_CLEANUP_PENDING', 'RTC_CLEANUP_FAILED']
                  .contains(failure.code)
          ? failure
          : const ApiFailure(
              'RTC_CLEANUP_FAILED', 'Media cleanup was not confirmed.'));
      _notify();
    }).whenComplete(() {
      if (identical(_cleanupWork, work)) _cleanupWork = null;
    });
    _cleanupWork = work;
    _notify();
  }

  bool _ownsStop(CallStopIntent intent, Object owner) =>
      _sameOwner(owner, intent.origin) &&
      intent.ownerId == user?.id &&
      identical(_stopIntent, intent) &&
      _stopOwner == owner &&
      activeCall?.id == intent.callId;

  void _persistStop(CallStopIntent intent, Object owner) {
    _storedStopIntent = intent;
    _stopStorage = _stopStorage.then((_) async {
      // A queued receipt survives local logout. It carries no credentials and
      // can be recovered only from an exact current owner/origin/call snapshot.
      // A newer receipt or authoritative terminal result supersedes this write.
      if (!identical(_storedStopIntent, intent)) return;
      await store.write('callStopIntent', jsonEncode(intent.toJson()));
      if (!identical(_storedStopIntent, intent)) return;
      await store.write('abandonedCallId', intent.callId);
    }).catchError((Object failure) {
      if (_ownsStop(intent, owner)) {
        _showError(failure);
        _notify();
      }
    });
  }

  void _forgetStop(Object owner, String origin) {
    _stopIntent = null;
    _stopOwner = null;
    _abandonedCallId = null;
    _legacyStopCallId = null;
    _storedStopIntent = null;
    _stopStorage = _stopStorage.then((_) async {
      if (!_sameOwner(owner, origin) || _stopIntent != null) return;
      await store.delete('abandonedCallId');
      if (!_sameOwner(owner, origin) || _stopIntent != null) return;
      await store.delete('callStopIntent');
    }).catchError((Object failure) {
      if (_sameOwner(owner, origin) && _stopIntent == null) {
        _showError(failure);
        _notify();
      }
    });
  }

  void _recoverStop(CallSession call) {
    if (_stopIntent != null &&
        _stopOwner == accountIdentity &&
        _stopIntent!.callId == call.id) {
      return;
    }
    final saved = _storedStopIntent;
    if (saved != null) {
      if (saved.ownerId != user?.id ||
          saved.origin != api.baseUrl ||
          saved.callId != call.id) {
        _abandonedCallId = null;
        return;
      }
      _stopIntent = saved;
    } else if (_legacyStopCallId == call.id) {
      // Legacy markers are bound only by an authenticated current-call snapshot.
      _stopIntent = CallStopIntent.forCall(user!.id, api.baseUrl, call);
    } else {
      return;
    }
    _stopOwner = accountIdentity;
    _abandonedCallId = call.id;
    _requestCleanup(callId: call.id);
    _persistStop(_stopIntent!, _stopOwner!);
  }

  Future<void> _terminateCall() async {
    final call = activeCall;
    if (_disposed || call == null || endingLocally) return;
    final owner = accountIdentity, origin = api.baseUrl;
    clearError();
    try {
      _stopLocally(call);
      await _stopOnServer(call);
    } catch (e) {
      if (_sameOwner(owner, origin) && activeCall?.id == call.id) _showError(e);
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
    // Capture before token/permission/native work; callbacks may outlive it.
    final diagnostics = _beginDiagnosticJoin(call);
    var credentialsObtained = false;
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
      credentialsObtained = true;
      diagnostics?.milestone(DiagnosticMilestone.joinRequested);
      if (audio is CallAudioDiagnostics && diagnostics != null) {
        await (audio as CallAudioDiagnostics).joinWithDiagnostics(
            credentials, token,
            video: call.isVideo, sink: diagnostics);
      } else if (call.isVideo) {
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
      diagnostics?.failure(_diagnosticFailure(e,
          fallback: credentialsObtained
              ? DiagnosticFailure.joinFailed
              : DiagnosticFailure.credentialsUnavailable));
      _showError(e);
      await _endAfterFailure(call);
    } finally {
      if (attempt == _joinAttempt) _joiningId = '';
      _notify();
    }
  }

  DiagnosticFailure _diagnosticFailure(Object failure,
      {DiagnosticFailure fallback = DiagnosticFailure.mediaFailure}) {
    if (failure is ApiFailure) {
      if (failure.code == 'MICROPHONE_DENIED') {
        return DiagnosticFailure.microphoneDenied;
      }
      if (failure.code == 'CAMERA_DENIED') {
        return DiagnosticFailure.cameraDenied;
      }
    }
    return fallback;
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
      _requestCleanup(callId: activeCall?.id);
      _notify();
      return;
    }
    if (_disposed || activeCall == null || endingLocally) return;
    error = 'Audio connection failed. Try another call.';
    errorCode = activeCall!.isVideo ? 'VIDEO_FAILED' : 'AUDIO_FAILED';
    diagnosticId = null;
    _errorFromSnapshot = false;
    final call = activeCall!;
    await _endAfterFailure(call);
    _notify();
  }

  Future<void> _endAfterFailure([CallSession? original]) async {
    final call = original ?? activeCall;
    if (call == null) return;
    if (_disposed || activeCall?.id != call.id) return;
    _stopLocally(call);
    try {
      await _stopOnServer(call);
    } catch (_) {
      // Keep persisted local hangup intent; the next snapshot retries without joining.
    }
  }

  void _stopLocally(CallSession call) {
    if (_disposed || user == null || activeCall?.id != call.id) return;
    final owner = accountIdentity;
    if (_stopIntent?.callId != call.id || _stopOwner != owner) {
      _stopIntent = CallStopIntent.forCall(user!.id, api.baseUrl, call);
      _stopOwner = owner;
    }
    _abandonedCallId = call.id;
    _revision++;
    _requestCleanup(callId: call.id);
    _persistStop(_stopIntent!, owner);
  }

  Future<void> _stopOnServer(CallSession initial) {
    final intent = _stopIntent, owner = _stopOwner;
    if (intent == null ||
        owner == null ||
        intent.callId != initial.id ||
        !_ownsStop(intent, owner)) {
      return Future<void>.value();
    }
    final scope = (owner, initial.id),
        existing = _stopRequests[(owner, initial.id)];
    if (existing != null) return existing;
    late final Future<void> work;
    work = _sendStop(intent, owner).whenComplete(() {
      if (identical(_stopRequests[scope], work)) _stopRequests.remove(scope);
    });
    _stopRequests[scope] = work;
    return work;
  }

  Future<void> _sendStop(CallStopIntent initial, Object owner) async {
    var intent = initial;
    bool current() => _ownsStop(intent, owner);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        if (!current()) return;
        try {
          final result = await api.privateRequest('POST', intent.path,
              origin: intent.origin,
              isCurrent: current,
              body: intent.body,
              idempotencyKey: intent.key);
          if (!current()) return;
          final ended = CallSession.fromJson(result);
          if (ended.id != intent.callId || !ended.ended) {
            throw const ApiFailure(
                'END_PENDING', 'Waiting for the server to end the call.');
          }
          _observeDiagnosticCall(ended);
          _revision++;
          activeCall = null;
          lastCall = ended;
          _forgetStop(owner, intent.origin);
          lastPath = '/history';
          await _savePath();
          if (!_sameOwner(owner, intent.origin) || activeCall != null) return;
          await loadHistory();
          return;
        } on ApiFailure catch (e) {
          if (!current()) return;
          if (e.status != 409 || attempt != 0) rethrow;
          final result = await api.privateRequest(
              'GET', '/calls/${intent.callId}',
              origin: intent.origin, isCurrent: current);
          if (!current()) return;
          final call = CallSession.fromJson(result);
          if (call.id != intent.callId ||
              (call.customerId != intent.ownerId &&
                  call.listenerId != intent.ownerId)) {
            throw const ApiFailure('INVALID_RESPONSE', 'Invalid call state.');
          }
          _observeDiagnosticCall(call);
          intent = CallStopIntent.forCall(intent.ownerId, intent.origin, call);
          _stopIntent = intent;
          _persistStop(intent, owner);
        }
      }
    } finally {
      if (_sameOwner(owner, initial.origin)) _notify();
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
        final origin = api.baseUrl;
        bool current() => _sameOwner(owner, origin);
        if (ownerId == null ||
            (call.customerId != ownerId && call.listenerId != ownerId)) {
          return;
        }
        try {
          if (block) {
            if (activeCall?.id == call.id) _stopLocally(call);
            if (!current()) return;
            final target =
                call.customerId == ownerId ? call.listenerId : call.customerId;
            await api.request('PUT', '/blocks/$target', body: {});
            if (!current()) return;
            discovery.forget(target);
            await refresh();
          }
          if (reason.trim().isNotEmpty && current()) {
            await api.request('POST', '/reports',
                body: {'callId': call.id, 'reason': reason.trim()},
                idempotencyKey: newId());
          }
        } catch (_) {
          // A stale failure must not reach perform's error/recovery path under
          // a replacement identity. Current-owner failures retain that path.
          if (current()) rethrow;
        }
      });

  Future<void> setForeground(bool value) async {
    if (foreground == value) return;
    foreground = value;
    staffWorkspace.reconcile();
    discovery.reconcile();
    matching.reconcile();
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
      final withdrawal =
          isListener && user?.listenerApproved == true && !invitations.active
              ? _writeAvailability(false, isCurrent: current)
                  .catchError((Object _) {
                  // Presence TTL expires when the control connection is unavailable.
                  return null;
                })
              : Future<Json?>.value();
      _revision++;
      // First milestone is foreground-only; never imply unsupported background calling.
      _requestCleanup(callId: backgroundCall?.id);
      if (current() &&
          backgroundCall != null &&
          activeCall?.id == backgroundCall.id &&
          !(backgroundCall.ringing &&
              (matching.blocked ||
                  (isListener &&
                      !backgroundCall.isVideo &&
                      invitations.active))) &&
          hasCall) {
        await _endAfterFailure(backgroundCall);
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
      await matching.recover();
      await refresh();
      await invitations.recover();
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
    await _savePath();
    if (lastPath == '/history') await loadHistory();
    _notify();
  }

  Future<void> _savePath() {
    final owner = accountIdentity, origin = api.baseUrl, path = lastPath;
    final work = _pathStorage.then((_) async {
      if (_sameOwner(owner, origin)) await store.write('lastPath', path);
    });
    // Preserve ordering even when an older storage operation fails. Later
    // navigation/logout writes must follow any already-admitted older write.
    _pathStorage = work.catchError((Object _) {});
    return work;
  }

  Future<void> logout() {
    final owner = accountIdentity;
    final pending = _logoutWork;
    if (pending != null && _logoutOwner == owner) return pending;
    if (_disposed) return Future<void>.value();
    // The auth request captures this token synchronously. Local invalidation and
    // cleanup admission proceed even while another permission/SDK operation waits.
    _requestCleanup(callId: activeCall?.id);
    final remote = api
        .request('POST', '/auth/logout', body: {}).then<void>((_) {}, onError:
            (Object _) {/* Local logout does not depend on the network. */});
    final local = _clearSession();
    late final Future<void> work;
    work = Future.wait([local, remote]).then<void>((_) {}).whenComplete(() {
      if (identical(_logoutWork, work)) _logoutWork = null;
    });
    _logoutOwner = owner;
    _logoutWork = work;
    return work;
  }

  Future<void> _clearSession() async {
    final pending = _sessionCleanup;
    if (pending != null) return pending;
    final cleanup = Completer<void>();
    _sessionCleanup = cleanup.future;
    try {
      final call = activeCall;
      if (call != null && !call.ended && user != null) {
        _stopLocally(call);
      } else {
        _requestCleanup(callId: call?.id);
      }
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
      await _savePath();
    } finally {
      // The caller still receives storage errors; this barrier only sequences
      // a later sign-in, whose token write can safely replace any old value.
      _sessionCleanup = null;
      cleanup.complete();
      _notify();
    }
  }

  void _invalidateSessionRequests() {
    _mediaDiagnostics.clear();
    _callDiagnosticSink = null;
    _diagnosticOwner = null;
    _diagnosticCallId = null;
    _diagnosticJoinAttempted = false;
    invitations.invalidate();
    staffWorkspace.close();
    discovery.reset();
    matching.reset();
    _matchCallSeen = null;
    _stopIntent = null;
    _stopOwner = null;
    _abandonedCallId = null;
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
      staffWorkspace.reconcile();
      discovery.reconcile();
      matching.reconcile();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _mediaDiagnostics.dispose();
    _callDiagnosticSink = null;
    staffWorkspace.removeListener(_notify);
    staffWorkspace.dispose();
    _videoPreviewRequest++;
    _videoPreviewRequested = videoPreviewBusy = false;
    _videoConsentCallId = null;
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _mediaTimer?.cancel();
    audio.onChanged = null;
    audio.onFailure = null;
    unawaited(Future<void>.sync(audio.leave).catchError((Object _) {}));
    discovery.removeListener(_notify);
    discovery.dispose();
    matching.removeListener(_matchingChanged);
    matching.dispose();
    invitations.removeListener(_notify);
    invitations.dispose();
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
