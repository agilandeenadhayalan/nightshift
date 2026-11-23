import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';

const draft = {
  'dateOfBirth': '2000-01-01',
  'displayName': 'Private nickname',
  'avatarCode': 'moon',
  'interfaceLanguage': 'ta',
  'languages': ['ta']
};
void main() {
  test(
      'onboarding cannot send account A birth date with account B credentials after refresh',
      () async {
    var sends = 0;
    final gate = Completer<void>();
    final api = NightShiftApi(client: MockClient((request) async {
      sends++;
      return http.Response('{}', 200);
    }))
      ..token = 'token-a'
      ..baseUrl = 'https://api.example';
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..user = UserProfile.fromJson({...userJson(), 'id': 'a'})
      ..needsOnboarding = true;
    addTearDown(app.dispose);
    api.prepareSession = () => gate.future;
    final pending = app.completeOnboarding(draft);
    app.user = UserProfile.fromJson({...userJson(), 'id': 'b'});
    api.token = 'token-b';
    gate.complete();
    await pending;
    expect(sends, 0);
    expect(app.user!.id, 'b');
    expect(app.onboardingProfile, isNull);
    expect(app.errorCode, isNull);
    expect(app.busy, isFalse);
  });
  for (final changeOrigin in [false, true]) {
    test(
        'stale onboarding cannot clear replacement ${changeOrigin ? 'origin' : 'owner'} operation busy or error state',
        () async {
      final oldGate = Completer<void>(), newGate = Completer<void>();
      var sends = 0, replacementStarted = false;
      final api = NightShiftApi(client: MockClient((request) async {
        sends++;
        return http.Response('{}', 200);
      }))
        ..token = 'token-a'
        ..baseUrl = 'https://api.example';
      final app = AppController(
          api: api,
          store: MemoryStore(),
          audio: FakeAudio(),
          startTimers: false)
        ..user = UserProfile.fromJson({...userJson(), 'id': 'a'});
      addTearDown(app.dispose);
      api.prepareSession = () => oldGate.future;
      final pending = app.completeOnboarding(draft);
      Future<void>? replacement;
      try {
        expect(app.busy, isTrue);
        if (changeOrigin) {
          api.baseUrl = 'https://other.example';
        } else {
          app.user = UserProfile.fromJson({...userJson(), 'id': 'b'});
          api.token = 'token-b';
        }
        expect(app.busy, isFalse,
            reason:
                'An old profile operation must not block the replacement scope');
        replacement = app.perform(() async {
          replacementStarted = true;
          await newGate.future;
        });
        expect(replacementStarted, isTrue);
        app.errorCode = 'CURRENT_SCOPE_ERROR';
        expect(app.busy, isTrue);
        oldGate.complete();
        await pending;
        expect(sends, 0,
            reason:
                'Neither a stale mutation nor a replacement snapshot refresh may dispatch');
        expect(app.errorCode, 'CURRENT_SCOPE_ERROR');
        expect(app.busy, isTrue);
        expect(app.onboardingProfile, isNull);
        newGate.complete();
        await replacement;
        expect(app.busy, isFalse);
      } finally {
        if (!oldGate.isCompleted) oldGate.complete();
        if (!newGate.isCompleted) newGate.complete();
        await pending;
        await replacement;
      }
    });
  }
  test(
      'current-owner onboarding failure still reports the error and releases busy',
      () async {
    final app = AppController(
        api: FakeApi()..token = 'current',
        store: MemoryStore(),
        audio: FakeAudio(),
        startTimers: false)
      ..user = UserProfile.fromJson(userJson())
      ..needsOnboarding = true;
    addTearDown(app.dispose);
    await app.completeOnboarding({...draft, 'dateOfBirth': 'invalid'});
    expect(app.errorCode, 'INVALID_BIRTH_DATE');
    expect(app.busy, isFalse);
  });
  test(
      'late onboarding response cannot install profile for a different current account',
      () async {
    final gate = Completer<http.Response>();
    final api = NightShiftApi(client: MockClient((request) => gate.future))
      ..token = 'token-a'
      ..baseUrl = 'https://api.example';
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..user = UserProfile.fromJson({...userJson(), 'id': 'a'})
      ..needsOnboarding = true;
    addTearDown(app.dispose);
    final pending = app.completeOnboarding(draft);
    await Future<void>.delayed(Duration.zero);
    app.user = UserProfile.fromJson({...userJson(), 'id': 'b'});
    api.token = 'token-b';
    gate.complete(
        http.Response(jsonEncode({'required': false, 'profile': draft}), 200));
    await pending;
    expect(app.onboardingProfile, isNull);
    expect(app.needsOnboarding, true);
    expect(app.user!.id, 'b');
  });
  test('ordinary protected mutation also fences changed owner across refresh',
      () async {
    var sends = 0;
    final gate = Completer<void>();
    final api = NightShiftApi(client: MockClient((request) async {
      sends++;
      return http.Response('{"favorite":true}', 200);
    }))
      ..token = 'token-a';
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..user = UserProfile.fromJson({...userJson(), 'id': 'a'});
    addTearDown(app.dispose);
    api.prepareSession = () => gate.future;
    final pending = api.request('PUT', '/favorites/listener-id');
    app.user = UserProfile.fromJson({...userJson(), 'id': 'b'});
    api.token = 'token-b';
    gate.complete();
    await expectLater(
        pending,
        throwsA(isA<ApiFailure>()
            .having((e) => e.code, 'code', 'PRIVATE_SESSION_CHANGED')));
    expect(sends, 0);
  });
  test(
      'same owner token renewal still dispatches one mutation with renewed token',
      () async {
    var sends = 0;
    final api = NightShiftApi(client: MockClient((request) async {
      sends++;
      expect(request.headers['Authorization'], 'Bearer renewed');
      return http.Response('{"favorite":true}', 200);
    }))
      ..token = 'old';
    final app = AppController(
        api: api, store: MemoryStore(), audio: FakeAudio(), startTimers: false)
      ..user = UserProfile.fromJson({...userJson(), 'id': 'a'});
    addTearDown(app.dispose);
    api.prepareSession = () async {
      api.token = 'renewed';
    };
    await api.request('PUT', '/favorites/listener-id');
    expect(sends, 1);
  });
}
