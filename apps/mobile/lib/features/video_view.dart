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
      this.aspectRatio = 16 / 9});
  final VideoViewController? controller;
  final String label, placeholder;
  final String? avatarCode;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      image: controller != null,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                  color: NsColors.card,
                  child: Stack(fit: StackFit.expand, children: [
                    if (controller != null)
                      AgoraVideoView(
                          key: ObjectKey(controller), controller: controller!)
                    else
                      Stack(fit: StackFit.expand, children: [
                        if (avatarAssetPath(avatarCode) case final asset?)
                          Opacity(
                              opacity: .35,
                              child: AvatarPortrait(
                                  assetPath: asset,
                                  borderRadius: BorderRadius.zero))
                        else
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                Color(0xFF263855),
                                Color(0xFF141627)
                              ]))),
                        Center(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.videocam_off_outlined,
                                          color: NsColors.cyan, size: 38),
                                      const SizedBox(height: 8),
                                      Flexible(
                                          child: Text(placeholder,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.white))),
                                    ]))),
                      ]),
                    Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color:
                                    NsColors.background.withValues(alpha: .8),
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(24)),
                            child: Text(label,
                                style: const TextStyle(color: Colors.white)))),
                  ])))));
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
      this.localAvatarCode});
  final CallVideo video;
  final String remoteLabel, localLabel, waitingLabel, cameraOffLabel;
  final String? remoteAvatarCode, localAvatarCode;

  @override
  Widget build(BuildContext context) => Stack(children: [
        VideoCameraPane(
            aspectRatio: 3 / 4,
            controller: video.remoteVideo,
            avatarCode: remoteAvatarCode,
            label: remoteLabel,
            placeholder: waitingLabel),
        Positioned(
            right: 12,
            top: 52,
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
