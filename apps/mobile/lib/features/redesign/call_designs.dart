import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design_system.dart';

/// Presentation state for the supplied call designs. It deliberately has no
/// RTC, wallet or API dependency; live calls remain owned by AppController.
class CallDesignState {
  const CallDesignState({
    this.rating = 0,
    this.tags = const {},
    this.muted = false,
    this.speaker = true,
    this.camera = true,
    this.ended = false,
    this.dice = 1,
    this.moves = 0,
    this.invitationAccepted = false,
    this.ratingSelected = false,
  });
  final int rating, dice, moves;
  final Set<String> tags;
  final bool muted, speaker, camera, ended;
  final bool invitationAccepted, ratingSelected;

  CallDesignState copyWith({
    int? rating,
    Set<String>? tags,
    bool? muted,
    bool? speaker,
    bool? camera,
    bool? ended,
    int? dice,
    int? moves,
    bool? invitationAccepted,
    bool? ratingSelected,
  }) =>
      CallDesignState(
        rating: rating ?? this.rating,
        tags: tags ?? this.tags,
        muted: muted ?? this.muted,
        speaker: speaker ?? this.speaker,
        camera: camera ?? this.camera,
        ended: ended ?? this.ended,
        dice: dice ?? this.dice,
        moves: moves ?? this.moves,
        invitationAccepted: invitationAccepted ?? this.invitationAccepted,
        ratingSelected: ratingSelected ?? this.ratingSelected,
      );
}

class CallDesignController extends StateNotifier<CallDesignState> {
  CallDesignController() : super(const CallDesignState());
  void rate(int value) {
    if (value < 1 || value > 5) return;
    state = state.copyWith(rating: value, ratingSelected: false);
  }

  void toggleTag(String tag) => state = state.copyWith(
      tags: Set.unmodifiable(state.tags.contains(tag)
          ? (state.tags.toSet()..remove(tag))
          : {...state.tags, tag}),
      ratingSelected: false);
  void toggleMute() => state = state.copyWith(muted: !state.muted);
  void toggleSpeaker() => state = state.copyWith(speaker: !state.speaker);
  void toggleCamera() => state = state.copyWith(camera: !state.camera);
  void endPreview() => state = state.copyWith(ended: true);
  void acceptInvitation() => state = state.copyWith(invitationAccepted: true);
  void selectRating() {
    if (state.rating > 0) state = state.copyWith(ratingSelected: true);
  }

  // A reproducible local board interaction, not a remote turn or cash game.
  void rollPreviewDice() => state = state.copyWith(
      dice: state.dice % 6 + 1, moves: state.moves + state.dice % 6 + 1);
}

final callDesignProvider = StateNotifierProvider.autoDispose
    .family<CallDesignController, CallDesignState, int>(
        (ref, designId) => CallDesignController());

class CallDesignScreen extends ConsumerWidget {
  const CallDesignScreen(
      {super.key, required this.designId, this.preview = true});
  final int designId;
  final bool preview;

