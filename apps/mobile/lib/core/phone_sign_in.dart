import 'package:flutter/foundation.dart';
import 'api.dart';
import 'firebase_identity_client.dart';
import 'models.dart';

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
  bool busy = false, consent = false, _disposed = false;
  int _generation = 0;
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
    busy = false;
    challengeId = null;
    expiresAt = null;
    retryAt = null;
    _requestKey = '';
    errorCode = null;
    consent = false;
    _notify();
  }

  void setConsent(bool value) {
    if (!value && consent) {
      _generation++;
      busy = false;
      challengeId = null;
      expiresAt = null;
      _requestKey = '';
    }
    consent = value;
    _notify();
  }

  void tick() => _notify();
  void reset({bool notify = true}) {
    _generation++;
    _phone = '';
    challengeId = null;
    expiresAt = retryAt = null;
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
      _notify();
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
      errorCode = 'OTP_EXPIRED';
      _notify();
      return;
    }
    if (challengeId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      errorCode = 'OTP_INVALID_INPUT';
      _notify();
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

  void _failure(Object error) {
    errorCode = error is ApiFailure ? error.code : 'IDENTITY_UNAVAILABLE';
    if (error is ApiFailure && error.retryAfterSeconds != null) {
      retryAt = _clock().add(Duration(seconds: error.retryAfterSeconds!));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
