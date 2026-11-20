import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../core/audio.dart';

/// Only an explicitly prepared/joined adapter supplies native view controllers.
class VideoCameraPane extends StatelessWidget {
  const VideoCameraPane(
      {super.key,
      required this.controller,
      required this.label,
      required this.placeholder,
      this.aspectRatio = 16 / 9});
  final VideoViewController? controller;
  final String label, placeholder;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      image: controller != null,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                  color: const Color(0xFF163B35),
                  child: Stack(fit: StackFit.expand, children: [
                    if (controller != null)
                      AgoraVideoView(
                          key: ObjectKey(controller), controller: controller!)
                    else
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off_outlined,
                                        color: Colors.white, size: 32),
                                    const SizedBox(height: 8),
                                    Flexible(
                                        child: Text(placeholder,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white))),
                                  ]))),
                    Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6)),
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
      required this.cameraOffLabel});
  final CallVideo video;
  final String remoteLabel, localLabel, waitingLabel, cameraOffLabel;

  @override
  Widget build(BuildContext context) => Column(children: [
        VideoCameraPane(
            controller: video.remoteVideo,
            label: remoteLabel,
            placeholder: waitingLabel),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: VideoCameraPane(
                    controller: video.cameraEnabled ? video.localVideo : null,
                    label: localLabel,
                    placeholder:
                        video.cameraEnabled ? waitingLabel : cameraOffLabel))),
      ]);
}
