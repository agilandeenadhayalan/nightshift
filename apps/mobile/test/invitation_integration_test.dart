import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/models.dart';
import 'package:nightshift/core/native_firebase_identity.dart';
import 'package:nightshift/features/invitation_settings.dart';
import 'package:nightshift_api/api.dart' as sdk;
import 'call_invitations_test.dart' show FakeInvitationDevice, receipt;
import 'native_phone_auth_test.dart'
    show FakePhoneDriver, nativeSession, nativeBackendSession;
import 'fakes.dart';

Future<(AppController, FakeApi, FakeAudio, FakeInvitationDevice)>
    setup() async {
  final token = 'synthetic.${base64Url.encode(utf8.encode(jsonEncode({
            'auth_time': 1795219200
          }))).replaceAll('=', '')}.fixture';
  final api = FakeApi()
    ..user = userJson(listener: true, approved: true, online: true);
  final store = MemoryStore()
    ..values['phoneSession'] = jsonEncode({
      'provider': 'firebase-native',
      'uid': 'opaque-firebase-uid',
      'baseUrl': api.baseUrl,
    });
  final device = FakeInvitationDevice(), audio = FakeAudio();
  Json? current;
  api.interceptor = (method, path, body) async {
    if (path == '/auth/exchange') {
      return {
        ...nativeBackendSession(token),
        'needsOnboarding': false,
        'user': api.user
      };
    }
    if (path == '/me/push/registration' && method == 'GET') {
      return {'registration': current};
    }
    if (path.startsWith('/me/push/registration')) {
      final stamp = DateTime.now().toUtc();
      return current = {
        ...receipt(
            state: path.endsWith('activate')
                ? 'active'
                : method == 'DELETE'
                    ? 'revoked'
                    : 'prepared'),
        'serverTime': stamp.toIso8601String(),
        'leaseExpiresAt': stamp
            .add(Duration(minutes: path.endsWith('activate') ? 30 : 5))
            .toIso8601String()
      };
    }
    return null;
  };
  final controller = AppController(
      api: api,
      store: store,
      audio: audio,
      invitationDevice: device,
      identityClient: NativeFirebaseIdentityClient(
          driver: FakePhoneDriver()..user = nativeSession(token: token)),
      startTimers: false);
  await controller.initialize();
  return (controller, api, audio, device);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'confirmed invitation lease preserves background availability but accepted audio still stops',
      () async {
    final (app, api, audio, _) = await setup();
    addTearDown(app.dispose);
    await app.invitations.enable(consent: true);
    expect(app.invitations.active, isTrue);
    api.requests.clear();
    await app.setForeground(false);
    expect(api.requests.where((r) => r['path'] == '/me/availability'), isEmpty);
    await app.setForeground(true);
    api.call = callJson(state: 'connected');
    app.activeCall = CallSession.fromJson(api.call!);
    api.requests.clear();
    await app.setForeground(false);
    expect(
        api.requests.where((r) => '${r['path']}'.endsWith('/end')).length, 1);
    expect(audio.ready, isFalse);
  });
  test(
      'native open lifetime hint causes only authoritative GET and never auto answer',
      () async {
    final (app, api, audio, device) = await setup();
    addTearDown(app.dispose);
    final saved = api.interceptor;
    final ringing = {...callJson(), 'id': 'call-1'};
    api.interceptor =
        (m, p, b) async => p == '/calls/call-1' ? ringing : saved!(m, p, b);
    api.requests.clear();
    device.hint = {
      'callId': 'call-1',
      'callVersion': '1',
      'remainingMilliseconds': 0
    };
    await app.invitations.recover();
    expect(api.requests.any((r) => r['path'] == '/calls/call-1'), isFalse);
    expect(app.activeCall, isNull);
    api.call = ringing;
    device.hint = {
      'callId': 'call-1',
      'callVersion': '1',
      'remainingMilliseconds': 30000
    };
    await app.invitations.recover();
    expect(api.requests.any((r) => r['path'] == '/calls/call-1'), isTrue);
    expect(app.activeCall?.id, 'call-1');
    expect(app.activeCall?.ringing, isTrue);
    expect(
        api.requests.any((r) =>
            '${r['path']}'.endsWith('/accept') ||
            '${r['path']}'.endsWith('/rtc-token')),
        isFalse);
    expect(audio.ready, isFalse);
  });
  test('late invitation GET cannot install a call after logout', () async {
    final (app, api, _, device) = await setup();
    addTearDown(app.dispose);
    final gate = Completer<Json>();
    var entered = false;
    final saved = api.interceptor;
    api.interceptor = (m, p, b) async {
      if (p == '/calls/call-1') {
        entered = true;
        return gate.future;
      }
      return saved!(m, p, b);
    };
    device.hint = {
      'callId': 'call-1',
      'callVersion': '1',
      'remainingMilliseconds': 30000
    };
    final open = app.invitations.recover();
    while (!entered) {
      await Future<void>.delayed(Duration.zero);
    }
    await app.logout();
    gate.complete(callJson());
    await open;
    expect(app.user, isNull);
    expect(app.activeCall, isNull);
    expect(device.binding, isNull);
  });
  test(
      'background reachable listener can receive audio but cannot pass video preflight',
      () async {
    final app = AppController(
        api: FakeApi(),
        store: MemoryStore(),
        audio: FakeAudio(),
        startTimers: false);
    addTearDown(app.dispose);
    app.user = UserProfile.fromJson(userJson());
    final card = ListenerProfile(
        id: 'listener-id',
        name: 'Listener',
        languages: const ['ta'],
        available: true,
        reachability: 'background_eligible');
    expect(app.canCallListener(card), isTrue);
    expect(app.canCallListener(card, video: true), isFalse);
  });
  test(
      'generated registration transport keeps token in private body and fences changed owner',
      () async {
    var sends = 0;
    Object owner = 'A';
    final api = NightShiftApi(client: MockClient((request) async {
      sends++;
      expect(request.followRedirects, isFalse);
      expect(request.url.query, isEmpty);
      expect(request.headers['Idempotency-Key'], 'frozen-key');
      expect(jsonDecode(request.body), {
        'targetKind': 'fcm_token',
        'token': 'private-token',
        'expectedVersion': null
      });
      return http.Response(jsonEncode(receipt()), 200);
    }))
      ..baseUrl = 'https://private.example'
      ..token = 'synthetic';
    addTearDown(api.close);
    api.sessionIdentity = () => owner;
    await api.privateRequest('PUT', '/me/push/registration',
        origin: api.baseUrl,
        isCurrent: () => true,
        body: {
          'targetKind': 'fcm_token',
          'token': 'private-token',
          'expectedVersion': null
        },
        idempotencyKey: 'frozen-key');
    final gate = Completer<void>();
    api.prepareSession = () => gate.future;
    final work = api.privateRequest('PUT', '/me/push/registration',
        origin: api.baseUrl,
        isCurrent: () => owner == 'A',
        body: {
          'targetKind': 'fcm_token',
          'token': 'private-token',
          'expectedVersion': null
        },
        idempotencyKey: 'frozen-key');
    owner = 'B';
    api.token = 'new-token';
    gate.complete();
    await expectLater(work, throwsA(isA<ApiFailure>()));
    expect(sends, 1);
  });
  test(
      'generated registration rejects missing nullable keys and unknown reachability',
      () {
    final valid = receipt();
    for (final key in valid.keys) {
      expect(() => sdk.PushRegistration.fromJson({...valid}..remove(key)),
          throwsFormatException);
    }
    expect(() => sdk.PushRegistration.fromJson({...valid, 'state': 'online'}),
        throwsFormatException);
    expect(
        sdk.PreparePushRegistration.fromJson({
          'targetKind': 'fcm_token',
          'token': 'private-token',
          'expectedVersion': null
        }).toString(),
        isNot(contains('private-token')));
    expect(
        () => sdk.Listener.fromJson({
              ...directoryCard({
                'id': 'listener-id',
                'displayName': 'Alias',
                'languages': ['ta'],
                'available': true
              }),
              'testOnly': true,
              'reachability': 'guaranteed'
            }),
        throwsFormatException);
  });
  testWidgets(
      'Tamil invitation consent and recovery controls fit 200 percent text',
      (tester) async {
    final (app, _, _, device) = await setup();
    addTearDown(app.dispose);
    app.locale = 'ta';
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: InvitationSettings(controller: app))))));
    expect(tester.takeException(), isNull);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(device.tokens, 0);
    await tester.ensureVisible(find.text('அழைப்பிதழ் நிலையைச் சரிபார்'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(app.invitations.active, isFalse);
  });
}