  static const designIds = <int>{
    18,
    33,
    36,
    37,
    38,
    40,
    46,
    48,
    49,
    50,
    51,
    52,
    54
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callDesignProvider(designId));
    final controller = ref.read(callDesignProvider(designId).notifier);
    final listener = {38, 40, 46, 48, 49}.contains(designId);
    final game = {33, 40, 51}.contains(designId) ||
        (designId == 49 && state.invitationAccepted);
    final video = {33, 36, 38, 40, 46, 51, 52}.contains(designId);
    final connecting = designId == 37 || designId == 54;
    return Scaffold(
      backgroundColor: NsColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const NightshiftBrand(size: 23),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _DesignPill(
                icon: listener ? Icons.diamond_outlined : Icons.toll,
                text: '—',
                color: listener ? NsColors.cyan : NsColors.gold),
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              children: [
                _PreviewNotice(
                    message: preview
                        ? 'Design preview · no live call or payment'
                        : 'This call layout is not connected to a live session'),
                const SizedBox(height: 22),
                if (state.ended)
                  _EndedPreview(onBack: () => Navigator.maybePop(context))
                else if (designId == 18)
                  _RatingDesign(state: state, controller: controller)
                else ...[
                  if (connecting)
                    const _ConnectingDesign()
                  else if (game) ...[
                    Row(children: [
                      const NightshiftAvatar(
                          name: 'Listener', size: 42, listener: true),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('Ludo together',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                      const _DesignPill(
                          icon: Icons.sports_esports_outlined,
                          text: 'Local',
                          color: NsColors.cyan),
                    ]),
                    const SizedBox(height: 18),
                    if (video && designId == 51) ...[
                      _VideoDesign(
                          camera: state.camera,
                          hiddenFace: false,
                          faceBox: false,
                          compact: true),
                      const SizedBox(height: 18),
                    ],
                    _LudoDesign(state: state, controller: controller),
                  ] else if (video)
                    _VideoDesign(
                        camera: state.camera,
                        hiddenFace: designId == 38,
                        faceBox: designId == 36,
                        compact: false)
                  else
                    _AudioDesign(listener: listener),
                  if (!connecting) ...[
                    const SizedBox(height: 20),
                    const Text('— : —',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(
                        listener
                            ? 'Test earnings appear only during a real call'
                            : 'Connected time appears only during a real call',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 12)),
                  ],
                  if (designId == 37) ...[
                    const SizedBox(height: 22),
                    NightshiftSurface(
                      child: Column(children: [
                        const Icon(Icons.call_end_rounded,
                            color: Color(0xFFFB7185), size: 34),
                        const SizedBox(height: 16),
                        const Text('End this call preview?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                            'This is a local design. No active call will be changed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: NsColors.muted)),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: () => Navigator.maybePop(context),
                              child: const Text('Keep preview')),
                          FilledButton(
                              onPressed: controller.endPreview,
                              child: const Text('End preview')),
                        ]),
                      ]),
                    ),
                  ] else if (designId == 49 && !state.invitationAccepted) ...[
                    const SizedBox(height: 24),
                    NightshiftSurface(
                      child: Column(children: [
                        const Icon(Icons.casino_outlined,
                            size: 48, color: NsColors.gold),
                        const SizedBox(height: 12),
                        const Text('A little friendly competition?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        const Text(
                            'Explore the local Ludo board. No invitation is sent and there are no winnings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: NsColors.muted)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                            onPressed: controller.acceptInvitation,
                            icon: const Icon(Icons.casino),
                            label: const Text('Try local board')),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (connecting && designId != 37)
                    Center(
                      child: OutlinedButton.icon(
                          onPressed: controller.endPreview,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel preview')),
                    )
                  else if (designId != 37)
                    _PreviewControls(
                        state: state, controller: controller, video: video),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: NsColors.violet.withValues(alpha: .12),
          border: Border.all(color: NsColors.violet.withValues(alpha: .25))),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: NsColors.muted)));
}

class _DesignPill extends StatelessWidget {
  const _DesignPill(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          border: Border.all(color: color.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(40)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 12))),
      ]));
}

class _AudioDesign extends StatelessWidget {
  const _AudioDesign({required this.listener});
  final bool listener;
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: NsColors.violet.withValues(alpha: .2)),
              gradient: RadialGradient(colors: [
                NsColors.violet.withValues(alpha: .3),
                NsColors.background,
              ])),
          child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: NsColors.cyan, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: NsColors.violet.withValues(alpha: .23),
                        blurRadius: 40)
                  ]),
              child: NightshiftAvatar(
                  name: listener ? 'Customer' : 'Listener',
                  listener: !listener,
                  size: 134)),
        ),
        const SizedBox(height: 26),
        Text(listener ? 'Customer' : 'Your Listener',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const _DesignPill(
            icon: Icons.graphic_eq, text: 'Audio layout', color: NsColors.cyan),
      ]);
}

class _ConnectingDesign extends StatelessWidget {
  const _ConnectingDesign();
  @override
  Widget build(BuildContext context) => Column(children: [
        const _DesignPill(
            icon: Icons.info_outline,
            text: 'Matching screen preview',
            color: NsColors.gold),
        const SizedBox(height: 38),
        Container(
          width: 190,
          height: 230,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: NsColors.cyan, width: 2),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF432063), Color(0xFF171227)]),
              boxShadow: [
                BoxShadow(
                    color: NsColors.violet.withValues(alpha: .26),
                    blurRadius: 45)
              ]),
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NightshiftAvatar(name: 'Listener', listener: true, size: 112),
                SizedBox(height: 25),
                SizedBox(
                    width: 124,
                    child: LinearProgressIndicator(
                        value: .6,
                        color: NsColors.cyan,
                        backgroundColor: Colors.white12)),
              ]),
        ),
        const SizedBox(height: 36),
        const Text('Finding a Listener\nfor you…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('No search is sent from this design preview.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted)),
      ]);
}

