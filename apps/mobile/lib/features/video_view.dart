import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../core/audio.dart';
import 'redesign/design_system.dart';

/// Only an explicitly prepared/joined adapter supplies native view controllers.
class VideoCameraPane extends StatelessWidget {
  const VideoCameraPane(
      {super.key,
      required this.controller,
      required this.label,
      required this.placeholder,
      this.avatarCode,
      this.aspectRatio = 16 / 9,
      this.expand = false,
      this.compact = false,
      this.showPlaceholder = true});
  final VideoViewController? controller;
  final String label, placeholder;
  final String? avatarCode;
  final double aspectRatio;
  final bool expand, compact, showPlaceholder;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    return Semantics(
        label: controller == null ? '$label · $placeholder' : label,
        image: controller != null,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(expand ? 0 : 26),
            child: expand
                ? content
                : AspectRatio(aspectRatio: aspectRatio, child: content)));
  }

  Widget _content(BuildContext context) => ColoredBox(
      color: NsColors.card,
      child: Stack(fit: StackFit.expand, children: [
        if (controller != null)
          AgoraVideoView(key: ObjectKey(controller), controller: controller!)
        else
          Stack(fit: StackFit.expand, children: [
            if (avatarAssetPath(avatarCode) case final asset?)
              Opacity(
                  opacity: .35,
                  child: AvatarPortrait(
                      assetPath: asset, borderRadius: BorderRadius.zero))
            else
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF263855), Color(0xFF141627)]))),
            if (showPlaceholder)
              Align(
                  alignment: Alignment.center,
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.videocam_off_outlined,
                            color: Colors.white, size: compact ? 26 : 38),
                        if (!compact) ...[
                          const SizedBox(height: 8),
                          Flexible(
                              child: Text(placeholder,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white))),
                        ],
                      ])))),
          ]),
        if (label.isNotEmpty && !compact)
          Align(
              alignment: Alignment.topLeft,
              child: Container(
                  margin: const EdgeInsets.all(8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: NsColors.background.withValues(alpha: .8),
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(24)),
                  child: Text(label,
                      style: const TextStyle(color: Colors.white)))),
      ]));
}

class VideoCallView extends StatelessWidget {
  const VideoCallView(
      {super.key,
      required this.video,
      required this.remoteLabel,
      required this.localLabel,
      required this.waitingLabel,
      required this.cameraOffLabel,
      this.remoteAvatarCode,
      this.localAvatarCode,
      this.fullBleed = false,
      this.showLocalPreview = true,
      this.showWaitingIndicator = true});
  final CallVideo video;
  final String remoteLabel, localLabel, waitingLabel, cameraOffLabel;
  final String? remoteAvatarCode, localAvatarCode;
  final bool fullBleed, showLocalPreview, showWaitingIndicator;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: fullBleed ? StackFit.expand : StackFit.loose, children: [
        VideoCameraPane(
            aspectRatio: 3 / 4,
            expand: fullBleed,
            showPlaceholder: showWaitingIndicator,
            controller: video.remoteVideo,
            avatarCode: remoteAvatarCode,
            label: fullBleed ? '' : remoteLabel,
            placeholder: waitingLabel),
        if (showLocalPreview)
          Positioned(
              right: fullBleed ? 22 : 12,
              top: fullBleed ? 100 : 52,
              child: VideoLocalPreview(
                  video: video,
                  avatarCode: localAvatarCode,
                  label: localLabel,
                  waitingLabel: waitingLabel,
                  cameraOffLabel: cameraOffLabel)),
      ]);
}

/// Compact visual status; the full state remains available to accessibility.
class VideoLocalPreview extends StatelessWidget {
  const VideoLocalPreview(
      {super.key,
      required this.video,
      this.avatarCode,
      required this.label,
      required this.waitingLabel,
      required this.cameraOffLabel});
  final CallVideo video;
  final String? avatarCode;
  final String label, waitingLabel, cameraOffLabel;
  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('call-local-preview'),
      width: 76,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white54),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18)]),
      child: VideoCameraPane(
          aspectRatio: 3 / 4,
          compact: true,
          controller: video.cameraEnabled ? video.localVideo : null,
          avatarCode: avatarCode,
          label: label,
          placeholder: video.cameraEnabled ? waitingLabel : cameraOffLabel));
}
