import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/firebase_identity_client.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/phone_sign_in.dart';
import 'fakes.dart';

class FakeIdentity implements FirebaseIdentityClient {
  @override
  bool configured = true;
  int exchanges = 0, refreshes = 0;
  Future<FirebaseTokens>? refreshDelay;
  FirebaseTokens tokens = FirebaseTokens('id-token', 'refresh-token',
      DateTime.now().add(const Duration(hours: 1)));
  @override
  Future<FirebaseTokens> exchange(String customToken) async {
    exchanges++;
    return tokens;
  }

  @override
  Future<FirebaseTokens> refresh(String refreshToken) async {
    refreshes++;
    return refreshDelay ?? tokens;
  }

  @override
  void close() {}
}

class PreparingFakeApi extends FakeApi {
  @override
  Future<Json> request(String method, String path,
      {Json? body, String? idempotencyKey}) async {
    if (token != null && !path.startsWith('/auth/')) {
      await prepareSession?.call();
    }
    return super
        .request(method, path, body: body, idempotencyKey: idempotencyKey);
  }
}

class MutableExpiryTokens extends FirebaseTokens {
  MutableExpiryTokens()
      : expiry = DateTime.now().add(const Duration(hours: 1)),
        super('old-id', 'old-refresh', DateTime.utc(2000));
  DateTime expiry;
  @override
  DateTime get expiresAt => expiry;
}

Json _challenge(DateTime now) => {
      'challengeId': 'challenge',
      'state': 'sent',
      'retryAt': now.add(const Duration(seconds: 60)).toIso8601String(),
      'expiresAt': now.add(const Duration(minutes: 5)).toIso8601String()
    };
Json _session(String token, {bool onboarding = true}) => {
      'token': token,
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'user': userJson(),
      'needsOnboarding': onboarding,
      'testOnly': true
    };
Json _profile({bool required = true}) => {
      'required': required,
      'profile': {
        'displayName': '',
        'avatarCode': 'moon',
        'interfaceLanguage': 'en',
        'languages': ['ta'],
        'dateOfBirth': null
      }
    };

