import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/controller.dart';
import 'package:nightshift/core/media_diagnostics.dart';
import 'package:nightshift/core/models.dart';
import 'fakes.dart';
import 'video_media_test.dart' show FakeRtcEngine, flush;

const diagnosticCallId = '11111111-1111-4111-8111-111111111111';

class DiagnosticsApi extends FakeApi {
  @override
  Future<Json> request(String method, String path,
      {Json? body, String? idempotencyKey}) async {
    final result = await super
        .request(method, path, body: body, idempotencyKey: idempotencyKey);
    Object? translate(Object? value) {
      if (value == 'call-id') return diagnosticCallId;
      if (value is Map<String, dynamic>) {
        return value.map((key, item) => MapEntry(key, translate(item)));
      }
      if (value is List) return value.map(translate).toList();
      return value;
    }

    return translate(result) as Json;
  }
}

const controllerConnection = RtcConnection(channelId: 'channel', localUid: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiagnosticsApi api;
  late FakeRtcEngine engine;
  late AgoraCallAudio audio;
  late MemoryStore store;
  late AppController state;
  late Duration now;
  late bool allowed;
  setUp(() async {
    api = DiagnosticsApi();
    engine = FakeRtcEngine();
    store = MemoryStore();
    now = Duration.zero;
    allowed = true;
    audio = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async => allowed,
        cleanupTimeout: const Duration(milliseconds: 30));
    state = AppController(
        api: api,
        store: store,
        audio: audio,
        diagnosticsNow: () => now,
        startTimers: false);
    await state.initialize();
    await state.login('http://localhost:3000', 'customer', 'key');
  });
  tearDown(() => state.dispose());

  Future<void> observed(String callState) async {
    api.call = callJson(state: callState);
    await state.refresh();
    await flush();
  }

  test('ringing and never-accepted terminal calls retain unknown acceptance',
      () async {
    await observed('ringing');
    final initial = state.mediaDiagnostics!;
    expect(initial.milestones.keys, contains(DiagnosticMilestone.callObserved));
    expect(initial.milestones.keys,
        isNot(contains(DiagnosticMilestone.acceptedObserved)));
    await state.transition('decline');
    final ended = state.mediaDiagnostics!;
    expect(ended.receiptId, initial.receiptId);
    expect(
        ended.milestones.keys, contains(DiagnosticMilestone.callEndedObserved));
    expect(ended.milestones.keys,
        isNot(contains(DiagnosticMilestone.acceptedObserved)));
    expect(
        ended.milestones.keys, isNot(contains(DiagnosticMilestone.sdkJoined)));
  });

  test(
      'accepted connecting call with token failure is not a successful SDK join',
      () async {
    api.rtcFailure =
        const ApiFailure('RTC_UNAVAILABLE', 'private synthetic text');
    await observed('connecting');
    final receipt = state.mediaDiagnostics!;
    expect(receipt.milestones.keys,
        contains(DiagnosticMilestone.acceptedObserved));
    expect(receipt.milestones.keys,
        isNot(contains(DiagnosticMilestone.sdkJoined)));
    expect(receipt.failure, DiagnosticFailure.credentialsUnavailable);
    expect(engine.called(#initialize), isFalse);
    expect(
        api.requests.where((r) => r['path'] == '/calls/$diagnosticCallId/end'),
        hasLength(1));
    expect(
        state.exportMediaDiagnostics(
            expectedOwner: state.accountIdentity,
            callId: receipt.callId,
            receiptId: receipt.receiptId),
        isNot(contains('private synthetic text')));
  });

  for (final operation in [#initialize, #joinChannel]) {
    test(
        'accepted connecting call records SDK failure before cleanup: $operation',
        () async {
      engine.failures.add(operation);
      await observed('connecting');
      final receipt = state.mediaDiagnostics!;
      expect(receipt.milestones.keys,
          contains(DiagnosticMilestone.acceptedObserved));
      expect(receipt.milestones.keys,
          isNot(contains(DiagnosticMilestone.sdkJoined)));
      expect(receipt.failure, DiagnosticFailure.joinFailed);
      expect(receipt.cleanup, DiagnosticCleanup.released);
      expect(receipt.milestones.keys,
          contains(DiagnosticMilestone.callEndedObserved));
    });
  }

  test(
      'permission denial for an existing invitation is recorded without acceptance',
      () async {
    api.user = userJson(listener: true);
    await observed('ringing');
    allowed = false;
    await state.transition('accept');
    expect(state.mediaDiagnostics!.failure, DiagnosticFailure.microphoneDenied);
    expect(state.mediaDiagnostics!.milestones.keys,
        isNot(contains(DiagnosticMilestone.acceptedObserved)));
    expect(
        api.requests
            .where((r) => r['path'] == '/calls/$diagnosticCallId/accept'),
        isEmpty);
  });

  test(
      'quality callbacks never drive HTTP, storage, readiness, time or charges',
      () async {
    await observed('connecting');
    final call = state.activeCall!;
    final stored = Map<String, String>.from(store.values);
    api.requests.clear();
    engine.handler!.onLocalAudioStats!(controllerConnection,
        const LocalAudioStats(txPacketLossRate: 80, sentBitrate: 0));
    engine.handler!.onRemoteAudioStats!(controllerConnection,
        const RemoteAudioStats(uid: 2, receivedBitrate: 0, audioLossRate: 90));
    engine.handler!.onRtcStats!(controllerConnection,
        const RtcStats(lastmileDelay: 5000, duration: 99999));
    await flush();
    expect(state.mediaDiagnostics!.metrics, hasLength(5));
    expect(audio.ready, isFalse);
    expect(api.requests, isEmpty);
    expect(store.values, stored);
    expect(state.activeCall!.connectedMs, call.connectedMs);
    expect(state.activeCall!.chargeMicrocredits, call.chargeMicrocredits);
    expect(state.mediaDiagnostics!.failure, isNull);
  });

  test(
      'native release before delayed End still records the server terminal observation',
      () async {
    await observed('connecting');
    final response = Completer<Json>();
    api.interceptor = (method, path, body) async =>
        path.endsWith('/end') ? response.future : null;
    final ending = state.transition('end');
    await flush();
    expect(state.mediaDiagnostics!.cleanup, DiagnosticCleanup.released);
    expect(state.mediaDiagnostics!.milestones.keys,
        isNot(contains(DiagnosticMilestone.callEndedObserved)));
    api.call = null;
    response.complete(callJson(state: 'ended'));
    await ending;
    expect(state.mediaDiagnostics!.milestones.keys,
        contains(DiagnosticMilestone.callEndedObserved));
  });

  test('logout clears receipt and old SDK callbacks cannot restore it',
      () async {
    await observed('connecting');
    final receipt = state.mediaDiagnostics!, owner = state.accountIdentity;
    final oldHandler = engine.handler!;
    await state.logout();
    oldHandler.onJoinChannelSuccess!(controllerConnection, 0);
    oldHandler.onRtcStats!(
        controllerConnection, const RtcStats(lastmileDelay: 9));
    expect(state.mediaDiagnostics, isNull);
    expect(state.mediaDiagnosticsFor(receipt.callId), isNull);
    expect(
        state.exportMediaDiagnostics(
            expectedOwner: owner,
            callId: receipt.callId,
            receiptId: receipt.receiptId),
        isNull);
  });

  test('401 invalidation clears receipt while cleanup remains pending',
      () async {
    await observed('connecting');
    final released = Completer<void>();
    engine.pending[#release] = released;
    api.snapshotFailure =
        const ApiFailure('UNAUTHENTICATED', 'Expired', status: 401);
    await state.refresh();
    expect(state.user, isNull);
    expect(state.mediaDiagnostics, isNull);
    released.complete();
    await flush();
    expect(state.mediaDiagnostics, isNull);
  });

  test(
      'same-user fresh sign-in, owner replacement, and origin changes deny old exports',
      () async {
    await observed('ringing');
    var receipt = state.mediaDiagnostics!, owner = state.accountIdentity;
    api.call = null;
    await state.login('http://localhost:3000', 'customer', 'key');
    expect(state.mediaDiagnostics, isNull);
    expect(
        state.exportMediaDiagnostics(
            expectedOwner: owner,
            callId: receipt.callId,
            receiptId: receipt.receiptId),
        isNull);
    await observed('ringing');
    receipt = state.mediaDiagnostics!;
    owner = state.accountIdentity;
    state.user = UserProfile.fromJson({...userJson(), 'id': 'replacement'});
    expect(state.mediaDiagnostics, isNull);
    expect(
        state.exportMediaDiagnostics(
            expectedOwner: owner,
            callId: receipt.callId,
            receiptId: receipt.receiptId),
        isNull);
    state.user = UserProfile.fromJson(userJson());
    api.call = {...callJson(), 'id': '22222222-2222-4222-8222-222222222222'};
    await state.refresh();
    receipt = state.mediaDiagnostics!;
    owner = state.accountIdentity;
    api.baseUrl = 'https://replacement.test';
    expect(state.mediaDiagnostics, isNull);
    expect(
        state.exportMediaDiagnostics(
            expectedOwner: owner,
            callId: receipt.callId,
            receiptId: receipt.receiptId),
        isNull);
  });

  test(
      'expired active call cannot recreate a receipt through snapshots; next call replaces it',
      () async {
    await observed('ringing');
    final first = state.mediaDiagnostics!;
    now = const Duration(minutes: 15);
    expect(state.mediaDiagnostics, isNull);
    await state.refresh();
    expect(state.mediaDiagnostics, isNull);
    api.call = {...callJson(), 'id': '33333333-3333-4333-8333-333333333333'};
    await state.refresh();
    expect(
        state.mediaDiagnostics!.callId, '33333333-3333-4333-8333-333333333333');
    expect(state.mediaDiagnostics!.receiptId, isNot(first.receiptId));
    expect(state.mediaDiagnosticsFor(first.callId), isNull);
  });

  test(
      'token replacement within the same identity preserves receipt and explicit symptom export',
      () async {
    await observed('ringing');
    final receipt = state.mediaDiagnostics!;
    api.token = 'renewed-synthetic-token';
    await state.refresh();
    expect(state.mediaDiagnostics!.receiptId, receipt.receiptId);
    final encoded = state.exportMediaDiagnostics(
        expectedOwner: state.accountIdentity,
        callId: receipt.callId,
        receiptId: receipt.receiptId,
        symptom: DiagnosticSymptom.couldNotHearOther)!;
    final exported = jsonDecode(encoded) as Map;
    expect(exported['userReportedSymptom'], 'couldNotHearOther');
    expect(encoded, isNot(contains('renewed-synthetic-token')));
    expect(state.mediaDiagnostics!.failure, isNull);
  });

  test('legacy adapter remains compatible and does not invent SDK facts',
      () async {
    final legacyApi = DiagnosticsApi(), legacyAudio = FakeAudio();
    final legacy = AppController(
        api: legacyApi,
        store: MemoryStore(),
        audio: legacyAudio,
        startTimers: false);
    try {
      await legacy.initialize();
      await legacy.login('http://localhost:3000', 'customer', 'key');
      legacyApi.call = callJson(state: 'connecting');
      await legacy.refresh();
      await flush();
      expect(legacyAudio.joinCount, 1);
      expect(legacy.mediaDiagnostics!.milestones.keys,
          contains(DiagnosticMilestone.acceptedObserved));
      expect(legacy.mediaDiagnostics!.milestones.keys,
          isNot(contains(DiagnosticMilestone.sdkJoined)));
    } finally {
      legacy.dispose();
    }
  });
}
