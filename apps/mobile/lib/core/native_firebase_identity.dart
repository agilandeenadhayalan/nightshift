import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as sdk;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'firebase_identity_client.dart';

abstract interface class PhoneIdentityClient implements FirebaseIdentityClient {
  Future<void> requestPhone(String phone,
      {required bool Function() isCurrent,
      required void Function(String, int?) codeSent,
      required void Function(Object) automaticallyVerified,
      required void Function(String) failed,
      required void Function() autoRetrievalEnded,
      int? resendToken});
  Future<FirebaseTokens> verifyPhoneCode(String verificationId, String code,
      String phone, bool Function() isCurrent);
  Future<FirebaseTokens> verifyAutomatic(
      Object credential, String phone, bool Function() isCurrent);
  Future<FirebaseTokens> restore(String expectedUid);
  Future<void> signOut();
  Future<void> discard(FirebaseTokens tokens);
}

class NativeIdentitySession {
  NativeIdentitySession(this.uid, this.phone, this.token, this.expiresAt);
  final String uid, phone, token;
  final DateTime expiresAt;
  @override
  String toString() => 'NativeIdentitySession[redacted]';
}

/// Isolates SDK calls so callback ordering and credential races can be tested
/// with synthetic fixtures without sending SMS or disabling app verification.
abstract interface class NativePhoneAuthDriver {
  bool get configured;
  Future<void> requestPhone(String phone,
      {required bool Function() isCurrent,
      required void Function(String, int?) codeSent,
      required void Function(Object) automaticallyVerified,
      required void Function(String) failed,
      required void Function() autoRetrievalEnded,
      int? resendToken});
  Object codeCredential(String verificationId, String code);
  Future<NativeIdentitySession> signIn(Object credential);
  Future<NativeIdentitySession> current({required bool forceRefresh});
  Future<void> signOut();
}

class NativeFirebaseIdentityClient implements PhoneIdentityClient {
  NativeFirebaseIdentityClient(
      {NativePhoneAuthDriver? driver,
      this.operationTimeout = const Duration(seconds: 20)})
      : driver = driver ?? FlutterFirePhoneDriver();
  final NativePhoneAuthDriver driver;
  final Duration operationTimeout;
  Future<void>? _identityWork, _cleanupWork, _cleanupWaiter, _verificationWork;
  int _generation = 0;
  bool _closed = false, _cleanupRequired = false;
  @override
  bool get configured => driver.configured && !_closed;
  static const _pending = ApiFailure(
      'PHONE_AUTH_PENDING', 'Phone verification is still finishing.');
  Future<T> _operate<T>(Future<T> Function() action) {
    if (_closed ||
        _identityWork != null ||
        _cleanupWork != null ||
        _cleanupRequired) {
      return Future.error(_pending);
    }
    final actual = Future<T>.sync(action);
    final barrier = actual.then<void>((_) {}, onError: (Object _) {});
    _identityWork = barrier;
    unawaited(barrier.then((_) {
      if (identical(_identityWork, barrier)) _identityWork = null;
    }));
    return actual.timeout(operationTimeout, onTimeout: () {
      // Keep the underlying operation locked. Its late mutation is cleaned up
      // before another credential operation can start.
      unawaited(signOut().catchError((Object _) {}));
      throw _pending;
    });
  }

  FirebaseTokens _tokens(NativeIdentitySession value) =>
      FirebaseTokens(value.token, '', value.expiresAt,
          nativeUid: value.uid, nativeGeneration: _generation);
  @override
  Future<void> requestPhone(String phone,
      {required bool Function() isCurrent,
      required void Function(String, int?) codeSent,
      required void Function(Object) automaticallyVerified,
      required void Function(String) failed,
      required void Function() autoRetrievalEnded,
      int? resendToken}) {
    if (_closed ||
        _verificationWork != null ||
        _cleanupWork != null ||
        _identityWork != null ||
        _cleanupRequired) {
      return Future.error(_pending);
    }
    final generation = _generation;
    bool current() => !_closed && generation == _generation && isCurrent();
    final actual =
        driver.requestPhone(phone, isCurrent: current, codeSent: (id, token) {
      if (current()) codeSent(id, token);
    }, automaticallyVerified: (credential) {
      if (current()) automaticallyVerified(credential);
    }, failed: (code) {
      if (current()) failed(code);
    }, autoRetrievalEnded: () {
      if (current()) autoRetrievalEnded();
    }, resendToken: resendToken);
    final barrier = actual.then<void>((_) {}, onError: (Object _) {});
    _verificationWork = barrier;
    unawaited(barrier.then((_) {
      if (identical(_verificationWork, barrier)) _verificationWork = null;
    }));
    return actual.timeout(operationTimeout, onTimeout: () {
      _generation++;
      throw _pending;
    });
  }