void main() {
  test('withdrawn OTP consent prevents verification and provider exchange',
      () async {
    final api = FakeApi(), identity = FakeIdentity();
    api.interceptor = (m, p, b) async =>
        p == '/auth/otp/request' ? _challenge(DateTime.now()) : null;
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone('9876543210');
    flow.setConsent(true);
    await flow.requestCode();
    flow.setConsent(false);
    expect(flow.canVerify, false);
    await flow.verifyCode('123456');
    expect(flow.errorCode, 'OTP_INVALID_CONSENT');
    expect(identity.exchanges, 0);
    expect(api.requests.where((r) => r['path'] == '/auth/otp/verify'), isEmpty);
  });
  test('discovery language filter never changes speaking languages', () async {
    final api = FakeApi(), store = MemoryStore();
    store.values['token'] = 'existing';
    final app = AppController(
        api: api, store: store, audio: FakeAudio(), startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    api.requests.clear();
    await app.setLanguage('en');
    expect(app.user!.languages, ['ta', 'en']);
    expect(app.language, 'en');
    expect(api.requests.where((r) => r['path'] == '/me/languages'), isEmpty);
    expect(api.requests.any((r) => r['path'] == '/snapshot?language=en'), true);
  });
  test('late old-token 401 cannot clear renewed credentials', () async {
    final api = PreparingFakeApi(),
        store = MemoryStore(),
        identity = FakeIdentity();
    final oldTokens = MutableExpiryTokens();
    identity.tokens = oldTokens;
    store.values['phoneSession'] =
        jsonEncode({'refreshToken': 'stored-refresh', 'baseUrl': api.baseUrl});
    api.interceptor = (m, p, b) async {
      if (p == '/auth/exchange') {
        return _session(b!['idToken'] as String, onboarding: false);
      }
      return null;
    };
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: identity,
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    final oldResponse = Completer<Json>();
    api.interceptor = (m, p, b) async {
      if (p == '/auth/exchange') {
        return _session(b!['idToken'] as String, onboarding: false);
      }
      if (p.startsWith('/snapshot')) return oldResponse.future;
      return null;
    };
    final poll = app.refresh();
    await Future<void>.delayed(Duration.zero);
    oldTokens.expiry = DateTime.now().subtract(const Duration(seconds: 1));
    identity.tokens = FirebaseTokens(
        'new-id', 'new-refresh', DateTime.now().add(const Duration(hours: 1)));
    await api.request('GET', '/wallet');
    oldResponse.completeError(
        const ApiFailure('SESSION_REVOKED', 'old token', status: 401));
    await poll;
    expect(api.token, 'new-id');
    expect(app.user, isNotNull);
    expect(store.values['token'], 'new-id');
    expect(store.values['phoneSession'], contains('new-refresh'));
  });
  test('invalid calendar date is not normalized into a different birthday',
      () async {
    final api = FakeApi()..token = 'id';
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..needsOnboarding = true;
    addTearDown(app.dispose);
    await app.completeOnboarding({
      'dateOfBirth': '2000-02-31',
      'displayName': 'Safe',
      'avatarCode': 'moon',
      'interfaceLanguage': 'en',
      'languages': ['ta']
    });
    expect(app.errorCode, 'INVALID_BIRTH_DATE');
    expect(api.requests, isEmpty);
  });
  test('OTP explicit consent, cooldown, expiry and wrong-code recovery',
      () async {
    var now = DateTime.utc(2026, 11, 20);
    final api = FakeApi(), identity = FakeIdentity();
    api.interceptor = (method, path, body) async {
      if (path == '/auth/otp/request') return _challenge(now);
      if (path == '/auth/otp/verify') {
        throw const ApiFailure('OTP_INVALID_CODE', 'safe');
      }
      return null;
    };
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'device',
        clock: () => now,
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone('9876543210');
    await flow.requestCode();
    expect(flow.errorCode, 'OTP_INVALID_CONSENT');
    expect(api.requests, isEmpty);
    flow.setConsent(true);
    await flow.requestCode();
    expect(flow.retrySeconds, 60);
    expect(flow.canRequest, false);
    await flow.verifyCode('123456');
    expect(flow.errorCode, 'OTP_INVALID_CODE');
    expect(flow.challengeId, 'challenge');
    now = now.add(const Duration(minutes: 6));
    await flow.verifyCode('123456');
    expect(flow.errorCode, 'OTP_EXPIRED');
    expect(identity.exchanges, 0);
  });
  test('phone edits invalidate pending request and consent', () async {
    final pending = Completer<Json>();
    final api = FakeApi(), identity = FakeIdentity();
    api.interceptor = (m, p, b) =>
        p == '/auth/otp/request' ? pending.future : Future.value(null);
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {
          fail('stale sign-in');
        });
    addTearDown(flow.dispose);
    flow.editPhone('9876543210');
    flow.setConsent(true);
    final request = flow.requestCode();
    flow.editPhone('9876543211');
    pending.complete(_challenge(DateTime.now()));
    await request;
    expect(flow.challengeId, isNull);
    expect(flow.consent, false);
    expect(flow.busy, false);
  });
  test('uncertain SMS retries preserve key and never use editable dev origin',
      () async {
    final api = FakeApi()..baseUrl = 'http://192.168.1.20:3000';
    api.interceptor = (m, p, b) async {
      if (p == '/auth/otp/request') throw const ApiFailure('OFFLINE', 'safe');
      return null;
    };
    final flow = PhoneSignIn(
        api: api,
        firebase: FakeIdentity(),
        backendUrl: 'https://configured.example.test',
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone('9876543210');
    flow.setConsent(true);
    await flow.requestCode();
    await flow.requestCode();
    expect(api.requests[0]['key'], api.requests[1]['key']);
    expect(api.baseUrl, 'https://configured.example.test');
    final unsafe = PhoneSignIn(
        api: api,
        firebase: FakeIdentity(),
        backendUrl: 'http://192.168.1.20',
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(unsafe.dispose);
    unsafe.editPhone('9876543210');
    unsafe.setConsent(true);
    await unsafe.requestCode();
    expect(unsafe.errorCode, 'PHONE_AUTH_UNAVAILABLE');
    expect(api.requests.length, 2);
  });
  test('consumed proof is not reused when Firebase exchange fails', () async {
    final api = FakeApi(), identity = FakeIdentity()..configured = false;
    api.interceptor = (m, p, b) async {
      if (p == '/auth/otp/request') return _challenge(DateTime.now());
      if (p == '/auth/otp/verify') return {'customToken': 'proof'};
      if (p == '/auth/exchange') {
        throw const ApiFailure('IDENTITY_UNAVAILABLE', 'safe');
      }
      return null;
    };
    identity.configured = true;
    final flow = PhoneSignIn(
        api: api,
        firebase: identity,
        deviceId: () => 'device',
        onAuthenticated: (_, __) async {});
    addTearDown(flow.dispose);
    flow.editPhone('9876543210');
    flow.setConsent(true);
    await flow.requestCode();
    await flow.verifyCode('123456');
    expect(flow.challengeId, isNull);
    await flow.verifyCode('123456');
    expect(identity.exchanges, 1);
  });
  test('new phone account reaches onboarding without discovery or presence',
      () async {
    final api = FakeApi(), store = MemoryStore(), identity = FakeIdentity();
    api.interceptor = (m, p, b) async {
      if (p == '/auth/otp/request') return _challenge(DateTime.now());
      if (p == '/auth/otp/verify') return {'customToken': 'proof'};
      if (p == '/auth/exchange') return _session('id-token');
      if (p == '/me/onboarding') return _profile();
      return null;
    };
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: identity,
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    app.phoneSignIn.editPhone('9876543210');
    app.phoneSignIn.setConsent(true);
    await app.phoneSignIn.requestCode();
    await app.phoneSignIn.verifyCode('123456');
    expect(app.needsOnboarding, true);
    expect(app.user, isNotNull);
    expect(
        api.requests.where((r) =>
            r['path'].startsWith('/snapshot') ||
            r['path'] == '/presence/heartbeat'),
        isEmpty);
    expect(store.values['phoneSession'], isNot(contains('9876543210')));
    expect(store.values['phoneSession'], contains('refresh-token'));
    await app.logout();
    expect(store.values['phoneSession'], isNull);
    expect(store.values['token'], isNull);
  });
  test('phone session restores through Firebase and exchange before onboarding',
      () async {
    final api = FakeApi(), store = MemoryStore(), identity = FakeIdentity();
    store.values.addAll({
      'token': 'old-id',
      'phoneSession':
          jsonEncode({'refreshToken': 'stored-refresh', 'baseUrl': api.baseUrl})
    });
    api.interceptor = (m, p, b) async {
      if (p == '/auth/exchange') return _session('id-token');
      if (p == '/me/onboarding') return _profile();
      return null;
    };
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: identity,
        startTimers: false);
    addTearDown(app.dispose);
    await app.initialize();
    expect(identity.refreshes, 1);
    expect(app.needsOnboarding, true);
    expect(api.token, 'id-token');
    expect(api.requests.first['path'], '/auth/exchange');
  });
  test('late identity renewal cannot restore credentials after logout',
      () async {
    final api = FakeApi(), store = MemoryStore(), identity = FakeIdentity();
    store.values['phoneSession'] =
        jsonEncode({'refreshToken': 'old-refresh', 'baseUrl': api.baseUrl});
    final pending = Completer<FirebaseTokens>();
    identity.refreshDelay = pending.future;
    final app = AppController(
        api: api,
        store: store,
        audio: FakeAudio(),
        identityClient: identity,
        startTimers: false);
    addTearDown(app.dispose);
    final initialization = app.initialize();
    await Future<void>.delayed(Duration.zero);
    await app.logout();
    pending.complete(identity.tokens);
    await initialization;
    expect(app.user, isNull);
    expect(api.token, isNull);
    expect(store.values['phoneSession'], isNull);
  });
  test('underage server rejection retains onboarding and safe error', () async {
    final api = FakeApi();
    api.token = 'id';
    api.interceptor = (m, p, b) async {
      if (m == 'PUT' && p == '/me/onboarding') {
        throw const ApiFailure('ADULT_ONLY', 'private DOB', status: 403);
      }
      return null;
    };
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..needsOnboarding = true;
    addTearDown(app.dispose);
    await app.completeOnboarding({
      'dateOfBirth': '2010-01-01',
      'displayName': 'Safe',
      'avatarCode': 'moon',
      'interfaceLanguage': 'en',
      'languages': ['ta']
    });
    expect(app.needsOnboarding, true);
    expect(app.errorCode, 'ADULT_ONLY');
    expect(
        api.requests.where((r) => r['path'].startsWith('/snapshot')), isEmpty);
  });
}
