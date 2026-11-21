import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/audio.dart';
import 'video_media_test.dart' show FakeRtcEngine, credentials;

class Completion {
  Completion(Future<void> work) {
    done = work.then((_) {
      settled = true;
    }, onError: (Object failure, StackTrace _) {
      error = failure;
      settled = true;
    });
  }
  late final Future<void> done;
  bool settled = false;
  Object? error;
}

Matcher failureCode(String code) =>
    isA<ApiFailure>().having((error) => error.code, 'code', code);

void main() {
  testWidgets(
      'leave caller times out without releasing ownership of stalled initialization',
      (tester) async {
    final first = FakeRtcEngine(), second = FakeRtcEngine();
    final initialized = Completer<void>();
    first.pending[#initialize] = initialized;
    var creations = 0, permissions = 0;
    final media = AgoraCallAudio(
        engineFactory: () => ++creations == 1 ? first : second,
        microphonePermission: () async {
          permissions++;
          return true;
        });
    final joining =
        Completion(media.join(credentials(), () async => credentials()));
    try {
      await tester.pump();
      expect(first.called(#initialize), isTrue);
      final leaving = Completion(media.leave());
      await tester.pump(const Duration(milliseconds: 2999));
      expect(leaving.settled, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(media.ready, isFalse);
      expect(first.called(#release), isFalse);

      final blocked =
          Completion(media.join(credentials(), () async => credentials()));
      await tester.pump(const Duration(seconds: 3));
      expect(blocked.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(creations, 1);
      expect(permissions, 1);
      initialized.complete();
      await tester.pump();
      await joining.done;
      expect(first.called(#enableAudio), isFalse);
      expect(first.called(#joinChannel), isFalse);
      expect(
          first.calls.where((call) => call.method == #release), hasLength(1));
      expect(creations, 1,
          reason: 'Late release must not restart a timed-out call.');

      final fresh =
          Completion(media.join(credentials(), () async => credentials()));
      await tester.pump();
      await fresh.done;
      expect(fresh.error, isNull);
      expect(creations, 2);
      expect(second.called(#joinChannel), isTrue);
    } finally {
      if (!initialized.isCompleted) initialized.complete();
      await tester.pump();
      final cleanup = Completion(media.leave());
      await tester.pump();
      await cleanup.done;
    }
  });

  testWidgets('shutdown disables capture before transmission mute and release',
      (tester) async {
    final engine = FakeRtcEngine();
    final media = AgoraCallAudio(
        engineFactory: () => engine, microphonePermission: () async => true);
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.audioConnected();
    expect(media.ready, isTrue);
    engine.calls.clear();
    final leaving = Completion(media.leave());
    expect(media.ready, isFalse);
    await tester.pump();
    await leaving.done;
    expect(leaving.error, isNull);
    expect(engine.calls.map((call) => call.method).toList(), [
      #enableLocalAudio,
      #muteLocalAudioStream,
      #leaveChannel,
      #release,
    ]);
    expect(engine.calls.first.arguments, [false]);
  });

  testWidgets('failed native release remains a typed barrier to another engine',
      (tester) async {
    final engine = FakeRtcEngine();
    var creations = 0;
    final media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () async => true);
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.failures.add(#release);
    final leaving = Completion(media.leave());
    await tester.pump();
    await leaving.done;
    expect(leaving.error, failureCode('RTC_CLEANUP_FAILED'));
    final fresh =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await fresh.done;
    expect(fresh.error, failureCode('RTC_CLEANUP_FAILED'));
    expect(creations, 1);
    expect(engine.calls.where((call) => call.method == #release), hasLength(1));
    expect(media.ready, isFalse);
  });

  testWidgets('a stalled capture-disable keeps duplicate cleanup serialized',
      (tester) async {
    final engine = FakeRtcEngine();
    final captureOff = Completer<void>();
    final media = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.audioConnected();
    engine.pending[#enableLocalAudio] = captureOff;
    final first = Completion(media.leave());
    final second = Completion(media.leave());
    try {
      await tester.pump(const Duration(milliseconds: 39));
      expect(first.settled, isFalse);
      expect(second.settled, isFalse);
      expect(media.ready, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(first.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(second.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(engine.calls.where((call) => call.method == #enableLocalAudio),
          hasLength(1));
      expect(engine.called(#muteLocalAudioStream), isFalse);
      expect(engine.called(#leaveChannel), isFalse);
      expect(engine.called(#release), isFalse);
    } finally {
      captureOff.complete();
      await tester.pump();
      final acknowledged = Completion(media.leave());
      await tester.pump();
      await acknowledged.done;
      expect(acknowledged.error, isNull);
      expect(
          engine.calls.where((call) => call.method == #release), hasLength(1));
    }
  });

  testWidgets('late release success permits only a new explicit engine start',
      (tester) async {
    final old = FakeRtcEngine(), next = FakeRtcEngine();
    final released = Completer<void>();
    var creations = 0;
    final media = AgoraCallAudio(
        engineFactory: () => ++creations == 1 ? old : next,
        microphonePermission: () async => true,
        cameraPermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    old.audioConnected();
    old.pending[#release] = released;
    final leaving = Completion(media.leave());
    try {
      await tester.pump(const Duration(milliseconds: 40));
      expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
      final preview = Completion(media.startPreview('test-app'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(preview.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(creations, 1);
      old.audioConnected();
      expect(media.ready, isFalse);
      released.complete();
      await tester.pump();
      expect(creations, 1);
      expect(media.localVideo, isNull);
      final fresh =
          Completion(media.join(credentials(), () async => credentials()));
      await tester.pump();
      await fresh.done;
      expect(fresh.error, isNull);
      expect(creations, 2);
      old.audioConnected();
      expect(media.ready, isFalse);
      next.audioConnected();
      expect(media.ready, isTrue);
      old.audioConnected();
      expect(media.ready, isTrue);
    } finally {
      if (!released.isCompleted) released.complete();
      await tester.pump();
      final cleanup = Completion(media.leave());
      await tester.pump();
      await cleanup.done;
    }
  });

  testWidgets('late native release error is observed and remains failed closed',
      (tester) async {
    final engine = FakeRtcEngine();
    final released = Completer<void>();
    var creations = 0;
    final media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.pending[#release] = released;
    final leaving = Completion(media.leave());
    await tester.pump(const Duration(milliseconds: 40));
    expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
    released
        .completeError(StateError('Synthetic native failure after timeout'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final next =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await next.done;
    expect(next.error, failureCode('RTC_CLEANUP_FAILED'));
    final retry = Completion(media.leave());
    await tester.pump();
    await retry.done;
    expect(retry.error, failureCode('RTC_CLEANUP_FAILED'));
    expect(creations, 1);
    expect(engine.calls.where((call) => call.method == #release), hasLength(1));
  });

  testWidgets(
      'stalled preview stop is bounded and cannot admit a joined engine',
      (tester) async {
    final engine = FakeRtcEngine();
    final stopped = Completer<void>();
    var creations = 0, microphoneRequests = 0;
    final media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () async {
          microphoneRequests++;
          return true;
        },
        cameraPermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
    final preview = Completion(media.startPreview('test-app'));
    await tester.pump();
    await preview.done;
    engine.videoCaptured();
    engine.pending[#stopPreview] = stopped;
    final closing = Completion(media.stopPreview());
    try {
      await tester.pump(const Duration(milliseconds: 40));
      expect(closing.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(media.previewing, isFalse);
      expect(media.localVideo, isNull);
      final join =
          Completion(media.join(credentials(), () async => credentials()));
      await tester.pump(const Duration(milliseconds: 40));
      expect(join.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(creations, 1);
      expect(microphoneRequests, 0);
      expect(engine.called(#joinChannel), isFalse);
      expect(engine.called(#release), isFalse);
    } finally {
      stopped.complete();
      await tester.pump();
      final cleanup = Completion(media.leave());
      await tester.pump();
      await cleanup.done;
      expect(cleanup.error, isNull);
    }
  });

  testWidgets(
      'repeated preview stop cannot acknowledge a still-pending release',
      (tester) async {
    final engine = FakeRtcEngine();
    final released = Completer<void>();
    final media = AgoraCallAudio(
        engineFactory: () => engine,
        cameraPermission: () async => true,
        cleanupTimeout: const Duration(milliseconds: 40));
    final preview = Completion(media.startPreview('test-app'));
    await tester.pump();
    await preview.done;
    engine.pending[#release] = released;
    final first = Completion(media.stopPreview());
    try {
      await tester.pump(const Duration(milliseconds: 40));
      expect(first.error, failureCode('RTC_CLEANUP_PENDING'));
      final repeated = Completion(media.stopPreview());
      await tester.pump(const Duration(milliseconds: 39));
      expect(repeated.settled, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repeated.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(
          engine.calls.where((call) => call.method == #release), hasLength(1));
    } finally {
      released.complete();
      await tester.pump();
      final complete = Completion(media.stopPreview());
      await tester.pump();
      await complete.done;
      expect(complete.error, isNull);
    }
  });

  testWidgets('pre-call permission cannot pass while native release is pending',
      (tester) async {
    final engine = FakeRtcEngine();
    final released = Completer<void>();
    var permissions = 0;
    final media = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async {
          permissions++;
          return true;
        },
        cleanupTimeout: const Duration(milliseconds: 40));
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.pending[#release] = released;
    final leaving = Completion(media.leave());
    try {
      await tester.pump(const Duration(milliseconds: 40));
      expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
      final preflight = Completion(media.checkPermission());
      await tester.pump(const Duration(milliseconds: 40));
      expect(preflight.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(permissions, 1);
    } finally {
      released.complete();
      await tester.pump();
      final fresh = Completion(media.checkPermission());
      await tester.pump();
      await fresh.done;
      expect(fresh.error, isNull);
    }
  });

  testWidgets('failed native release also prevents a new permission preflight',
      (tester) async {
    final engine = FakeRtcEngine();
    var permissions = 0;
    final media = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async {
          permissions++;
          return true;
        });
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.failures.add(#release);
    final leaving = Completion(media.leave());
    await tester.pump();
    await leaving.done;
    expect(leaving.error, failureCode('RTC_CLEANUP_FAILED'));
    final preflight = Completion(media.checkPermission());
    await tester.pump();
    await preflight.done;
    expect(preflight.error, failureCode('RTC_CLEANUP_FAILED'));
    expect(permissions, 1);
  });

  testWidgets(
      'late permission grant rechecks cleanup started during the prompt',
      (tester) async {
    final engine = FakeRtcEngine();
    final granted = Completer<bool>(), released = Completer<void>();
    var permissions = 0;
    final media = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () {
          permissions++;
          return permissions == 1 ? Future.value(true) : granted.future;
        },
        cleanupTimeout: const Duration(milliseconds: 40));
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    final preflight = Completion(media.checkPermission());
    await tester.pump();
    expect(permissions, 2);
    engine.pending[#release] = released;
    final leaving = Completion(media.leave());
    try {
      granted.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(leaving.error, failureCode('RTC_CLEANUP_PENDING'));
      expect(preflight.error, failureCode('RTC_CLEANUP_PENDING'));
    } finally {
      if (!granted.isCompleted) granted.complete(false);
      released.complete();
      await tester.pump();
      final cleanup = Completion(media.leave());
      await tester.pump();
      await cleanup.done;
    }
  });

  testWidgets('permission preflight does not tear down a current live engine',
      (tester) async {
    final engine = FakeRtcEngine();
    final media = AgoraCallAudio(
        engineFactory: () => engine, microphonePermission: () async => true);
    final joined =
        Completion(media.join(credentials(), () async => credentials()));
    await tester.pump();
    await joined.done;
    engine.audioConnected();
    final preflight = Completion(media.checkPermission());
    await tester.pump();
    await preflight.done;
    expect(preflight.error, isNull);
    expect(media.ready, isTrue);
    expect(engine.called(#enableLocalAudio), isFalse);
    expect(engine.called(#leaveChannel), isFalse);
    expect(engine.called(#release), isFalse);
    final cleanup = Completion(media.leave());
    await tester.pump();
    await cleanup.done;
  });

  for (final failedStep in [
    #enableLocalAudio,
    #muteLocalAudioStream,
    #leaveChannel,
  ]) {
    testWidgets('rejected $failedStep still reaches final native release',
        (tester) async {
      final engine = FakeRtcEngine();
      final media = AgoraCallAudio(
          engineFactory: () => engine, microphonePermission: () async => true);
      final joined =
          Completion(media.join(credentials(), () async => credentials()));
      await tester.pump();
      await joined.done;
      engine.calls.clear();
      engine.failures.add(failedStep);
      final leaving = Completion(media.leave());
      await tester.pump();
      await leaving.done;
      expect(leaving.error, isNull);
      expect(engine.calls.map((call) => call.method).toList(), [
        #enableLocalAudio,
        #muteLocalAudioStream,
        #leaveChannel,
        #release,
      ]);
      expect(media.ready, isFalse);
    });
  }
}
