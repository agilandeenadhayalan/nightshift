import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightshift/core/api.dart';
import 'package:nightshift/core/audio.dart';
import 'package:nightshift/core/models.dart';

class SdkCall {
  SdkCall(this.method, this.arguments, this.named);
  final Symbol method;
  final List<dynamic> arguments;
  final Map<Symbol, dynamic> named;
}

class FakeRtcEngine implements RtcEngine {
  final List<SdkCall> calls = [];
  final Map<Symbol, Completer<void>> pending = {};
  final Set<Symbol> failures = {};
  RtcEngineEventHandler? handler;

  bool called(Symbol method) => calls.any((call) => call.method == method);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(SdkCall(invocation.memberName, invocation.positionalArguments,
        invocation.namedArguments));
    if (invocation.memberName == #registerEventHandler) {
      handler = invocation.positionalArguments.single as RtcEngineEventHandler;
      return null;
    }
    if (failures.contains(invocation.memberName)) {
      return Future<void>.error(StateError('Synthetic SDK failure'));
    }
    return pending[invocation.memberName]?.future ?? Future<void>.value();
  }

  void audioConnected() {
    const connection = RtcConnection(channelId: 'test-channel', localUid: 1);
    handler!.onJoinChannelSuccess!(connection, 0);
    handler!.onLocalAudioStateChanged!(
        connection,
        LocalAudioStreamState.localAudioStreamStateRecording,
        LocalAudioStreamReason.localAudioStreamReasonOk);
    handler!.onRemoteAudioStateChanged!(
        connection,
        2,
        RemoteAudioState.remoteAudioStateDecoding,
        RemoteAudioStateReason.remoteAudioReasonNetworkRecovery,
        0);
  }

  void videoCaptured() => handler!.onLocalVideoStateChanged!(
      VideoSourceType.videoSourceCameraPrimary,
      LocalVideoStreamState.localVideoStreamStateCapturing,
      LocalVideoStreamReason.localVideoStreamReasonOk);

  void videoReceived([int uid = 2]) => handler!.onRemoteVideoStateChanged!(
      const RtcConnection(channelId: 'test-channel', localUid: 1),
      uid,
      RemoteVideoState.remoteVideoStateDecoding,
      RemoteVideoStateReason.remoteVideoStateReasonNetworkRecovery,
      0);
}

RtcCredentials credentials() => RtcCredentials.fromJson({
      'appId': 'test-app',
      'channel': 'test-channel',
      'token': 'synthetic-rtc-token',
      'uid': 1,
      'remoteUid': 2,
      'mediaType': 'video',
    });

