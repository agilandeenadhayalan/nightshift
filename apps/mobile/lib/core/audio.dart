import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api.dart';
import 'models.dart';

abstract interface class CallAudio {
  bool get ready;
  bool get muted;
  bool get speaker;
  set onChanged(void Function()? callback);
  set onFailure(void Function(String code)? callback);
  Future<void> checkPermission();
  Future<void> join(
      RtcCredentials credentials, Future<RtcCredentials> Function() renew);
  Future<void> leave();
  Future<void> toggleMute();
  Future<void> toggleSpeaker();
}

/// Optional video capability; existing audio-only adapters remain compatible.
abstract interface class CallVideo implements CallAudio {
  bool get previewing;
  bool get cameraEnabled;
  bool get frontCamera;
  bool get videoReady;
  bool get lowBandwidth;
  VideoViewController? get localVideo;
  VideoViewController? get remoteVideo;
  Future<void> startPreview(String appId);
  Future<void> stopPreview();
  Future<void> joinVideo(
      RtcCredentials credentials, Future<RtcCredentials> Function() renew);
  Future<void> setCameraEnabled(bool enabled);
  Future<void> switchCamera();
}

/// Serializes native mutations with final teardown. A pending enable operation
/// cannot finish after release and leave a camera running.
class _OwnedRtcEngine {
  _OwnedRtcEngine(this.engine,
      {required this.video, required this.previewOnly});
  final RtcEngine engine;
  final bool video, previewOnly;
  bool closed = false;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;

  Future<void> run(Future<void> Function() operation) {
    final result = _tail.then((_) async {
      if (!closed) await operation();
    });
    // A failed operation must not prevent final capture shutdown/release.
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> close() {
    final existing = _closing;
    if (existing != null) return existing;
    closed = true;
    return _closing = _tail.then((_) async {
      Future<void> attempt(Future<void> Function() action) async {
        try {
          await action();
        } catch (_) {
          // Partial joins can reject individual calls; always attempt every
          // capture-stop operation and then release the native engine.
        }
      }

      if (video) {
        await attempt(() => engine.enableLocalVideo(false));
        await attempt(engine.stopPreview);
        await attempt(() => engine.muteLocalVideoStream(true));
      }
      await attempt(() => engine.muteLocalAudioStream(true));
      await attempt(engine.leaveChannel);
      await engine.release();
    });
  }
}

/// SDK callbacks establish media readiness; HTTP acceptance is never proof.
class AgoraCallAudio implements CallVideo {
  AgoraCallAudio({
    RtcEngine Function()? engineFactory,
    Future<bool> Function()? microphonePermission,
    Future<bool> Function()? cameraPermission,
  })  : _engineFactory = engineFactory ?? createAgoraRtcEngine,
        _microphonePermission = microphonePermission ??
            (() async => (await Permission.microphone.request()).isGranted),
        _cameraPermission = cameraPermission ??
            (() async => (await Permission.camera.request()).isGranted);

  final RtcEngine Function() _engineFactory;
  final Future<bool> Function() _microphonePermission, _cameraPermission;
  _OwnedRtcEngine? _session;
  Future<void> _releaseBarrier = Future<void>.value();
  int _generation = 0, _cameraRevision = 0;
  bool _previewRequested = false;
  bool _joined = false,
      _connected = false,
      _recording = false,
      _remoteReady = false,
      _localVideoReady = false,
      _remoteVideoReady = false;
  int _remoteUid = 0, _localUid = 0;
  String? _channel;
  VideoViewController? _localView, _remoteView;

  @override
  bool muted = false;
  @override
  bool speaker = false;
  @override
  bool cameraEnabled = false;
  @override
  bool frontCamera = true;
  @override
  bool lowBandwidth = false;
  @override
  void Function()? onChanged;
  @override
  void Function(String code)? onFailure;

  @override
  bool get ready =>
      _session?.previewOnly == false &&
      _joined &&
      _connected &&
      _recording &&
      _remoteReady;
  @override
  bool get previewing =>
      _session?.previewOnly == true && cameraEnabled && _localVideoReady;
  @override
  bool get videoReady =>
      ready &&
      _session?.video == true &&
      cameraEnabled &&
      _localVideoReady &&
      _remoteVideoReady;
  @override
  VideoViewController? get localVideo => cameraEnabled ? _localView : null;
  @override
  VideoViewController? get remoteVideo =>
      _session?.video == true && _session?.previewOnly == false
          ? _remoteView
          : null;

