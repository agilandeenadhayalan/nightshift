import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/core/phone_sign_in.dart';
import 'fakes.dart';

const syntheticPhone = '+919876543210';

class FakePhoneDriver implements NativePhoneAuthDriver {
  @override
  bool configured = true;
  int sends = 0, signIns = 0, signOuts = 0, refreshes = 0;
  NativeIdentitySession? user;
  Completer<NativeIdentitySession>? pendingSignIn;
  Completer<NativeIdentitySession>? pendingCurrent;
  Completer<void>? pendingRequest, pendingSignOut;
  ApiFailure? signInFailure;
  bool failSignOut = false;
  void Function(String, int?)? sent;
  void Function(Object)? auto;
  void Function(String)? fail;
  void Function()? timedOut;
  bool Function()? stillCurrent;
  int? resend;
  @override
  Future<void> requestPhone(String phone,
      {required bool Function() isCurrent,
      required void Function(String, int?) codeSent,
      required void Function(Object) automaticallyVerified,
      required void Function(String) failed,
      required void Function() autoRetrievalEnded,
      int? resendToken}) async {
    sends++;
    sent = codeSent;
    auto = automaticallyVerified;
    fail = failed;
    timedOut = autoRetrievalEnded;
    stillCurrent = isCurrent;
    resend = resendToken;
    await pendingRequest?.future;
  }

  @override
  Object codeCredential(String verificationId, String code) => Object();
  @override
  Future<NativeIdentitySession> signIn(Object credential) async {
    signIns++;
    if (signInFailure != null) throw signInFailure!;
    user = await (pendingSignIn?.future ?? Future.value(nativeSession()));
    return user!;
  }

  @override
  Future<NativeIdentitySession> current({required bool forceRefresh}) async {
    if (forceRefresh) refreshes++;
    if (pendingCurrent != null) return pendingCurrent!.future;
    if (user == null) {
      throw const ApiFailure('UNAUTHENTICATED', 'missing', status: 401);
    }
    return user!;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    await pendingSignOut?.future;
    if (failSignOut) {
      throw const ApiFailure('IDENTITY_UNAVAILABLE', 'cleanup failed');
    }
    user = null;
  }
}

NativeIdentitySession nativeSession(
        {String uid = 'opaque-firebase-uid',
        String token = 'fixture-native-token'}) =>
    NativeIdentitySession(uid, syntheticPhone, token,
        DateTime.now().add(const Duration(hours: 1)));
Json nativeAdmission(DateTime now) => {
      'attemptId': 'admission-id',
      'expiresAt': now.add(const Duration(minutes: 5)).toIso8601String(),
      'retryAt': now.add(const Duration(seconds: 60)).toIso8601String()
    };
Json nativeBackendSession(String token) => {
      'token': token,
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'needsOnboarding': true,
      'testOnly': true,
      'user': userJson()
    };
Json nativeOnboarding() => {
      'required': true,
      'profile': {
        'displayName': '',
        'avatarCode': 'moon',
        'interfaceLanguage': 'en',
        'languages': ['ta'],
        'dateOfBirth': null
      }
    };