class _VideoDesign extends StatelessWidget {
  const _VideoDesign({
    required this.camera,
    required this.hiddenFace,
    required this.faceBox,
    required this.compact,
  });
  final bool camera, hiddenFace, faceBox, compact;
  @override
  Widget build(BuildContext context) => Container(
        height: compact ? 210 : 390,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3F2458), Color(0xFF15142D)]),
            border: Border.all(color: Colors.white12)),
        child: Stack(children: [
          Center(
              child: hiddenFace
                  ? Container(
                      width: 150,
                      height: 190,
                      decoration: BoxDecoration(
                          color: NsColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: NsColors.cyan)),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility_off_outlined,
                                color: NsColors.cyan, size: 38),
                            SizedBox(height: 14),
                            Flexible(
                                child: Text('Hidden in\nthis preview',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12))),
                          ]))
                  : Container(
                      padding: EdgeInsets.all(faceBox ? 15 : 0),
                      decoration: faceBox
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: NsColors.cyan, width: 2))
                          : null,
                      child: NightshiftAvatar(
                          name: 'Listener',
                          listener: true,
                          size: compact ? 92 : 150))),
          const Positioned(
              top: 14,
              left: 14,
              child: _DesignPill(
                  icon: Icons.videocam_outlined,
                  text: 'Video layout',
                  color: NsColors.cyan)),
          Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: compact ? 75 : 104,
                height: compact ? 95 : 138,
                decoration: BoxDecoration(
                    color: NsColors.card,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: NsColors.cyan, width: 2)),
                child: Stack(children: [
                  Align(
                      alignment: const Alignment(0, -.35),
                      child: camera
                          ? NightshiftAvatar(
                              name: 'You', size: compact ? 43 : 62)
                          : const Icon(Icons.videocam_off_outlined,
                              color: NsColors.muted, size: 30)),
                  Positioned(
                      bottom: 6,
                      left: 4,
                      right: 4,
                      child: Text(camera ? 'You' : 'Off',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10))),
                ]),
              )),
          if (faceBox)
            const Positioned(
                left: 14,
                bottom: 14,
                child: Text('Layout overlay\nNo face detection',
                    style: TextStyle(fontSize: 11, color: NsColors.muted))),
        ]),
      );
}

class _RatingDesign extends StatelessWidget {
  const _RatingDesign({required this.state, required this.controller});
  final CallDesignState state;
  final CallDesignController controller;
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 16),
        const NightshiftAvatar(name: 'Listener', listener: true, size: 106),
        const SizedBox(height: 22),
        const Text('How was your conversation?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        const Text('Your feedback helps shape a better experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted)),
        const SizedBox(height: 26),
        Wrap(alignment: WrapAlignment.center, children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
                key: ValueKey('rating-$star'),
                tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                onPressed: () => controller.rate(star),
                iconSize: 37,
                color: star <= state.rating ? NsColors.gold : NsColors.muted,
                icon: Icon(star <= state.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded)),
        ]),
        const SizedBox(height: 24),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final tag in [
                'Great listener',
                'Friendly',
                'Clear audio',
                'Helpful'
              ])
                FilterChip(
                    label: Text(tag),
                    selected: state.tags.contains(tag),
                    onSelected: (_) => controller.toggleTag(tag)),
            ]),
        const SizedBox(height: 28),
        NightshiftSurface(
            child: Column(children: [
          const Icon(Icons.favorite_outline, color: NsColors.cyan),
          const SizedBox(height: 12),
          Text(
              state.ratingSelected
                  ? 'Rating selected locally. Nothing was submitted.'
                  : 'Ratings are not connected yet. Try selecting stars and feedback tags in this preview.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: NsColors.muted)),
        ])),
        const SizedBox(height: 24),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: state.rating > 0 ? controller.selectRating : null,
                child: const Text('Keep preview rating'))),
      ]);
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls(
      {required this.state, required this.controller, required this.video});
  final CallDesignState state;
  final CallDesignController controller;
  final bool video;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 17,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _RoundControl(
                label: state.speaker ? 'Speaker' : 'Earpiece',
                icon: state.speaker ? Icons.volume_up : Icons.hearing,
                onPressed: controller.toggleSpeaker),
            if (video)
              _RoundControl(
                  label: state.camera ? 'Camera on' : 'Camera off',
                  icon: state.camera ? Icons.videocam : Icons.videocam_off,
                  onPressed: controller.toggleCamera),
            _RoundControl(
                label: state.muted ? 'Unmute' : 'Mute',
                icon: state.muted ? Icons.mic_off : Icons.mic,
                active: !state.muted,
                onPressed: controller.toggleMute),
            _RoundControl(
                label: 'End preview',
                icon: Icons.call_end,
                danger: true,
                onPressed: controller.endPreview),
          ]);
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active, danger;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 72,
      child: Column(children: [
        IconButton.filled(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
                minimumSize: const Size(57, 57),
                backgroundColor: danger
                    ? const Color(0xFFE74365)
                    : active
                        ? Colors.white
                        : NsColors.card,
                foregroundColor: active ? NsColors.background : Colors.white),
            icon: Icon(icon, size: 25)),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.muted, fontSize: 11)),
      ]));
}