  bool _current(_OwnedRtcEngine session) =>
      identical(_session, session) && !session.closed;

  void _resetState() {
    _joined = _connected = _recording = _remoteReady = false;
    _localVideoReady = _remoteVideoReady = false;
    muted = speaker = cameraEnabled = lowBandwidth = false;
    frontCamera = true;
    _remoteUid = _localUid = 0;
    _channel = null;
    _localView = _remoteView = null;
    _cameraRevision++;
  }

  Future<void> _detach() {
    final old = _session;
    _session = null;
    _resetState();
    if (old != null) {
      final previous = _releaseBarrier;
      final closing = old.close();
      _releaseBarrier = Future.wait([previous, closing]).then((_) {});
    }
    onChanged?.call();
    return _releaseBarrier;
  }

  Future<bool> _run(
      _OwnedRtcEngine session, Future<void> Function() operation) async {
    if (!_current(session)) return false;
    await session.run(operation);
    return _current(session);
  }

  @override
  Future<void> checkPermission() async {
    if (!await _microphonePermission()) {
      throw const ApiFailure('MICROPHONE_DENIED',
          'Microphone access is required for a call. Allow it in Android app settings and try again.');
    }
  }

  Future<void> _checkCameraPermission() async {
    if (!await _cameraPermission()) {
      throw const ApiFailure('CAMERA_DENIED',
          'Camera access is required for video. Allow it in Android app settings and try again.');
    }
  }

  @override
  Future<void> startPreview(String appId) async {
    final generation = ++_generation;
    _previewRequested = true;
    await _detach();
    if (generation != _generation || !_previewRequested) return;
    await _checkCameraPermission();
    if (generation != _generation || !_previewRequested) return;
    final session =
        _OwnedRtcEngine(_engineFactory(), video: true, previewOnly: true);
    _session = session;
    try {
      if (!await _initialize(session, appId)) return;
      // Local preview must not acquire the microphone or join any channel.
      if (!await _run(session, session.engine.disableAudio)) return;
      if (!await _run(
          session,
          () => session.engine
              .setVideoEncoderConfiguration(_videoConfig(false)))) {
        return;
      }
      cameraEnabled = true;
      if (!await _run(session, session.engine.enableVideo)) return;
      if (!await _run(session, session.engine.startPreview)) return;
      onChanged?.call();
    } catch (_) {
      if (_current(session)) await leave();
      rethrow;
    }
  }

  @override
  Future<void> stopPreview() async {
    // A dismissed preflight must not tear down a later joined call engine.
    if (!_previewRequested && _session?.previewOnly != true) return;
    _previewRequested = false;
    _generation++;
    await _detach();
  }

  @override
  Future<void> join(RtcCredentials credentials,
          Future<RtcCredentials> Function() renew) =>
      _join(credentials, renew, video: false);

  @override
  Future<void> joinVideo(RtcCredentials credentials,
          Future<RtcCredentials> Function() renew) =>
      _join(credentials, renew, video: true);

  Future<void> _join(
      RtcCredentials credentials, Future<RtcCredentials> Function() renew,
      {required bool video}) async {
    final generation = ++_generation;
    _previewRequested = false;
    await _detach();
    if (generation != _generation) return;
    await checkPermission();
    if (generation != _generation) return;
    if (video) {
      await _checkCameraPermission();
      if (generation != _generation) return;
    }
    final session =
        _OwnedRtcEngine(_engineFactory(), video: video, previewOnly: false);
    _session = session;
    _remoteUid = credentials.remoteUid;
    _localUid = credentials.uid;
    _channel = credentials.channel;
    try {
      if (!await _initialize(session, credentials.appId, renew: renew)) return;
      if (!await _run(session, session.engine.enableAudio)) return;
      if (!await _run(session,
          () => session.engine.setDefaultAudioRouteToSpeakerphone(video))) {
        return;
      }
      speaker = video;
      if (video) {
        if (!await _run(
            session,
            () => session.engine
                .setVideoEncoderConfiguration(_videoConfig(false)))) {
          return;
        }
        cameraEnabled = true;
        if (!await _run(session, session.engine.enableVideo)) return;
        if (!await _run(session, session.engine.startPreview)) return;
      }
      if (!await _run(
          session,
          () => session.engine.joinChannel(
              token: credentials.token,
              channelId: credentials.channel,
              uid: credentials.uid,
              options: ChannelMediaOptions(
                channelProfile: ChannelProfileType.channelProfileCommunication,
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishMicrophoneTrack: true,
                publishCameraTrack: video,
                autoSubscribeAudio: true,
                autoSubscribeVideo: video,
              )))) {
        return;
      }
      onChanged?.call();
    } catch (_) {
      if (_current(session)) await leave();
      rethrow;
    }
  }