Future<void> settleCallbacks() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class PendingPhoneStore extends MemoryStore {
  final reached = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (key == 'phoneSession') {
      reached.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

class PartialFailurePhoneStore extends MemoryStore {
  final reached = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (key == 'token') {
      reached.complete();
      await release.future;
      throw StateError('storage write failed');
    }
    await super.write(key, value);
  }
}

void main() {
  test(
      'failed native cleanup blocks new proof until explicit cleanup retry succeeds',
      () async {
    final driver = FakePhoneDriver()..failSignOut = true;
    final native = NativeFirebaseIdentityClient(driver: driver);
    await expectLater(native.signOut(), throwsA(isA<ApiFailure>()));
    await expectLater(
        native.verifyAutomatic(Object(), syntheticPhone, () => true),
        throwsA(isA<ApiFailure>()));
    expect(driver.signIns, 0);
    driver.failSignOut = false;
    await native.signOut();
    await native.verifyAutomatic(Object(), syntheticPhone, () => true);
    expect(driver.signIns, 1);
  });
  test(
      'automatic completion contains cleanup timeout and always releases UI busy state',
      () async {
    final driver = FakePhoneDriver(), api = FakeApi();
    final native = NativeFirebaseIdentityClient(
        driver: driver, operationTimeout: const Duration(milliseconds: 15));
    api.interceptor = (m, p, b) async {
      if (p.endsWith('/admissions')) return nativeAdmission(DateTime.now());
      driver.pendingSignOut = Completer();
      throw const ApiFailure('OFFLINE', 'lost');
    };
    final flow = PhoneSignIn(
        api: api,
        firebase: native,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    driver.auto!(Object());
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(flow.busy, false);
    expect(flow.errorCode, 'OFFLINE');
    await expectLater(
        native.verifyAutomatic(Object(), syntheticPhone, () => true),
        throwsA(isA<ApiFailure>()));
    driver.pendingSignOut!.complete();
    await settleCallbacks();
    expect(driver.user, isNull);
  });
  test(
      'hung SDK sign-in has bounded callers and one coalesced cleanup without releasing ownership',
      () async {
    final driver = FakePhoneDriver()..pendingSignIn = Completer();
    final native = NativeFirebaseIdentityClient(
        driver: driver, operationTimeout: const Duration(milliseconds: 20));
    final pending =
        native.verifyAutomatic(Object(), syntheticPhone, () => true);
    await expectLater(
        pending,
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'PHONE_AUTH_PENDING')));
    final cleanup = native.signOut();
    for (var i = 0; i < 8; i++) {
      expect(identical(native.signOut(), cleanup), true);
      await expectLater(
          native.verifyAutomatic(Object(), syntheticPhone, () => true),
          throwsA(isA<ApiFailure>()));
    }
    await expectLater(cleanup, throwsA(isA<ApiFailure>()));
    expect(driver.signIns, 1);
    expect(driver.signOuts, 0);
    driver.pendingSignIn!.complete(nativeSession());
    await settleCallbacks();
    expect(driver.signOuts, 1);
    expect(driver.user, isNull);
    driver.pendingSignIn = null;
    final fresh =
        await native.verifyAutomatic(Object(), syntheticPhone, () => true);
    expect(fresh.nativeUid, 'opaque-firebase-uid');
    expect(driver.signIns, 2);
  });
  test(
      'local logout clears private state and marker while SDK refresh never settles',
      () async {
    final driver = FakePhoneDriver()..user = nativeSession(),
        api = FakeApi(),
        store = MemoryStore();
    store.values['phoneSession'] = jsonEncode({
      'provider': 'firebase-native',
      'uid': 'opaque-firebase-uid',
      'baseUrl': api.baseUrl
    });
    api.interceptor = (m, p, b) async => p == '/auth/exchange'
        ? nativeBackendSession(b!['idToken'] as String)
        : p == '/me/onboarding'
            ? nativeOnboarding()
            : null;
    final native = NativeFirebaseIdentityClient(
        driver: driver, operationTimeout: const Duration(milliseconds: 20));
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: native,
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.user, isNotNull);
    driver.pendingCurrent = Completer();
    final refresh = native.restore('opaque-firebase-uid');
    final expected = expectLater(refresh, throwsA(isA<ApiFailure>()));
    await app.logout();
    expect(app.user, isNull);
    expect(api.token, isNull);
    expect(app.onboardingProfile, isNull);
    expect(store.values['phoneSession'], isNull);
    expect(store.values['token'], isNull);
    await expected;
    expect(driver.signOuts, 0);
    driver.pendingCurrent!.complete(nativeSession());
    await settleCallbacks();
    expect(driver.signOuts, 1);
    expect(driver.user, isNull);
  });
  test(
      'hanging verification request cannot enqueue more SMS or accept late auto callbacks',
      () async {
    final driver = FakePhoneDriver()..pendingRequest = Completer();
    final native = NativeFirebaseIdentityClient(
        driver: driver, operationTimeout: const Duration(milliseconds: 20));
    var completions = 0;
    Future<void> send() => native.requestPhone(syntheticPhone,
        isCurrent: () => true,
        codeSent: (_, __) {},
        automaticallyVerified: (_) {
          completions++;
        },
        failed: (_) {},
        autoRetrievalEnded: () {});
    await expectLater(send(), throwsA(isA<ApiFailure>()));
    await expectLater(send(), throwsA(isA<ApiFailure>()));
    driver.auto!(Object());
    expect(completions, 0);
    expect(driver.sends, 1);
    driver.pendingRequest!.complete();
    await settleCallbacks();
  });
  test(
      'partial secure write failure after cancellation removes marker and SDK session',
      () async {
    final driver = FakePhoneDriver(),
        api = FakeApi(),
        store = PartialFailurePhoneStore();
    api.interceptor = (m, p, b) async => p.endsWith('/admissions')
        ? nativeAdmission(DateTime.now())
        : nativeBackendSession(b!['idToken'] as String);
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    app.phoneSignIn.editPhone(syntheticPhone);
    app.phoneSignIn.setConsent(true);
    await app.phoneSignIn.requestCode();
    driver.sent!('id', 1);
    final verifying = app.phoneSignIn.verifyCode('123456');
    await store.reached.future;
    expect(store.values['phoneSession'], isNotNull);
    app.phoneSignIn.setConsent(false);
    store.release.complete();
    await verifying;
    expect(app.user, isNull);
    expect(api.token, isNull);
    expect(store.values['phoneSession'], isNull);
    expect(driver.user, isNull);
  });
  test('malformed backend user is rejected before persisting acceptance',
      () async {
    final driver = FakePhoneDriver(), api = FakeApi(), store = MemoryStore();
    api.interceptor = (m, p, b) async => p.endsWith('/admissions')
        ? nativeAdmission(DateTime.now())
        : {...nativeBackendSession(b!['idToken'] as String), 'user': null};
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    app.phoneSignIn.editPhone(syntheticPhone);
    app.phoneSignIn.setConsent(true);
    await app.phoneSignIn.requestCode();
    driver.sent!('id', 1);
    await app.phoneSignIn.verifyCode('123456');
    expect(app.phoneSignIn.errorCode, 'INVALID_RESPONSE');
    expect(app.user, isNull);
    expect(store.values['phoneSession'], isNull);
    expect(driver.user, isNull);
  });
  test(
      'cancel during secure acceptance write cannot publish or restore the stale phone session',
      () async {
    final driver = FakePhoneDriver(),
        api = FakeApi(),
        store = PendingPhoneStore();
    api.interceptor = (m, p, b) async => p.endsWith('/admissions')
        ? nativeAdmission(DateTime.now())
        : p == '/auth/exchange'
            ? nativeBackendSession(b!['idToken'] as String)
            : nativeOnboarding();
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    app.phoneSignIn.editPhone(syntheticPhone);
    app.phoneSignIn.setConsent(true);
    await app.phoneSignIn.requestCode();
    driver.sent!('id', 1);
    final verifying = app.phoneSignIn.verifyCode('123456');
    await store.reached.future;
    expect(app.user, isNull);
    expect(api.token, isNull);
    app.phoneSignIn.editPhone('9876543211');
    store.release.complete();
    await verifying;
    expect(app.user, isNull);
    expect(api.token, isNull);
    expect(store.values['phoneSession'], isNull);
    expect(store.values['token'], isNull);
    expect(driver.user, isNull);
  });
  test(
      'admission and consent precede SDK SMS; auto timeout preserves manual code',
      () async {
    final api = FakeApi(), driver = FakePhoneDriver();
    final native = NativeFirebaseIdentityClient(driver: driver);
    var now = DateTime.utc(2026, 11, 20);
    api.interceptor = (m, p, b) async {
      expect(p, '/auth/firebase/admissions');
      return nativeAdmission(now);
    };
    final flow = PhoneSignIn(
        api: api,
        firebase: native,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {},
        clock: () => now);
    addTearDown(flow.dispose);
    addTearDown(native.close);
    flow.editPhone(syntheticPhone);
    await flow.requestCode();
    expect(driver.sends, 0);
    flow.setConsent(true);
    await flow.requestCode();
    expect(driver.sends, 1);
    expect(flow.challengeId, isNull);
    expect(flow.busy, true);
    driver.sent!('verification-id', 7);
    expect(flow.canVerify, true);
    expect(flow.canRequest, false);
    driver.timedOut!();
    expect(flow.autoRetrievalEnded, true);
    expect(flow.expired, false);
    expect(flow.canVerify, true);
    now = now.add(const Duration(seconds: 61));
    await flow.requestCode();
    expect(driver.resend, 7);
    expect(driver.sends, 2);
  });
  test('failed admission never invokes SMS provider', () async {
    final driver = FakePhoneDriver(), api = FakeApi();
    final native = NativeFirebaseIdentityClient(driver: driver);
    api.interceptor = (m, p, b) async =>
        throw const ApiFailure('OTP_COOLDOWN', 'wait', status: 429);
    final flow = PhoneSignIn(
        api: api,
        firebase: native,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    expect(driver.sends, 0);
    expect(flow.errorCode, 'OTP_COOLDOWN');
  });
  test(
      'automatic completion before codeSent and duplicate callbacks exchange once',
      () async {
    final driver = FakePhoneDriver(), api = FakeApi();
    var accepted = 0;
    api.interceptor = (m, p, b) async => p.endsWith('/admissions')
        ? nativeAdmission(DateTime.now())
        : nativeBackendSession(b!['idToken'] as String);
    final flow = PhoneSignIn(
        api: api,
        firebase: NativeFirebaseIdentityClient(driver: driver),
        deviceId: () => 'device',
        onAuthenticated: (tokens, result) async {
          accepted++;
        });
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    driver.auto!(Object());
    driver.auto!(Object());
    driver.sent!('late-id', 1);
    await flow.verifyCode('123456');
    await settleCallbacks();
    expect(accepted, 1);
    expect(driver.signIns, 1);
    final exchanges =
        api.requests.where((r) => r['path'] == '/auth/exchange').toList();
    expect(exchanges.length, 1);
    expect(exchanges.single['body']['attemptId'], 'admission-id');
    expect(api.requests.any((r) => r['path'] == '/auth/otp/request'), false);
  });
  test('phone edit or withdrawn consent fences late automatic completion',
      () async {
    for (final edit in [true, false]) {
      final driver = FakePhoneDriver(), api = FakeApi();
      api.interceptor = (m, p, b) async => nativeAdmission(DateTime.now());
      final flow = PhoneSignIn(
          api: api,
          firebase: NativeFirebaseIdentityClient(driver: driver),
          deviceId: () => 'device',
          onAuthenticated: (_, __) async {});
      flow.editPhone(syntheticPhone);
      flow.setConsent(true);
      await flow.requestCode();
      if (edit) {
        flow.editPhone('9876543211');
      } else {
        flow.setConsent(false);
      }
      driver.auto!(Object());
      driver.sent!('stale', 1);
      await settleCallbacks();
      expect(driver.signIns, 0);
      expect(flow.challengeId, isNull);
      expect(api.requests.length, 1);
      flow.dispose();
    }
  });
  test(
      'withdrawal during SDK credential sign-in clears SDK and prevents exchange',
      () async {
    final driver = FakePhoneDriver()..pendingSignIn = Completer(),
        api = FakeApi();
    api.interceptor = (m, p, b) async => nativeAdmission(DateTime.now());
    final flow = PhoneSignIn(
        api: api,
        firebase: NativeFirebaseIdentityClient(driver: driver),
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    driver.sent!('id', 1);
    final verifying = flow.verifyCode('123456');
    await settleCallbacks();
    flow.setConsent(false);
    driver.pendingSignIn!.complete(nativeSession());
    await verifying;
    await settleCallbacks();
    expect(driver.user, isNull);
    expect(api.requests.where((r) => r['path'] == '/auth/exchange'), isEmpty);
  });
  test('wrong code remains retryable and provider expiry ends manual challenge',
      () async {
    final driver = FakePhoneDriver()
          ..signInFailure = const ApiFailure('OTP_INVALID_CODE', 'invalid'),
        api = FakeApi();
    api.interceptor = (m, p, b) async => nativeAdmission(DateTime.now());
    final flow = PhoneSignIn(
        api: api,
        firebase: NativeFirebaseIdentityClient(driver: driver),
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    driver.sent!('id', 1);
    await flow.verifyCode('123456');
    expect(flow.errorCode, 'OTP_INVALID_CODE');
    expect(flow.canVerify, true);
    await settleCallbacks();
    driver.signInFailure = const ApiFailure('OTP_EXPIRED', 'expired');
    await flow.verifyCode('123456');
    expect(flow.challengeId, isNull);
  });
  test(
      'expired app admission blocks auto proof without treating retrieval timeout as expiry',
      () async {
    final driver = FakePhoneDriver(), api = FakeApi();
    var now = DateTime.utc(2026, 11, 20);
    api.interceptor = (m, p, b) async => nativeAdmission(now);
    final flow = PhoneSignIn(
        api: api,
        firebase: NativeFirebaseIdentityClient(driver: driver),
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {},
        clock: () => now);
    addTearDown(flow.dispose);
    flow.editPhone(syntheticPhone);
    flow.setConsent(true);
    await flow.requestCode();
    now = now.add(const Duration(minutes: 6));
    flow.tick();
    driver.auto!(Object());
    await settleCallbacks();
    expect(driver.signIns, 0);
    expect(flow.busy, false);
    expect(flow.errorCode, 'PHONE_ADMISSION_EXPIRED');
  });
  test('stale proof cleanup cannot sign out a newer native session', () async {
    final driver = FakePhoneDriver();
    final identity = NativeFirebaseIdentityClient(driver: driver);
    final old =
        await identity.verifyAutomatic(Object(), syntheticPhone, () => true);
    await identity.signOut();
    final fresh =
        await identity.verifyAutomatic(Object(), syntheticPhone, () => true);
    await identity.discard(old);
    expect(driver.user, isNotNull);
    expect(fresh.nativeGeneration, isNot(old.nativeGeneration));
  });
  test('logout serializes cleanup after in-flight SDK sign-in', () async {
    final driver = FakePhoneDriver()..pendingSignIn = Completer();
    final identity = NativeFirebaseIdentityClient(driver: driver);
    final pending =
        identity.verifyAutomatic(Object(), syntheticPhone, () => true);
    final rejection = expectLater(pending, throwsA(isA<ApiFailure>()));
    await settleCallbacks();
    final logout = identity.signOut();
    driver.pendingSignIn!.complete(nativeSession());
    await rejection;
    await logout;
    expect(driver.user, isNull);
  });
  test(
      'native restoration requires secure accepted UID marker and omits admission on refresh',
      () async {
    final driver = FakePhoneDriver()..user = nativeSession(),
        api = FakeApi(),
        store = MemoryStore();
    store.values['phoneSession'] = jsonEncode({
      'provider': 'firebase-native',
      'uid': 'opaque-firebase-uid',
      'baseUrl': api.baseUrl
    });
    api.interceptor = (m, p, b) async => p == '/auth/exchange'
        ? nativeBackendSession(b!['idToken'] as String)
        : p == '/me/onboarding'
            ? nativeOnboarding()
            : null;
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.user!.id, 'customer-id');
    expect(app.user!.id, isNot('opaque-firebase-uid'));
    expect(driver.refreshes, 1);
    expect(
        (api.requests.firstWhere((r) => r['path'] == '/auth/exchange')['body']
                as Json)
            .containsKey('attemptId'),
        false);
    final saved = jsonDecode(store.values['phoneSession']!);
    expect(saved['provider'], 'firebase-native');
    expect(saved.containsKey('refreshToken'), false);
    await app.logout();
    expect(driver.user, isNull);
    expect(store.values['phoneSession'], isNull);
  });
  test(
      'SDK session without backend acceptance marker never restores app access',
      () async {
    final driver = FakePhoneDriver()..user = nativeSession(), api = FakeApi();
    final app = AppController(
        api: api,
        store: MemoryStore(),
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(driver.user, isNull);
    expect(app.user, isNull);
    expect(api.requests, isEmpty);
  });
  test('mismatched native UID cannot restore a stored app session', () async {
    final driver = FakePhoneDriver()..user = nativeSession(uid: 'different'),
        api = FakeApi(),
        store = MemoryStore();
    store.values['phoneSession'] = jsonEncode({
      'provider': 'firebase-native',
      'uid': 'expected',
      'baseUrl': api.baseUrl
    });
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: NativeFirebaseIdentityClient(driver: driver),
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(app.user, isNull);
    expect(driver.user, isNull);
    expect(store.values['phoneSession'], isNull);
  });
}
