import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'firebase_identity_client.dart';
import 'models.dart';
import 'native_firebase_identity.dart';

/// Ephemeral OTP state. Phone numbers, OTPs and one-use proofs are never stored.
class PhoneSignIn extends ChangeNotifier {
  PhoneSignIn(
      {required this.api,
      required this.firebase,
      required this.deviceId,
      required this.onAuthenticated,
      this.backendUrl = const String.fromEnvironment('PHONE_API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000'),
      this.consentVersion = const String.fromEnvironment(
          'PHONE_AUTH_CONSENT_VERSION',
          defaultValue: 'phone-signin-v1'),
      DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final NightShiftApi api;
  final FirebaseIdentityClient firebase;
  final String Function() deviceId;
  final Future<void> Function(FirebaseTokens, Json) onAuthenticated;
  final String consentVersion;
  final String backendUrl;
  final DateTime Function() _clock;
  String _phone = '', _requestKey = '';
  String? challengeId, errorCode;
  DateTime? expiresAt, retryAt;
  DateTime? _cooldownWarningUntil;
  bool busy = false, consent = false, _disposed = false;
  int _generation = 0;
  String? _attemptId;
  int? _resendToken;
  bool autoRetrievalEnded = false, _completing = false;
  bool get nativePhone => firebase is PhoneIdentityClient;
  int get attemptRevision => _generation;
  bool isCurrentAttempt(int revision) =>
      !_disposed &&
      revision == _generation &&
      consent &&
      api.baseUrl == backendUrl;
  bool get configured => firebase.configured;
  bool get safeBackend {
    final uri = Uri.tryParse(backendUrl);
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        (uri.scheme == 'https' ||
            (!kReleaseMode &&
                uri.scheme == 'http' &&
                ['127.0.0.1', 'localhost', '10.0.2.2', '::1']
                    .contains(uri.host)));
  }

  int get retrySeconds {
    final milliseconds = retryAt?.difference(_clock()).inMilliseconds ?? 0;
    return milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;
  }

  bool get expired => expiresAt != null && !expiresAt!.isAfter(_clock());
  bool get canRequest => configured && consent && !busy && retrySeconds == 0;
  bool get canVerify => consent && !busy && challengeId != null && !expired;

  void editPhone(String value) {
    final canonical = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    final phone = canonical.startsWith('+91') ? canonical : '+91$canonical';
    if (phone == _phone) return;
    _phone = phone;
    _generation++;
    _attemptId = null;
    _resendToken = null;
    autoRetrievalEnded = _completing = false;
    busy = false;
    challengeId = null;
    expiresAt = null;
    retryAt = null;
    _cooldownWarningUntil = null;
    _requestKey = '';
    errorCode = null;
    consent = false;
    _notify();
  }

  void setConsent(bool value) {
    if (!value && consent) {
      _generation++;
      _attemptId = null;
      _resendToken = null;
      _completing = false;
      busy = false;
      challengeId = null;
      expiresAt = null;
      _requestKey = '';
    }
    consent = value;
    _notify();
  }

  void tick() {
    if (_cooldownWarningUntil != null &&
        !_cooldownWarningUntil!.isAfter(_clock()) &&
        (errorCode == 'OTP_COOLDOWN' || errorCode == 'OTP_RATE_LIMITED')) {
      errorCode = null;
      _cooldownWarningUntil = null;
    }
    if (nativePhone && expired && busy && !_completing) {
      busy = false;
      errorCode = 'PHONE_ADMISSION_EXPIRED';
    }
    _notify();
  }

  void reset({bool notify = true}) {
    _generation++;
    _attemptId = null;
    _resendToken = null;
    autoRetrievalEnded = _completing = false;
    _phone = '';
    challengeId = null;
    expiresAt = retryAt = null;
    _cooldownWarningUntil = null;
    busy = consent = false;
    errorCode = null;
    _requestKey = '';
    if (notify) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> requestCode() async {
    if (busy) return;
    if (!configured) {
      errorCode = 'PHONE_AUTH_UNAVAILABLE';
      _notify();
      return;
    }
    if (!safeBackend) {
      errorCode = 'PHONE_AUTH_UNAVAILABLE';
      _notify();
      return;
    }
    api.baseUrl = backendUrl;
    if (!consent) {
      errorCode = 'OTP_INVALID_CONSENT';
      _notify();
      return;
    }
    if (!RegExp(r'^\+91[6-9][0-9]{9}$').hasMatch(_phone)) {
      errorCode = 'OTP_INVALID_PHONE';
      _notify();
      return;
    }
    if (retrySeconds > 0) {
      errorCode = 'OTP_COOLDOWN';
      _cooldownWarningUntil = retryAt;
      _notify();
      return;
    }
    if (firebase is PhoneIdentityClient) {
      await _requestNative(firebase as PhoneIdentityClient);
      return;
    }
    final generation = _generation;
    busy = true;
    errorCode = null;
    _notify();
    // Network uncertainty retries the same idempotency key, avoiding another SMS.
    if (_requestKey.isEmpty) _requestKey = newId();
    try {
      final result = await api.request('POST', '/auth/otp/request',
          body: {
            'phone': _phone,
            'deviceId': deviceId(),
            'consentVersion': consentVersion,
          },
          idempotencyKey: _requestKey);
      if (_disposed || generation != _generation) return;
      challengeId = result['challengeId'] as String;
      expiresAt = DateTime.parse(result['expiresAt'] as String);
      retryAt = DateTime.parse(result['retryAt'] as String);
      _requestKey = '';
      final state = result['state'];
      if (state != 'sent') {
        errorCode =
            state == 'sending' ? 'OTP_IN_PROGRESS' : 'OTP_UNKNOWN_OUTCOME';
        challengeId = null;
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _failure(e);
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> verifyCode(String code) async {
    if (busy) return;
    if (!consent) {
      errorCode = 'OTP_INVALID_CONSENT';
      _notify();
      return;
    }
    if (expired) {
      errorCode = nativePhone ? 'PHONE_ADMISSION_EXPIRED' : 'OTP_EXPIRED';
      _notify();
      return;
    }
    if (challengeId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      errorCode = 'OTP_INVALID_INPUT';
      _notify();
      return;
    }
    if (firebase is PhoneIdentityClient) {
      final identity = firebase as PhoneIdentityClient;
      final generation = _generation, phone = _phone, id = challengeId!;
      await _completeNative(
          generation,
          () => identity.verifyPhoneCode(
              id, code, phone, () => _nativeCurrent(generation)));
      return;
    }
    final generation = _generation;
    busy = true;
    errorCode = null;
    _notify();
    bool current() =>
        !_disposed && generation == _generation && api.baseUrl == backendUrl;
    try {
      final proof = await api.request('POST', '/auth/otp/verify', body: {
        'challengeId': challengeId,
        'phone': _phone,
        'deviceId': deviceId(),
        'code': code,
      });
      if (!current()) return;
      // A consumed OTP can never be resubmitted, including Firebase failures.
      challengeId = null;
      final tokens = await firebase.exchange(proof['customToken'] as String);
      if (!current()) return;
      final session = await api.request('POST', '/auth/exchange', body: {
        'idToken': tokens.idToken,
        'deviceId': deviceId(),
      });
      if (!current()) return;
      await onAuthenticated(tokens, session);
      if (!current()) return;
      _phone = '';
      _requestKey = '';
      consent = false;
      expiresAt = retryAt = null;
    } catch (e) {
      if (!current()) return;
      _failure(e);
      if ([
        'OTP_EXPIRED',
        'OTP_CONSUMED',
        'OTP_LOCKED',
        'OTP_NOT_FOUND',
        'OTP_UNKNOWN_OUTCOME'
      ].contains(errorCode)) {
        challengeId = null;
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  bool _nativeCurrent(int generation) =>
      !_disposed &&
      generation == _generation &&
      consent &&
      api.baseUrl == backendUrl &&
      !expired;

  Future<void> _requestNative(PhoneIdentityClient identity) async {
    final generation = ++_generation;
    final phone = _phone, resend = _resendToken;
    busy = true;
    _completing = false;
    errorCode = challengeId = _attemptId = null;
    autoRetrievalEnded = false;
    expiresAt = null;
    _notify();
    if (_requestKey.isEmpty) _requestKey = newId();
    try {
      final admission = await api.request('POST', '/auth/firebase/admissions',
          body: {
            'phone': phone,
            'deviceId': deviceId(),
            'consentVersion': consentVersion
          },
          idempotencyKey: _requestKey);
      if (!_nativeCurrent(generation)) return;
      _attemptId = admission['attemptId'] as String;
      expiresAt = DateTime.parse(admission['expiresAt'] as String);
      retryAt = DateTime.parse(admission['retryAt'] as String);
      _requestKey = '';
      // Start a fresh SDK sign-in lineage. The admission is not an SMS receipt.
      await identity.signOut();
      if (!_nativeCurrent(generation)) return;
      await identity.requestPhone(phone,
          isCurrent: () => _nativeCurrent(generation),
          resendToken: resend,
          codeSent: (id, token) {
            if (!_nativeCurrent(generation) || _completing) return;
            challengeId = id;
            _resendToken = token;
            busy = false;
            _notify();
          },
          automaticallyVerified: (credential) {
            if (!_nativeCurrent(generation) || _completing) return;
            unawaited(_completeNative(
                generation,
                () => identity.verifyAutomatic(
                    credential, phone, () => _nativeCurrent(generation))));
          },
          failed: (code) {
            if (!_nativeCurrent(generation) || _completing) return;
            errorCode = code;
            busy = false;
            _notify();
          },
          autoRetrievalEnded: () {
            if (!_nativeCurrent(generation)) return;
            // This only ends Android auto-retrieval. It does not expire the code.
            autoRetrievalEnded = true;
            _notify();
          });
    } catch (e) {
      if (!_nativeCurrent(generation)) return;
      _failure(e);
      busy = false;
      _notify();
    }
  }

  Future<void> _completeNative(
      int generation, Future<FirebaseTokens> Function() prove) async {
    if (!_nativeCurrent(generation) || _completing || _attemptId == null) {
      return;
    }
    _completing = true;
    busy = true;
    errorCode = null;
    _notify();
    var signedIn = false, accepted = false;
    FirebaseTokens? proofTokens;
    final identity = firebase as PhoneIdentityClient;
    try {
      final tokens = await prove();
      proofTokens = tokens;
      signedIn = true;
      if (!_nativeCurrent(generation)) return;
      final result = await api.request('POST', '/auth/exchange', body: {
        'idToken': tokens.idToken,
        'deviceId': deviceId(),
        'attemptId': _attemptId
      });
      if (!_nativeCurrent(generation)) return;
      // Navigation may dispose this route once the accepted session is installed.
      accepted = true;
      await onAuthenticated(tokens, result);
      if (generation != _generation) return;
      challengeId = _attemptId = null;
      _phone = '';
      consent = false;
      expiresAt = retryAt = null;
    } catch (e) {
      if (generation != _generation || _disposed) return;
      _failure(e);
      if (signedIn ||
          ['OTP_EXPIRED', 'SESSION_REVOKED', 'PHONE_ADMISSION_EXPIRED']
              .contains(errorCode)) {
        challengeId = _attemptId = null;
      }
    } finally {
      if (signedIn && !accepted && proofTokens != null) {
        try {
          await identity.discard(proofTokens);
        } catch (_) {
          // Cleanup remains fenced inside the identity adapter. A caller timeout
          // must not keep this UI busy or escape an automatic callback.
        }
      }
      if (generation == _generation) {
        _completing = false;
        busy = false;
        _notify();
      }
    }
  }

  void _failure(Object error) {
    errorCode = error is ApiFailure ? error.code : 'IDENTITY_UNAVAILABLE';
    _cooldownWarningUntil = null;
    if (error is ApiFailure && error.retryAfterSeconds != null) {
      retryAt = _clock().add(Duration(seconds: error.retryAfterSeconds!));
      if (errorCode == 'OTP_COOLDOWN' || errorCode == 'OTP_RATE_LIMITED') {
        _cooldownWarningUntil = retryAt;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