Future<void> flush() async {
  for (var iteration = 0; iteration < 12; iteration++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeRtcEngine engine;
  late AgoraCallAudio media;
  late int microphoneRequests, cameraRequests;
  setUp(() {
    engine = FakeRtcEngine();
    microphoneRequests = cameraRequests = 0;
    media = AgoraCallAudio(
        engineFactory: () => engine,
        microphonePermission: () async {
          microphoneRequests++;
          return true;
        },
        cameraPermission: () async {
          cameraRequests++;
          return true;
        });
  });
  tearDown(() => media.leave());

  test('preview captures camera only and requires an actual capture callback',
      () async {
    await media.startPreview('test-app');
    expect(cameraRequests, 1);
    expect(microphoneRequests, 0);
    expect(engine.called(#disableAudio), isTrue);
    expect(engine.called(#enableAudio), isFalse);
    expect(engine.called(#joinChannel), isFalse);
    expect(media.previewing, isFalse);
    expect(media.localVideo, isNotNull);
    expect(media.remoteVideo, isNull);
    engine.videoCaptured();
    expect(media.previewing, isTrue);
    expect(media.ready, isFalse);
    expect(media.videoReady, isFalse);
    await media.stopPreview();
    expect(engine.called(#stopPreview), isTrue);
    expect(engine.called(#release), isTrue);
    expect(media.localVideo, isNull);
    expect(media.previewing, isFalse);
  });

  test('denied camera never creates or enables an engine', () async {
    var creations = 0;
    media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () async => true,
        cameraPermission: () async => false);
    await expectLater(
        media.startPreview('test-app'),
        throwsA(
            isA<ApiFailure>().having((e) => e.code, 'code', 'CAMERA_DENIED')));
    expect(creations, 0);
    expect(media.previewing, isFalse);
  });

  test('closing preview during permission prompt prevents late camera creation',
      () async {
    final permission = Completer<bool>();
    var creations = 0;
    media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () async => true,
        cameraPermission: () => permission.future);
    final starting = media.startPreview('test-app');
    await flush();
    await media.stopPreview();
    permission.complete(true);
    await starting;
    expect(creations, 0);
    expect(media.localVideo, isNull);
  });

  test('ending a join during permission prompt prevents late media activation',
      () async {
    final permission = Completer<bool>();
    var creations = 0;
    media = AgoraCallAudio(
        engineFactory: () {
          creations++;
          return engine;
        },
        microphonePermission: () => permission.future,
        cameraPermission: () async => true);
    final joining = media.joinVideo(credentials(), () async => credentials());
    await flush();
    await media.leave();
    permission.complete(true);
    await joining;
    expect(creations, 0);
    expect(engine.called(#joinChannel), isFalse);
  });

  test('late initialization cannot enable a cancelled preview', () async {
    final initialized = Completer<void>();
    engine.pending[#initialize] = initialized;
    final starting = media.startPreview('test-app');
    await flush();
    final closing = media.stopPreview();
    initialized.complete();
    await Future.wait([starting, closing]);
    expect(engine.called(#enableVideo), isFalse);
    expect(engine.called(#startPreview), isFalse);
    expect(engine.called(#release), isTrue);
  });

  test('late preview disposal does not stop a video call engine', () async {
    final joinedEngine = FakeRtcEngine();
    final engines = [engine, joinedEngine];
    media = AgoraCallAudio(
        engineFactory: () => engines.removeAt(0),
        microphonePermission: () async => true,
        cameraPermission: () async => true);
    await media.startPreview('test-app');
    await media.joinVideo(credentials(), () async => credentials());
    await media.stopPreview();
    expect(joinedEngine.called(#release), isFalse);
    expect(joinedEngine.called(#joinChannel), isTrue);
    expect(engine.called(#release), isTrue);
    expect(engine.called(#joinChannel), isFalse);
    joinedEngine.audioConnected();
    joinedEngine.videoCaptured();
    joinedEngine.videoReceived();
    expect(media.videoReady, isTrue);
    engine.handler!.onLocalVideoStateChanged!(
        VideoSourceType.videoSourceCameraPrimary,
        LocalVideoStreamState.localVideoStreamStateStopped,
        LocalVideoStreamReason.localVideoStreamReasonOk);
    expect(media.videoReady, isTrue);
  });

  test('video readiness requires both actual media directions and expected UID',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    engine.audioConnected();
    expect(media.ready, isTrue);
    expect(media.videoReady, isFalse);
    engine.videoCaptured();
    engine.videoReceived(99);
    expect(media.videoReady, isFalse);
    engine.videoReceived();
    expect(media.videoReady, isTrue);
    await media.setCameraEnabled(false);
    expect(media.cameraEnabled, isFalse);
    expect(media.videoReady, isFalse);
    expect(
        engine.calls.any((call) =>
            call.method == #enableLocalVideo && call.arguments.single == false),
        isTrue);
    expect(engine.called(#stopPreview), isTrue);
    expect(media.localVideo, isNull);
  });

  test('end waits for in-flight camera activation and then stops capture',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    await media.setCameraEnabled(false);
    final enabled = Completer<void>();
    engine.pending[#enableLocalVideo] = enabled;
    final enabling = media.setCameraEnabled(true);
    await flush();
    final end = media.leave();
    expect(media.videoReady, isFalse);
    enabled.complete();
    await Future.wait([enabling, end]);
    final releaseIndex =
        engine.calls.lastIndexWhere((c) => c.method == #release);
    final captureOffIndex = engine.calls.lastIndexWhere(
        (c) => c.method == #enableLocalVideo && c.arguments.single == false);
    expect(captureOffIndex, greaterThan(0));
    expect(releaseIndex, greaterThan(captureOffIndex));
    expect(media.cameraEnabled, isFalse);
    expect(media.localVideo, isNull);
  });

  test('camera re-enable waits for a fresh capture callback', () async {
    await media.joinVideo(credentials(), () async => credentials());
    engine.audioConnected();
    engine.videoCaptured();
    engine.videoReceived();
    expect(media.videoReady, isTrue);
    await media.setCameraEnabled(false);
    engine.videoCaptured();
    expect(media.videoReady, isFalse);
    await media.setCameraEnabled(true);
    expect(media.videoReady, isFalse);
    engine.videoCaptured();
    expect(media.videoReady, isTrue);
    final publishing = engine.calls
        .lastWhere((call) => call.method == #updateChannelMediaOptions);
    expect(
        (publishing.arguments.single as ChannelMediaOptions).publishCameraTrack,
        isTrue);
  });

  test('failed camera-off releases the engine instead of only hiding the view',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    engine.failures.add(#enableLocalVideo);
    await expectLater(media.setCameraEnabled(false), throwsStateError);
    expect(engine.called(#release), isTrue);
    expect(media.cameraEnabled, isFalse);
    expect(media.localVideo, isNull);
    expect(media.remoteVideo, isNull);
  });

  test(
      'camera switching invokes the SDK and ignores an ended engine completion',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    await media.switchCamera();
    expect(media.frontCamera, isFalse);
    final switched = Completer<void>();
    engine.pending[#switchCamera] = switched;
    final switching = media.switchCamera();
    await flush();
    final leaving = media.leave();
    switched.complete();
    await Future.wait([switching, leaving]);
    expect(media.frontCamera, isTrue);
    expect(media.cameraEnabled, isFalse);
    expect(engine.called(#release), isTrue);
  });

  test('teardown still releases engine when stopping one track fails',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    engine.failures.add(#muteLocalAudioStream);
    await media.leave();
    expect(
        engine.calls.any((call) =>
            call.method == #enableLocalVideo && call.arguments.single == false),
        isTrue);
    expect(engine.called(#stopPreview), isTrue);
    expect(engine.called(#leaveChannel), isTrue);
    expect(engine.called(#release), isTrue);
  });

  test('poor network reduces encoding quality without changing media type',
      () async {
    await media.joinVideo(credentials(), () async => credentials());
    engine.handler!.onNetworkQuality!(const RtcConnection(), 0,
        QualityType.qualityBad, QualityType.qualityPoor);
    await flush();
    expect(media.lowBandwidth, isTrue);
    final config = engine.calls
        .lastWhere((call) => call.method == #setVideoEncoderConfiguration)
        .arguments
        .single as VideoEncoderConfiguration;
    expect(config.dimensions!.width, 320);
    expect(config.dimensions!.height, 180);
    expect(config.frameRate, 10);
    expect(config.orientationMode, OrientationMode.orientationModeAdaptive);
    expect(
        config.degradationPreference, DegradationPreference.maintainBalanced);
    expect(engine.called(#disableVideo), isFalse);
    expect(media.cameraEnabled, isTrue);
  });

  test('audio calls never request camera or enable video', () async {
    await media.join(credentials(), () async => credentials());
    expect(microphoneRequests, 1);
    expect(cameraRequests, 0);
    expect(engine.called(#enableVideo), isFalse);
    final options = engine.calls
        .singleWhere((c) => c.method == #joinChannel)
        .named[#options] as ChannelMediaOptions;
    expect(options.publishCameraTrack, isFalse);
    expect(options.autoSubscribeVideo, isFalse);
    expect(media.localVideo, isNull);
    expect(media.remoteVideo, isNull);
    expect(media.speaker, isFalse);
  });
}