class _LudoDesign extends StatelessWidget {
  const _LudoDesign({required this.state, required this.controller});
  final CallDesignState state;
  final CallDesignController controller;
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
          label: 'Local Ludo board preview. No remote player or winnings.',
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
                painter: _LudoBoardPainter(state.moves),
                child: const Center(
                    child: Icon(Icons.star_rounded,
                        color: NsColors.gold, size: 29))),
          ),
        ),
        const SizedBox(height: 16),
        NightshiftSurface(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Expanded(
                child: Text('Explore the board\nLocal moves only',
                    style: TextStyle(color: NsColors.muted, fontSize: 12))),
            FilledButton.icon(
                key: const ValueKey('roll-preview-dice'),
                onPressed: controller.rollPreviewDice,
                icon: const Icon(Icons.casino_outlined),
                label: Text('Roll · ${state.dice}')),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('No online game, invitation, or earnings are created.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted, fontSize: 11)),
      ]);
}

class _LudoBoardPainter extends CustomPainter {
  const _LudoBoardPainter(this.moves);
  final int moves;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 15;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = Colors.white24;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
        fill..color = const Color(0xFF171426));
    for (var y = 0; y < 15; y++) {
      for (var x = 0; x < 15; x++) {
        if ((x >= 6 && x <= 8) || (y >= 6 && y <= 8)) {
          final rect = Rect.fromLTWH(x * unit, y * unit, unit, unit);
          var color = const Color(0xFF342C48);
          if (y == 7 && x < 6) color = const Color(0xFF178663);
          if (x == 7 && y < 6) color = const Color(0xFFCD9224);
          if (x == 7 && y > 8) color = const Color(0xFFCE426A);
          if (y == 7 && x > 8) color = const Color(0xFF3577CC);
          canvas.drawRect(rect, fill..color = color);
          canvas.drawRect(rect, line);
        }
      }
    }
    const corners = [
      (0.0, 0.0, Color(0xFF139B72)),
      (9.0, 0.0, Color(0xFFE6AA36)),
      (0.0, 9.0, Color(0xFFE55578)),
      (9.0, 9.0, Color(0xFF438DDF)),
    ];
    for (final (x, y, color) in corners) {
      final base =
          Rect.fromLTWH(x * unit + 4, y * unit + 4, unit * 6 - 8, unit * 6 - 8);
      canvas.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(14)),
          fill..color = color.withValues(alpha: .6));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              base.deflate(unit * .7), const Radius.circular(10)),
          fill..color = const Color(0xFF181425));
      for (final dx in [1.9, 4.1]) {
        for (final dy in [1.9, 4.1]) {
          canvas.drawCircle(Offset((x + dx) * unit, (y + dy) * unit),
              unit * .55, fill..color = color);
          canvas.drawCircle(Offset((x + dx) * unit, (y + dy) * unit),
              unit * .24, fill..color = Colors.white70);
        }
      }
    }
    if (moves > 0) {
      final step = moves % 5;
      canvas.drawCircle(Offset((step + .5) * unit, 6.5 * unit), unit * .43,
          fill..color = NsColors.cyan);
    }
    canvas.drawRect(Rect.fromLTWH(6 * unit, 6 * unit, 3 * unit, 3 * unit),
        fill..color = NsColors.violet.withValues(alpha: .5));
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) =>
      oldDelegate.moves != moves;
}

class _EndedPreview extends StatelessWidget {
  const _EndedPreview({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        const Icon(Icons.call_end_rounded, size: 64, color: Color(0xFFFB7185)),
        const SizedBox(height: 24),
        const Text('Preview ended',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('No live call or account balance was changed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted)),
        const SizedBox(height: 28),
        OutlinedButton(onPressed: onBack, child: const Text('Back to designs')),
      ]));
}