  @override
  Future<FirebaseTokens> verifyPhoneCode(String verificationId, String code,
          String phone, bool Function() isCurrent) =>
      verifyAutomatic(
          driver.codeCredential(verificationId, code), phone, isCurrent);
  @override
  Future<FirebaseTokens> verifyAutomatic(
      Object credential, String phone, bool Function() isCurrent) {
    final generation = _generation;
    bool current() => !_closed && generation == _generation && isCurrent();
    return _operate(() async {
      if (!current()) {
        throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Sign in again.');
      }
      final NativeIdentitySession result;
      try {
        result = await driver.signIn(credential);
      } catch (_) {
        unawaited(signOut().catchError((Object _) {}));
        rethrow;
      }
      if (!current() || result.phone != phone) {
        // The operation must settle before its one coalesced cleanup can run.
        unawaited(signOut().catchError((Object _) {}));
        throw const ApiFailure('PRIVATE_SESSION_CHANGED', 'Sign in again.');
      }
      return _tokens(result);
    });
  }

  @override
  Future<FirebaseTokens> restore(String expectedUid) {
    final generation = _generation;
    return _operate(() async {
      if (_closed || generation != _generation) {
        throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
            status: 401);
      }
      final value = await driver.current(forceRefresh: true);
      if (_closed || generation != _generation || value.uid != expectedUid) {
        throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
            status: 401);
      }
      return _tokens(value);
    });
  }

  @override
  Future<FirebaseTokens> refresh(String expectedUid) => restore(expectedUid);
  @override
  Future<FirebaseTokens> exchange(String customToken) async =>
      throw const ApiFailure(
          'PHONE_AUTH_UNAVAILABLE', 'Legacy phone sign-in is unavailable.');
  @override
  Future<void> signOut() {
    if (_cleanupWork != null) return _cleanupWaiter!;
    _generation++;
    if (!driver.configured) return Future<void>.value();
    _cleanupRequired = true;
    final actual =
        (_identityWork ?? Future<void>.value()).then((_) => driver.signOut());
    _cleanupWork = actual;
    void clear() {
      if (identical(_cleanupWork, actual)) {
        _cleanupWork = null;
        _cleanupWaiter = null;
      }
    }

    unawaited(actual.then<void>((_) {
      _cleanupRequired = false;
      clear();
    }, onError: (Object _) {
      clear();
    }));
    return _cleanupWaiter =
        actual.timeout(operationTimeout, onTimeout: () => throw _pending);
  }

  @override
  Future<void> discard(FirebaseTokens tokens) =>
      tokens.nativeGeneration == _generation ? signOut() : Future<void>.value();
  @override
  void close() {
    _closed = true;
    _generation++;
  }
}

/// Selects Firebase's real browser app-verification flow for a diagnostic debug
/// build. Verification remains enabled, including when the switch is omitted.
@visibleForTesting
Future<bool> configurePhoneAppVerification({
  required Future<void> Function({
    required bool appVerificationDisabledForTesting,
    required bool forceRecaptchaFlow,
  }) applySettings,
  required bool Function() isCurrent,
  bool debugBuild = kDebugMode,
  bool forceRequested = const bool.fromEnvironment('FIREBASE_FORCE_RECAPTCHA'),
}) async {
  if (!isCurrent()) return false;
  await applySettings(
      appVerificationDisabledForTesting: false,
      forceRecaptchaFlow: debugBuild && forceRequested);
  return isCurrent();
}

