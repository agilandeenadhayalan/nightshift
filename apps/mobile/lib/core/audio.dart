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

/// Only SDK callbacks establish readiness. A successful HTTP accept is not audio.
class AgoraCallAudio implements CallAudio {
  RtcEngine? _engine;
  bool _joined = false,
      _connected = false,
      _recording = false,
      _remoteReady = false;
  int _remoteUid = 0;
  @override
  bool muted = false;
  @override
  bool speaker = false;
  @override
  void Function()? onChanged;
  @override
  void Function(String code)? onFailure;
  @override
  bool get ready => _joined && _connected && _recording && _remoteReady;

  @override
  Future<void> checkPermission() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      throw const ApiFailure('MICROPHONE_DENIED',
          'Microphone access is required for a call. Allow it in Android app settings and try again.');
    }
  }

  @override
  Future<void> join(RtcCredentials credentials,
      Future<RtcCredentials> Function() renew) async {
    await leave();
    await checkPermission();
    final engine = createAgoraRtcEngine();
    _engine = engine;
    _remoteUid = credentials.remoteUid;
    await engine.initialize(RtcEngineContext(
      appId: credentials.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
      // Disable SDK file logging: diagnostic UI exposes codes, never tokens/audio.
      logConfig: const LogConfig(level: LogLevel.logLevelNone),
    ));
    if (!identical(_engine, engine)) return;
    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (!identical(_engine, engine)) return;
        _joined = true;
        _connected = true;
        onChanged?.call();
      },
      onRejoinChannelSuccess: (connection, elapsed) {
        if (!identical(_engine, engine)) return;
        _joined = true;
        _connected = true;
        onChanged?.call();
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (!identical(_engine, engine)) return;
        _connected = state == ConnectionStateType.connectionStateConnected;
        if (!_connected) _remoteReady = false;
        onChanged?.call();
        if (state == ConnectionStateType.connectionStateFailed) {
          onFailure?.call('RTC_CONNECTION_FAILED');
        }
      },
      onLocalAudioStateChanged: (connection, state, reason) {
        if (!identical(_engine, engine)) return;
        _recording =
            state == LocalAudioStreamState.localAudioStreamStateRecording ||
                state == LocalAudioStreamState.localAudioStreamStateEncoding;
        onChanged?.call();
        if (state == LocalAudioStreamState.localAudioStreamStateFailed) {
          onFailure?.call('RTC_MICROPHONE_FAILED');
        }
      },
      onRemoteAudioStateChanged: (connection, uid, state, reason, elapsed) {
        if (!identical(_engine, engine)) return;
        if (uid != _remoteUid) return;
        // Intentional mute does not mean a network gap, once media was established.
        if (reason != RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
          _remoteReady = state == RemoteAudioState.remoteAudioStateDecoding;
        }
        onChanged?.call();
      },
      onUserOffline: (connection, uid, reason) {
        if (!identical(_engine, engine)) return;
        if (uid == _remoteUid) {
          _remoteReady = false;
          onChanged?.call();
        }
      },
      onTokenPrivilegeWillExpire: (connection, token) {
        if (!identical(_engine, engine)) return;
        unawaited(() async {
          try {
            final next = await renew();
            if (identical(_engine, engine)) await engine.renewToken(next.token);
          } catch (_) {
            if (identical(_engine, engine)) {
              onFailure?.call('RTC_RENEWAL_FAILED');
            }
          }
        }());
      },
      onRequestToken: (connection) {
        if (!identical(_engine, engine)) return;
        onFailure?.call('RTC_TOKEN_EXPIRED');
      },
      onError: (code, message) {
        if (!identical(_engine, engine)) return;
        onFailure?.call('RTC_${code.value()}');
      },
    ));
    await engine.enableAudio();
    if (!identical(_engine, engine)) return;
    await engine.setDefaultAudioRouteToSpeakerphone(false);
    if (!identical(_engine, engine)) return;
    await engine.joinChannel(
      token: credentials.token,
      channelId: credentials.channel,
      uid: credentials.uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: false,
      ),
    );
  }

  @override
  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    _joined = _connected = _recording = _remoteReady = false;
    muted = speaker = false;
    if (engine != null) {
      try {
        await engine.muteLocalAudioStream(true);
        await engine.leaveChannel();
      } on AgoraRtcException {
        // Partial joins can reject leave; release still tears down native capture.
      } finally {
        await engine.release();
      }
    }
    onChanged?.call();
  }

  @override
  Future<void> toggleMute() async {
    await _engine?.muteLocalAudioStream(!muted);
    muted = !muted;
    onChanged?.call();
  }

  @override
  Future<void> toggleSpeaker() async {
    await _engine?.setEnableSpeakerphone(!speaker);
    speaker = !speaker;
    onChanged?.call();
  }
}
