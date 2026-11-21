import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/media_diagnostics.dart';
import 'audio_lifecycle_test.dart' show Completion, failureCode;
import 'video_media_test.dart' show FakeRtcEngine, credentials, flush;

const connection = RtcConnection(channelId: 'test-channel', localUid: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Object? owner;
  late Duration now;
  late MediaDiagnostics recorder;
  late FakeRtcEngine engine;
  late AgoraCallAudio audio;
  var widgetOwned = false;
  MediaDiagnosticSink begin(
          [String id = '11111111-1111-4111-8111-111111111111']) =>
      recorder.begin(
          owner: owner!, callId: id, mediaType: DiagnosticMediaType.audio)!;
  Future<void> join(MediaDiagnosticSink sink) =>
      audio.joinWithDiagnostics(credentials(), () async => credentials(),
          video: false, sink: sink);

  void widgetTest(
      String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      widgetOwned = true;
      // Engine barriers must be created in the same fake-async zone as pumps.
      audio = AgoraCallAudio(
          engineFactory: () => engine,
          microphonePermission: () async => true,
          cameraPermission: () async => true,
          cleanupTimeout: const Duration(milliseconds: 40));
      try {
        await body(tester);
      } finally {
        recorder.dispose();
        final cleanup = Completion(audio.leave());
        await tester.pump(const Duration(milliseconds: 40));
        await cleanup.done;
      }
    });
  }

  setUp(() {
    widgetOwned = false;
    owner = Object();
    now = Duration.zero;
    recorder = MediaDiagnostics(
        owner: () => owner,
        origin: () => 'https://api.test',
        monotonicNow: () => now);
    engine = FakeRtcEngine();
    audio = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async => true,
        cameraPermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
  });
  tearDown(() async {
    recorder.dispose();
    if (widgetOwned) return; // Already settled in the widget's fake-async zone.
    try {
      await audio.leave();
    } catch (_) {/* Failure is asserted by the case. */}
  });

  test('join method completion is not SDK join or audibility evidence',
      () async {
    await join(begin());
    expect(
        recorder.snapshot!.milestones.keys, [DiagnosticMilestone.callObserved]);
    expect(audio.ready, isFalse);
    engine.handler!.onJoinChannelSuccess!(connection, 123);
    expect(recorder.snapshot!.milestones.keys,
        contains(DiagnosticMilestone.sdkJoined));
    expect(recorder.snapshot!.milestones.keys,
        isNot(contains(DiagnosticMilestone.localCaptureObserved)));
    expect(audio.ready, isFalse);
    engine.audioConnected();
    expect(audio.ready, isTrue);
    expect(
        recorder.snapshot!.milestones.keys,
        containsAll([
          DiagnosticMilestone.localCaptureObserved,
          DiagnosticMilestone.remoteDecodeObserved,
        ]));
  });

  test(
      'actual callbacks map seven independent scalar metrics without readiness changes',
      () async {
    await join(begin());
    var readinessNotifications = 0;
    audio.onChanged = () => readinessNotifications++;
    engine.handler!.onLocalAudioStats!(connection,
        const LocalAudioStats(txPacketLossRate: 12, sentBitrate: 35));
    engine.handler!.onRemoteAudioStats!(
        connection,
        const RemoteAudioStats(
            uid: 2,
            audioLossRate: 7,
            receivedBitrate: 24,
            networkTransportDelay: 111,
            jitterBufferDelay: 32));
    engine.handler!.onRtcStats!(
        connection,
        const RtcStats(
            lastmileDelay: 48,
            duration: 99999,
            txPacketLossRate: 99,
            rxPacketLossRate: 88));
    final metrics = recorder.snapshot!.metrics;
    expect(metrics.map((k, v) => MapEntry(k, v.latest)), {
      DiagnosticMetric.localPacketLossPercent: 12,
      DiagnosticMetric.localSentKbps: 35,
      DiagnosticMetric.remoteFrameLossPercent: 7,
      DiagnosticMetric.remoteReceivedKbps: 24,
      DiagnosticMetric.networkTransportDelayMs: 111,
      DiagnosticMetric.jitterBufferDelayMs: 32,
      DiagnosticMetric.clientServerDelayMs: 48,
    });
    expect(audio.ready, isFalse);
    expect(readinessNotifications, 0);
    expect(recorder.snapshot!.failure, isNull);
    engine.handler!.onLocalAudioStats!(connection,
        const LocalAudioStats(txPacketLossRate: -1, sentBitrate: 0));
    engine.handler!.onRemoteAudioStats!(
        connection, const RemoteAudioStats(uid: 2, audioLossRate: 101));
    expect(
        recorder.snapshot!.metrics[DiagnosticMetric.localPacketLossPercent]!
            .samples,
        1);
    expect(
        recorder.snapshot!.metrics[DiagnosticMetric.localSentKbps]!.latest, 0);
    expect(
        recorder.snapshot!.metrics[DiagnosticMetric.remoteFrameLossPercent]!
            .samples,
        1);
  });

  test('foreign connection and remote UID samples cannot enter the receipt',
      () async {
    await join(begin());
    engine.handler!.onRemoteAudioStats!(
        connection, const RemoteAudioStats(uid: 99, audioLossRate: 10));
    engine.handler!.onLocalAudioStats!(
        const RtcConnection(channelId: 'foreign', localUid: 1),
        const LocalAudioStats(txPacketLossRate: 10));
    engine.handler!.onRtcStats!(
        const RtcConnection(channelId: 'test-channel', localUid: 99),
        const RtcStats(lastmileDelay: 10));
    engine.handler!.onJoinChannelSuccess!(
        const RtcConnection(channelId: 'foreign', localUid: 1), 0);
    expect(recorder.snapshot!.metrics, isEmpty);
    expect(
        recorder.snapshot!.milestones.keys, [DiagnosticMilestone.callObserved]);
  });

  test(
      'intentional local and remote mute and zero receive bitrate are not failure',
      () async {
    await join(begin());
    engine.audioConnected();
    await audio.toggleMute();
    engine.handler!.onRemoteAudioStateChanged!(
        connection,
        2,
        RemoteAudioState.remoteAudioStateStopped,
        RemoteAudioStateReason.remoteAudioReasonRemoteMuted,
        0);
    engine.handler!.onRemoteAudioStats!(
        connection, const RemoteAudioStats(uid: 2, receivedBitrate: 0));
    expect(recorder.snapshot!.localMute, DiagnosticMute.muted);
    expect(recorder.snapshot!.remoteMute, DiagnosticMute.muted);
    expect(recorder.snapshot!.failure, isNull);
    expect(audio.ready, isTrue);
    await audio.toggleMute();
    engine.handler!.onRemoteAudioStateChanged!(
        connection,
        2,
        RemoteAudioState.remoteAudioStateDecoding,
        RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted,
        0);
    expect(recorder.snapshot!.localMute, DiagnosticMute.unmuted);
    expect(recorder.snapshot!.remoteMute, DiagnosticMute.unmuted);
  });

  test('failure observation precedes a synchronous readiness-triggered cleanup',
      () async {
    await join(begin());
    audio.onChanged = () {
      audio.onChanged = null;
      unawaited(audio.leave());
    };
    engine.handler!.onConnectionStateChanged!(
        connection,
        ConnectionStateType.connectionStateFailed,
        ConnectionChangedReasonType.connectionChangedRejectedByServer);
    await flush();
    expect(recorder.snapshot!.failure, DiagnosticFailure.connectionFailed);
    expect(recorder.snapshot!.cleanup, DiagnosticCleanup.released);
  });

  test('reconnect is an observation and does not invent a technical failure',
      () async {
    await join(begin());
    engine.handler!.onConnectionStateChanged!(
        connection,
        ConnectionStateType.connectionStateReconnecting,
        ConnectionChangedReasonType.connectionChangedInterrupted);
    expect(recorder.snapshot!.reconnectCount, 1);
    expect(recorder.snapshot!.failure, isNull);
  });

  test('SDK raw error message is discarded and only a safe enum is recorded',
      () async {
    await join(begin());
    engine.handler!.onError!(ErrorCodeType.errFailed,
        'secret-token phone +919999999999 private-channel');
    expect(recorder.snapshot!.failure, DiagnosticFailure.mediaFailure);
    expect(recorder.export().toString(), isNot(contains('secret-token')));
    expect(recorder.export().toString(), isNot(contains('+919999999999')));
  });

  test('preview callbacks collect no call diagnostics', () async {
    begin();
    await audio.startPreview('synthetic-app');
    engine.audioConnected();
    engine.handler!.onRtcStats!(connection, const RtcStats(lastmileDelay: 10));
    expect(
        recorder.snapshot!.milestones.keys, [DiagnosticMilestone.callObserved]);
    expect(recorder.snapshot!.metrics, isEmpty);
  });

  test('detached callbacks cannot populate a new call receipt', () async {
    await join(begin());
    final oldHandler = engine.handler!;
    await audio.leave();
    final next = FakeRtcEngine();
    audio = AgoraCallAudio(
        engineFactory: () => next, microphonePermission: () async => true);
    await join(begin('22222222-2222-4222-8222-222222222222'));
    oldHandler.onRemoteAudioStats!(
        connection, const RemoteAudioStats(uid: 2, audioLossRate: 55));
    oldHandler.onJoinChannelSuccess!(connection, 0);
    expect(recorder.snapshot!.callId, '22222222-2222-4222-8222-222222222222');
    expect(recorder.snapshot!.metrics, isEmpty);
    expect(
        recorder.snapshot!.milestones.keys, [DiagnosticMilestone.callObserved]);
    next.audioConnected();
    expect(recorder.snapshot!.milestones.keys,
        contains(DiagnosticMilestone.sdkJoined));
  });

  widgetTest(
      'sink cannot be retargeted when an older permission request resolves',
      (tester) async {
    final permission = Completer<bool>();
    var requests = 0, creations = 0;
    audio = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () =>
            ++requests == 1 ? permission.future : Future.value(true));
    final old = Completion(join(begin()));
    await tester.pump();
    final fresh =
        Completion(join(begin('22222222-2222-4222-8222-222222222222')));
    await tester.pump();
    await fresh.done;
    engine.audioConnected();
    permission.complete(true);
    await tester.pump();
    await old.done;
    expect(creations, 1);
    expect(recorder.snapshot!.callId, '22222222-2222-4222-8222-222222222222');
    expect(recorder.snapshot!.milestones.keys,
        contains(DiagnosticMilestone.sdkJoined));
    expect(recorder.snapshot!.cleanup, DiagnosticCleanup.notRequested);
  });

  for (final invalidate in ['none', 'owner', 'expiry', 'next-call']) {
    widgetTest('pending cleanup only settles its retained scope: $invalidate',
        (tester) async {
      final joined = Completion(join(begin()));
      await tester.pump();
      await joined.done;
      final release = Completer<void>();
      engine.pending[#release] = release;
      final leaving = Completion(audio.leave());
      await tester.pump(const Duration(milliseconds: 40));
      expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(recorder.snapshot!.cleanup, DiagnosticCleanup.pending);
      if (invalidate == 'owner') owner = Object();
      if (invalidate == 'expiry') now = const Duration(minutes: 15);
      if (invalidate == 'next-call') {
        begin('22222222-2222-4222-8222-222222222222');
      }
      release.complete();
      await tester.pump();
      if (invalidate == 'none') {
        expect(recorder.snapshot!.cleanup, DiagnosticCleanup.released);
      } else if (invalidate == 'next-call') {
        expect(recorder.snapshot!.cleanup, DiagnosticCleanup.notRequested);
      } else {
        expect(recorder.snapshot, isNull);
      }
    });
  }

  test('native release failure is recorded without claiming release', () async {
    await join(begin());
    engine.failures.add(#release);
    await expectLater(
        audio.leave(), throwsA(failureCode('RTC_CLEANUP_FAILED')));
    expect(recorder.snapshot!.cleanup, DiagnosticCleanup.failed);
    expect(recorder.snapshot!.capture, isNot(DiagnosticCapture.stopped));
  });

  for (final failedMethod in [#initialize, #joinChannel]) {
    test(
        'join failure before/after handler registration survives release: $failedMethod',
        () async {
      engine.failures.add(failedMethod);
      await expectLater(join(begin()), throwsStateError);
      expect(engine.called(#release), isTrue);
      expect(recorder.snapshot!.failure, DiagnosticFailure.joinFailed);
      expect(recorder.snapshot!.cleanup, DiagnosticCleanup.released);
      expect(recorder.snapshot!.milestones.keys,
          isNot(contains(DiagnosticMilestone.sdkJoined)));
    });
  }
}