  Future<bool> _initialize(_OwnedRtcEngine session, String appId,
      {Future<RtcCredentials> Function()? renew}) async {
    if (!await _run(
        session,
        () => session.engine.initialize(RtcEngineContext(
            appId: appId,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            // No SDK file logging, recorded media or token-bearing diagnostics.
            logConfig: const LogConfig(level: LogLevel.logLevelNone))))) {
      return false;
    }
    if (session.video) {
      _localView = VideoViewController(
          rtcEngine: session.engine, canvas: const VideoCanvas(uid: 0));
      if (!session.previewOnly) {
        _remoteView = VideoViewController.remote(
            rtcEngine: session.engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection:
                RtcConnection(channelId: _channel, localUid: _localUid));
      }
    }
    session.engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (!_current(session) || session.previewOnly) return;
        _joined = _connected = true;
        onChanged?.call();
      },
      onRejoinChannelSuccess: (connection, elapsed) {
        if (!_current(session) || session.previewOnly) return;
        _joined = _connected = true;
        onChanged?.call();
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (!_current(session) || session.previewOnly) return;
        _connected = state == ConnectionStateType.connectionStateConnected;
        if (!_connected) {
          _remoteReady = _remoteVideoReady = false;
        }
        onChanged?.call();
        if (state == ConnectionStateType.connectionStateFailed) {
          onFailure?.call('RTC_CONNECTION_FAILED');
        }
      },
      onLocalAudioStateChanged: (connection, state, reason) {
        if (!_current(session) || session.previewOnly) return;
        _recording =
            state == LocalAudioStreamState.localAudioStreamStateRecording ||
                state == LocalAudioStreamState.localAudioStreamStateEncoding;
        onChanged?.call();
        if (state == LocalAudioStreamState.localAudioStreamStateFailed) {
          onFailure?.call('RTC_MICROPHONE_FAILED');
        }
      },
      onRemoteAudioStateChanged: (connection, uid, state, reason, elapsed) {
        if (!_current(session) || session.previewOnly || uid != _remoteUid) {
          return;
        }
        // Intentional audio mute preserves previously established media readiness.
        if (reason != RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
          _remoteReady = state == RemoteAudioState.remoteAudioStateDecoding;
        }
        onChanged?.call();
      },
      onLocalVideoStateChanged: (source, state, reason) {
        if (!_current(session) ||
            !session.video ||
            source != VideoSourceType.videoSourceCameraPrimary) {
          return;
        }
        _localVideoReady = cameraEnabled &&
            (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
                state == LocalVideoStreamState.localVideoStreamStateEncoding);
        onChanged?.call();
        if (state == LocalVideoStreamState.localVideoStreamStateFailed) {
          _cameraFailed(session);
        }
      },
      onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) {
        if (!_current(session) ||
            !session.video ||
            session.previewOnly ||
            uid != _remoteUid) {
          return;
        }
        // Unlike intentional audio mute, a missing camera pauses video charging.
        _remoteVideoReady = state == RemoteVideoState.remoteVideoStateDecoding;
        onChanged?.call();
      },
      onUserOffline: (connection, uid, reason) {
        if (!_current(session)) return;
        if (uid == _remoteUid) {
          _remoteReady = _remoteVideoReady = false;
          onChanged?.call();
        }
      },
      onNetworkQuality: (connection, uid, txQuality, rxQuality) {
        if (!_current(session) ||
            !session.video ||
            session.previewOnly ||
            (uid != 0 && uid != _localUid)) {
          return;
        }
        const bad = {
          QualityType.qualityBad,
          QualityType.qualityVbad,
          QualityType.qualityDown
        };
        const good = {QualityType.qualityExcellent, QualityType.qualityGood};
        if (bad.contains(txQuality) || bad.contains(rxQuality)) {
          unawaited(_adaptQuality(session, true));
        } else if (good.contains(txQuality) && good.contains(rxQuality)) {
          unawaited(_adaptQuality(session, false));
        }
      },
      onTokenPrivilegeWillExpire: (connection, token) {
        if (!_current(session) || renew == null) return;
        unawaited(() async {
          try {
            final next = await renew();
            if (_current(session)) {
              await _run(session, () => session.engine.renewToken(next.token));
            }
          } catch (_) {
            if (_current(session)) onFailure?.call('RTC_RENEWAL_FAILED');
          }
        }());
      },
      onRequestToken: (connection) {
        if (_current(session) && !session.previewOnly) {
          onFailure?.call('RTC_TOKEN_EXPIRED');
        }
      },
      onError: (code, message) {
        if (!_current(session)) return;
        if (session.previewOnly) {
          _cameraFailed(session);
        } else {
          onFailure?.call('RTC_${code.value()}');
        }
      },
    ));
    return _current(session);
  }

  void _cameraFailed(_OwnedRtcEngine session) {
    if (!_current(session)) return;
    cameraEnabled = _localVideoReady = false;
    onChanged?.call();
    onFailure?.call('RTC_CAMERA_FAILED');
    if (session.previewOnly) {
      // Preview may have no active call controller to perform failure cleanup.
      unawaited(leave().catchError((Object _) {}));
    }
  }

  VideoEncoderConfiguration _videoConfig(bool low) => VideoEncoderConfiguration(
      dimensions:
          VideoDimensions(width: low ? 320 : 640, height: low ? 180 : 360),
      frameRate: low ? 10 : 15,
      orientationMode: OrientationMode.orientationModeAdaptive,
      degradationPreference: DegradationPreference.maintainBalanced);

  Future<void> _adaptQuality(_OwnedRtcEngine session, bool low) async {
    if (!_current(session) || lowBandwidth == low) return;
    lowBandwidth = low;
    onChanged?.call();
    try {
      await _run(session,
          () => session.engine.setVideoEncoderConfiguration(_videoConfig(low)));
    } catch (_) {
      if (_current(session)) onFailure?.call('RTC_VIDEO_QUALITY_FAILED');
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final session = _session;
    if (session == null || !session.video || session.closed) return;
    final revision = ++_cameraRevision;
    bool current() => _current(session) && revision == _cameraRevision;
    if (!enabled) {
      cameraEnabled = _localVideoReady = false;
      onChanged?.call();
    }
    try {
      if (enabled) {
        await _checkCameraPermission();
        if (!current()) return;
        // A late capture callback while the camera was off cannot establish
        // readiness for this fresh activation.
        _localVideoReady = false;
        cameraEnabled = true;
        onChanged?.call();
      }
      if (!await _run(session, () async {
            if (current()) await session.engine.enableLocalVideo(enabled);
          }) ||
          !current()) {
        return;
      }
      if (!enabled) {
        if (!await _run(session, session.engine.stopPreview) || !current()) {
          return;
        }
        if (!session.previewOnly) {
          await _run(
              session,
              () => session.engine.updateChannelMediaOptions(
                  const ChannelMediaOptions(publishCameraTrack: false)));
        }
      } else {
        if (!session.previewOnly) {
          if (!await _run(
                  session,
                  () => session.engine.updateChannelMediaOptions(
                      const ChannelMediaOptions(publishCameraTrack: true))) ||
              !current()) {
            return;
          }
        }
        if (!await _run(session, session.engine.startPreview) || !current()) {
          return;
        }
        cameraEnabled = true;
      }
      if (current()) onChanged?.call();
    } catch (_) {
      // A failed camera-off request must release the engine, not merely hide UI.
      if (_current(session)) await leave();
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    final session = _session;
    if (session == null || !session.video || !cameraEnabled) return;
    if (await _run(session, session.engine.switchCamera)) {
      frontCamera = !frontCamera;
      onChanged?.call();
    }
  }

  @override
  Future<void> leave() async {
    _generation++;
    _previewRequested = false;
    await _detach();
  }

  @override
  Future<void> toggleMute() async {
    final session = _session;
    if (session == null || session.previewOnly) return;
    final next = !muted;
    if (await _run(session, () => session.engine.muteLocalAudioStream(next))) {
      muted = next;
      onChanged?.call();
    }
  }

  @override
  Future<void> toggleSpeaker() async {
    final session = _session;
    if (session == null || session.previewOnly) return;
    final next = !speaker;
    if (await _run(session, () => session.engine.setEnableSpeakerphone(next))) {
      speaker = next;
      onChanged?.call();
    }
  }
}