class FlutterFirePhoneDriver implements NativePhoneAuthDriver {
  static const _apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  Future<sdk.FirebaseAuth>? _initializing;
  @override
  bool get configured =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId == 'nightshift-c3e1a';
  Future<sdk.FirebaseAuth> _auth() {
    if (!configured) {
      throw const ApiFailure(
          'PHONE_AUTH_UNAVAILABLE', 'Phone sign-in is unavailable.');
    }
    return _initializing ??= (() async {
      final app = await Firebase.initializeApp(
          name: 'nightshift-phone',
          options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _senderId,
              projectId: _projectId));
      return sdk.FirebaseAuth.instanceFor(app: app);
    })();
  }

  @override
  Future<void> requestPhone(String phone,
      {required bool Function() isCurrent,
      required void Function(String, int?) codeSent,
      required void Function(Object) automaticallyVerified,
      required void Function(String) failed,
      required void Function() autoRetrievalEnded,
      int? resendToken}) async {
    try {
      final auth = await _auth();
      if (!await configurePhoneAppVerification(
          applySettings: auth.setSettings, isCurrent: isCurrent)) {
        return;
      }
      await auth.verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          forceResendingToken: resendToken,
          verificationCompleted: (credential) {
            if (isCurrent()) automaticallyVerified(credential);
          },
          verificationFailed: (error) {
            if (isCurrent()) failed(firebasePhoneError(error.code));
          },
          codeSent: (id, token) {
            if (isCurrent()) codeSent(id, token);
          },
          codeAutoRetrievalTimeout: (_) {
            if (isCurrent()) autoRetrievalEnded();
          });
    } on sdk.FirebaseAuthException catch (e) {
      if (isCurrent()) failed(firebasePhoneError(e.code));
    }
  }

  @override
  Object codeCredential(String verificationId, String code) =>
      sdk.PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: code);
  Future<NativeIdentitySession> _session(
      sdk.User user, bool forceRefresh) async {
    final token = await user.getIdTokenResult(forceRefresh);
    if (token.token == null ||
        token.expirationTime == null ||
        user.phoneNumber == null) {
      throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.', status: 401);
    }
    return NativeIdentitySession(
        user.uid, user.phoneNumber!, token.token!, token.expirationTime!);
  }

  @override
  Future<NativeIdentitySession> signIn(Object credential) async {
    try {
      final result = await (await _auth())
          .signInWithCredential(credential as sdk.PhoneAuthCredential);
      if (result.user == null) {
        throw const ApiFailure('INVALID_ID_TOKEN', 'Sign in again.',
            status: 401);
      }
      return await _session(result.user!, false);
    } on sdk.FirebaseAuthException catch (e) {
      throw ApiFailure(
          firebasePhoneError(e.code), 'Phone verification failed.');
    }
  }

  @override
  Future<NativeIdentitySession> current({required bool forceRefresh}) async {
    try {
      final user = (await _auth()).currentUser;
      if (user == null) {
        throw const ApiFailure('UNAUTHENTICATED', 'Sign in again.',
            status: 401);
      }
      return await _session(user, forceRefresh);
    } on sdk.FirebaseAuthException catch (e) {
      final code = firebasePhoneError(e.code);
      throw ApiFailure(code, 'Sign in again.',
          status: code == 'OFFLINE' ? 0 : 401);
    }
  }

  @override
  Future<void> signOut() async => (await _auth()).signOut();
}

String firebasePhoneError(String code) => switch (code) {
      'invalid-phone-number' => 'OTP_INVALID_PHONE',
      'invalid-verification-code' => 'OTP_INVALID_CODE',
      'session-expired' || 'invalid-verification-id' => 'OTP_EXPIRED',
      'too-many-requests' || 'quota-exceeded' => 'PHONE_PROVIDER_LIMIT',
      'network-request-failed' => 'OFFLINE',
      'user-disabled' ||
      'user-not-found' ||
      'user-token-expired' ||
      'invalid-user-token' =>
        'SESSION_REVOKED',
      'app-not-authorized' ||
      'invalid-app-credential' ||
      'missing-app-credential' ||
      'operation-not-allowed' ||
      'captcha-check-failed' ||
      'missing-client-identifier' =>
        'PHONE_APP_VERIFICATION_FAILED',
      _ => 'IDENTITY_UNAVAILABLE'
    };
