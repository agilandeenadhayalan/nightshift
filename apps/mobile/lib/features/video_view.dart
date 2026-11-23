import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../core/audio.dart';
import 'redesign/design_system.dart';

double _fullBleedVideoInset(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
  return MediaQuery.paddingOf(context).top +
      100 +
      (scale - 1).clamp(0, 2) * 140;
}

/// Only an explicitly prepared/joined adapter supplies native view controllers.
class VideoCameraPane extends StatelessWidget {
  const VideoCameraPane(
      {super.key,
      required this.controller,
      required this.label,
      required this.placeholder,
      this.avatarCode,
      this.aspectRatio = 16 / 9,
      this.expand = false});
  final VideoViewController? controller;
  final String label, placeholder;
  final String? avatarCode;
  final double aspectRatio;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
    return Semantics(
        label: label,
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
            Align(
                alignment: expand ? Alignment.topLeft : Alignment.center,
                child: Padding(
                    padding: expand
                        ? EdgeInsets.only(
                            left: 22, top: _fullBleedVideoInset(context) + 12)
                        : const EdgeInsets.all(16),
                    child: SizedBox(
                        width: expand
                            ? (MediaQuery.sizeOf(context).width - 190)
                                .clamp(100, 220)
                            : null,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.videocam_off_outlined,
                              color: NsColors.cyan, size: 38),
                          const SizedBox(height: 8),
                          Flexible(
                              child: Text(placeholder,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white))),
                        ])))),
          ]),
        if (label.isNotEmpty)
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
      this.fullBleed = false});
  final CallVideo video;
  final String remoteLabel, localLabel, waitingLabel, cameraOffLabel;
  final String? remoteAvatarCode, localAvatarCode;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: fullBleed ? StackFit.expand : StackFit.loose, children: [
        VideoCameraPane(
            aspectRatio: 3 / 4,
            expand: fullBleed,
            controller: video.remoteVideo,
            avatarCode: remoteAvatarCode,
            label: fullBleed ? '' : remoteLabel,
            placeholder: waitingLabel),
        Positioned(
            right: fullBleed ? 22 : 12,
            top: fullBleed ? _fullBleedVideoInset(context) : 52,
            child: Container(
                width:
                    MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 120 : 100,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white70, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 20)
                    ]),
                child: VideoCameraPane(
                    aspectRatio: 3 / 4,
                    controller: video.cameraEnabled ? video.localVideo : null,
                    avatarCode: localAvatarCode,
                    label: localLabel,
                    placeholder:
                        video.cameraEnabled ? waitingLabel : cameraOffLabel))),
      ]);
}
