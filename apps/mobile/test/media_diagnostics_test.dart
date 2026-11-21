import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/media_diagnostics.dart';

const callA = '00000000-0000-4000-8000-000000000001';
const callB = '00000000-0000-4000-8000-000000000002';
void main() {
  testWidgets(
      'receipt expires on its original monotonic timer without another read or callback',
      (tester) async {
    var now = Duration.zero, notifications = 0;
    final recorder = MediaDiagnostics(
        owner: () => 'private-owner',
        origin: () => 'https://private.example',
        monotonicNow: () => now,
        onChanged: () => notifications++);
    addTearDown(recorder.dispose);
    final sink = recorder.begin(
        owner: 'private-owner',
        callId: callA,
        mediaType: DiagnosticMediaType.audio);
    expect(sink, isNotNull);
    expect(recorder.snapshot, isNotNull);
    await tester.pump();
    final initialNotifications = notifications;
    now = const Duration(minutes: 14);
    sink!.metric(DiagnosticMetric.localSentKbps, 12);
    recorder.snapshot;
    await tester.pump(const Duration(minutes: 14));
    final beforeExpiry = notifications;
    expect(beforeExpiry, greaterThanOrEqualTo(initialNotifications));
    now = const Duration(minutes: 15);
    await tester.pump(const Duration(minutes: 1));
    expect(notifications, greaterThan(beforeExpiry),
        reason: 'Timer erases and notifies without requiring a getter');
    expect(recorder.snapshot, isNull);
    expect(recorder.export(), isNull);
    expect(
        recorder.begin(
            owner: 'private-owner',
            callId: callA,
            mediaType: DiagnosticMediaType.audio),
        isNull);
    sink.metric(DiagnosticMetric.localSentKbps, 99);
    expect(recorder.snapshot, isNull);
    expect(
        recorder.begin(
            owner: 'private-owner',
            callId: callB,
            mediaType: DiagnosticMediaType.audio),
        isNotNull);
    recorder.dispose();
  });

  test(
      'receipt exports a fresh allowlisted map and never owner origin or arbitrary text',
      () {
    final recorder = MediaDiagnostics(
        owner: () => 'secret-account',
        origin: () => 'https://secret-origin.example');
    addTearDown(recorder.dispose);
    final sink = recorder.begin(
        owner: 'secret-account',
        callId: callA,
        mediaType: DiagnosticMediaType.video)!;
    sink.milestone(DiagnosticMilestone.sdkJoined);
    sink.failure(DiagnosticFailure.joinFailed);
    final receipt = recorder.snapshot!, export = recorder.export()!;
    expect(receipt.receiptId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(receipt.receiptId, isNot(callA));
    expect(export['callId'], callA);
    expect(export.containsKey('userReportedSymptom'), isFalse);
    final encoded = jsonEncode(export);
    expect(encoded, isNot(contains('secret-account')));
    expect(encoded, isNot(contains('secret-origin')));
    expect(export.keys.toSet(), {
      'receiptId',
      'callId',
      'mediaType',
      'attempt',
      'ageMilliseconds',
      'remainingMilliseconds',
      'milestones',
      'metrics',
      'failure',
      'capture',
      'cleanup',
      'localMute',
      'remoteMute',
      'reconnectCount',
      'previousCleanupAttempt',
      'previousCleanup'
    });
    expect(
        recorder.export(
            symptom:
                DiagnosticSymptom.otherCouldNotHearMe)!['userReportedSymptom'],
        'otherCouldNotHearMe');
    expect(recorder.export()!.containsKey('userReportedSymptom'), isFalse);
    export['callId'] = 'tampered';
    expect(recorder.snapshot!.callId, callA);
    expect(() => receipt.milestones[DiagnosticMilestone.callObserved] = 999,
        throwsUnsupportedError);
    expect(() => receipt.metrics.clear(), throwsUnsupportedError);
  });

  test(
      'owner revision origin invalidity disposal and next call invalidate captured sinks',
      () {
    Object? owner = ('one', 1);
    var origin = 'https://one.example';
    final recorder = MediaDiagnostics(owner: () => owner, origin: () => origin);
    addTearDown(recorder.dispose);
    final first = recorder.begin(
        owner: owner, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    final oldId = recorder.snapshot!.receiptId;
    recorder.begin(
        owner: owner, callId: callB, mediaType: DiagnosticMediaType.audio);
    first.failure(DiagnosticFailure.mediaFailure);
    first.cleanup(DiagnosticCleanup.released);
    expect(recorder.snapshot!.failure, isNull);
    expect(recorder.snapshot!.receiptId, isNot(oldId));
    origin = 'https://two.example';
    expect(recorder.snapshot, isNull);
    recorder.begin(
        owner: owner, callId: callA, mediaType: DiagnosticMediaType.audio);
    owner = ('one', 2);
    expect(recorder.owner, isNull);
    expect(recorder.export(), isNull);
    recorder.begin(
        owner: owner, callId: callB, mediaType: DiagnosticMediaType.audio);
    owner = null;
    expect(recorder.snapshot, isNull);
    owner = ('two', 1);
    final current = recorder.begin(
        owner: owner, callId: callB, mediaType: DiagnosticMediaType.audio)!;
    expect(
        recorder.begin(
            owner: ('one', 1),
            callId: callA,
            mediaType: DiagnosticMediaType.audio),
        isNull);
    expect(recorder.snapshot!.callId, callB);
    recorder.dispose();
    current.reconnect();
    expect(recorder.snapshot, isNull);
    expect(
        recorder.begin(
            owner: owner, callId: callA, mediaType: DiagnosticMediaType.audio),
        isNull);
  });

  test(
      'same call attempts retain absolute age and reject old facts except separate prior cleanup',
      () {
    var now = Duration.zero;
    final recorder = MediaDiagnostics(
        owner: () => 1, origin: () => 'origin', monotonicNow: () => now);
    addTearDown(recorder.dispose);
    final first = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    first.milestone(DiagnosticMilestone.acceptedObserved);
    first.milestone(DiagnosticMilestone.sdkJoined);
    first.metric(DiagnosticMetric.localSentKbps, 10);
    first.cleanup(DiagnosticCleanup.pending);
    final id = recorder.snapshot!.receiptId;
    now = const Duration(minutes: 14);
    final second = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    first.metric(DiagnosticMetric.localSentKbps, 999);
    first.capture(DiagnosticCapture.active);
    first.milestone(DiagnosticMilestone.remoteDecodeObserved);
    first.failure(DiagnosticFailure.joinFailed);
    first.reconnect();
    first.remoteMute(DiagnosticMute.muted);
    first.cleanup(DiagnosticCleanup.released);
    first.cleanup(DiagnosticCleanup.failed);
    final receipt = recorder.snapshot!;
    expect(receipt.receiptId, id);
    expect(receipt.attempt, 2);
    expect(receipt.remainingMilliseconds, 60000);
    expect(receipt.metrics, isEmpty);
    expect(receipt.failure, isNull);
    expect(receipt.capture, DiagnosticCapture.unknown);
    expect(receipt.reconnectCount, 0);
    expect(receipt.remoteMute, DiagnosticMute.unknown);
    expect(receipt.milestones.containsKey(DiagnosticMilestone.acceptedObserved),
        isTrue);
    expect(
        receipt.milestones.containsKey(DiagnosticMilestone.sdkJoined), isFalse);
    expect(receipt.previousCleanupAttempt, 1);
    expect(receipt.previousCleanup, DiagnosticCleanup.released);
    expect(receipt.cleanup, DiagnosticCleanup.notRequested);
    second.cleanup(DiagnosticCleanup.pending);
    recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio);
    first.cleanup(DiagnosticCleanup.released);
    expect(recorder.snapshot!.previousCleanupAttempt, 2);
    expect(recorder.snapshot!.previousCleanup, DiagnosticCleanup.pending);
  });

  test(
      'seven metrics preserve missingness bound ranges counters and immutable snapshots',
      () {
    final recorder = MediaDiagnostics(owner: () => 1, origin: () => 'origin');
    addTearDown(recorder.dispose);
    final sink = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    for (final metric in DiagnosticMetric.values) {
      for (final invalid in <num?>[
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
        100001
      ]) {
        sink.metric(metric, invalid);
      }
    }
    expect(recorder.snapshot!.metrics, isEmpty);
    for (final metric in DiagnosticMetric.values) {
      sink.metric(metric, 0);
      sink.metric(metric, 10);
      sink.metric(metric, 5);
    }
    final prior = recorder.snapshot!;
    expect(prior.metrics.length, 7);
    for (final summary in prior.metrics.values) {
      expect(summary.samples, 3);
      expect(summary.latest, 5);
      expect(summary.minimum, 0);
      expect(summary.maximum, 10);
    }
    sink.metric(DiagnosticMetric.localPacketLossPercent, 101);
    sink.metric(DiagnosticMetric.remoteFrameLossPercent, 101);
    sink.metric(DiagnosticMetric.networkTransportDelayMs, 60001);
    expect(
        recorder.snapshot!.metrics[DiagnosticMetric.localPacketLossPercent]!
            .samples,
        3);
    for (var i = 0; i < 66000; i++) {
      sink.metric(DiagnosticMetric.localSentKbps, 20);
      sink.reconnect();
    }
    expect(recorder.snapshot!.reconnectCount, 65535);
    expect(recorder.snapshot!.metrics[DiagnosticMetric.localSentKbps]!.samples,
        65535);
    expect(prior.metrics[DiagnosticMetric.localSentKbps]!.samples, 3);
  });

  testWidgets(
      'observer coalescing is asynchronous and exceptions never enter media callbacks',
      (tester) async {
    var calls = 0;
    final recorder = MediaDiagnostics(
        owner: () => 1,
        origin: () => 'origin',
        onChanged: () {
          calls++;
          throw StateError('private observer error');
        });
    addTearDown(recorder.dispose);
    final sink = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    for (var i = 0; i < 100; i++) {
      sink.metric(DiagnosticMetric.localSentKbps, i);
    }
    expect(calls, 0);
    await tester.pump();
    expect(calls, 1);
    recorder.clear();
    expect(calls, 1);
    await tester.pump();
    expect(calls, 2);
  });

  test(
      'invalid IDs and terminal observations cannot manufacture or revive a receipt',
      () {
    final recorder = MediaDiagnostics(owner: () => 1, origin: () => 'origin');
    addTearDown(recorder.dispose);
    for (final id in ['phone +919876543210', 'raw-channel', '', 'a' * 37]) {
      expect(
          recorder.begin(
              owner: 1, callId: id, mediaType: DiagnosticMediaType.audio),
          isNull);
      expect(recorder.export(), isNull);
    }
    final sink = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    sink.milestone(DiagnosticMilestone.callEndedObserved);
    sink.metric(DiagnosticMetric.localSentKbps, 99);
    expect(recorder.snapshot!.metrics, isEmpty);
    expect(
        recorder.begin(
            owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio),
        isNull);
    sink.cleanup(DiagnosticCleanup.pending);
    sink.cleanup(DiagnosticCleanup.released);
    sink.cleanup(DiagnosticCleanup.failed);
    expect(recorder.snapshot!.cleanup, DiagnosticCleanup.released);
  });

  test(
      'server ended observation may follow release without reopening SDK facts',
      () {
    final recorder = MediaDiagnostics(owner: () => 1, origin: () => 'origin');
    addTearDown(recorder.dispose);
    final sink = recorder.begin(
        owner: 1, callId: callA, mediaType: DiagnosticMediaType.audio)!;
    sink.cleanup(DiagnosticCleanup.released);
    sink.milestone(DiagnosticMilestone.sdkJoined);
    sink.metric(DiagnosticMetric.localSentKbps, 99);
    sink.milestone(DiagnosticMilestone.callEndedObserved);
    expect(
        recorder.snapshot!.milestones
            .containsKey(DiagnosticMilestone.callEndedObserved),
        isTrue);
    expect(
        recorder.snapshot!.milestones
            .containsKey(DiagnosticMilestone.sdkJoined),
        isFalse);
    expect(recorder.snapshot!.metrics, isEmpty);
    expect(recorder.snapshot!.cleanup, DiagnosticCleanup.released);
  });
}
