import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design_system.dart';
import 'call_components.dart';

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
    final invitation = {49, 51}.contains(designId) && !state.invitationAccepted;
    final board = {33, 40}.contains(designId) ||
        ({49, 51}.contains(designId) && state.invitationAccepted);
    final video = !board && {36, 38, 46, 49, 51, 52}.contains(designId);
    final connecting = designId == 37 || designId == 54;
    final peer = listener ? 'rahul_92' : 'mannat_046';
    final portrait = listener ? _sampleMan : _sampleWoman;
    return Scaffold(
        backgroundColor: const Color(0xFF0C1220),
        body: Stack(fit: StackFit.expand, children: [
          if (video && !state.ended && preview)
            _VideoBackdrop(asset: portrait, hidden: designId == 38)
          else
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                  Color(0xFF192B47),
                  Color(0xFF11172D),
                  Color(0xFF080C18)
                ]))),
          SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => ListView(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                          children: [
                            _CallHeader(
                                preview: preview,
                                listener: listener,
                                connecting: connecting || designId == 18),
                            if (state.ended)
                              _EndedPreview(
                                  onBack: () => Navigator.maybePop(context))
                            else if (designId == 18)
                              _RatingDesign(
                                  state: state, controller: controller)
                            else if (connecting) ...[
                              const SizedBox(height: 24),
                              if (designId == 37)
                                SizedBox(
                                    height: (constraints.maxHeight - 120)
                                        .clamp(600, 900),
                                    child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Positioned.fill(
                                              child: IgnorePointer(
                                                  child: Opacity(
                                                      opacity: .22,
                                                      child: SingleChildScrollView(
                                                          child:
                                                              _ConnectingDesign())))),
                                          _ConflictCard(controller: controller),
                                        ]))
                              else ...[
                                const _ConnectingDesign(),
                                const SizedBox(height: 36),
                                Center(
                                    child: OutlinedButton.icon(
                                        onPressed: controller.endPreview,
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text('Cancel preview')))
                              ],
                            ] else if (board) ...[
                              const SizedBox(height: 20),
                              _PlayerStrip(
                                  name: peer,
                                  asset: portrait,
                                  caption: listener
                                      ? 'Red · Customer'
                                      : 'Yellow · Listener',
                                  color: listener ? _red : _yellow,
                                  trailing: '09:42'),
                              const SizedBox(height: 18),
                              _LudoDesign(
                                  state: state,
                                  controller: controller,
                                  listener: listener),
                              const SizedBox(height: 22),
                              _PreviewControls(
                                  state: state,
                                  controller: controller,
                                  video: true),
                            ] else if (video) ...[
                              _VideoStage(
                                  height: invitation
                                      ? 185
                                      : (constraints.maxHeight * .49)
                                          .clamp(280, 460),
                                  camera: state.camera,
                                  localAsset:
                                      listener ? _sampleWoman : _sampleMan,
                                  faceBox: designId == 36,
                                  hidden: designId == 38),
                              _PeerHeading(
                                  name: preview ? peer : 'Not connected',
                                  caption:
                                      listener ? 'Customer' : 'Your companion',
                                  centered: false),
                              if (invitation) ...[
                                const SizedBox(height: 18),
                                _GameInvitation(
                                    controller: controller, listener: listener)
                              ],
                              const SizedBox(height: 28),
                              _PreviewControls(
                                  state: state,
                                  controller: controller,
                                  video: true),
                            ] else ...[
                              SizedBox(
                                  height: (constraints.maxHeight * .09)
                                      .clamp(24, 80)),
                              _AudioDesign(
                                  listener: listener, preview: preview),
                              const SizedBox(height: 38),
                              _PreviewControls(
                                  state: state,
                                  controller: controller,
                                  video: false),
                              const SizedBox(height: 26),
                              Center(
                                  child: TextButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.shield_outlined,
                                          size: 17),
                                      label: const Text('Report or block'))),
                            ],
                          ]))),
        ]));
  }
}

const _sampleWoman = 'assets/avatars/female/avatar_01.png';
const _sampleMan = 'assets/avatars/male/avatar_01.png';
const _yellow = Color(0xFFF5C84C);
const _red = Color(0xFFF16B79);

class _CallHeader extends StatelessWidget {
  const _CallHeader(
      {required this.preview,
      required this.listener,
      required this.connecting});
  final bool preview, listener, connecting;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          if (connecting)
            const Expanded(child: NightshiftBrand(size: 23))
          else
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: _DesignPill(
                        icon: listener
                            ? Icons.diamond_rounded
                            : Icons.add_circle_rounded,
                        text: listener ? (preview ? '28' : '—') : 'Add coins',
                        color: listener ? NsColors.cyan : NsColors.gold))),
          Semantics(
              label: 'Design preview. No live call, payment or earnings.',
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24)),
                  child: Text(preview ? 'Preview' : 'Not connected',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          letterSpacing: .5)))),
          if (!connecting) ...[
            const SizedBox(width: 8),
            _DesignPill(
                icon: Icons.graphic_eq,
                text: preview ? '09:34' : '— : —',
                color: const Color(0xFFF5B4DB))
          ],
        ]),
        if (!connecting) ...[
          const SizedBox(height: 12),
          const Align(
              alignment: Alignment.centerRight,
              child: Text('Secure connection',
                  style: TextStyle(
                      fontSize: 10, color: Colors.white70, letterSpacing: .4)))
        ],
      ]);
}

class _DesignPill extends StatelessWidget {
  const _DesignPill(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xD91C2435),
          border: Border.all(color: color.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(40)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700))),
      ]));
}

class _PeerHeading extends StatelessWidget {
  const _PeerHeading(
      {required this.name, required this.caption, this.centered = true});
  final String name, caption;
  final bool centered;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment:
              centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(name,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded,
                  size: 15, color: NsColors.cyan),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(caption,
                      style: const TextStyle(
                          color: Color(0xFFCFD5E9), fontSize: 12))),
            ]),
          ]);
}

class _AudioDesign extends StatelessWidget {
  const _AudioDesign({required this.listener, required this.preview});
  final bool listener, preview;
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            width: 278,
            height: 278,
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: NsColors.violet.withValues(alpha: .14)),
                gradient: RadialGradient(colors: [
                  NsColors.violet.withValues(alpha: .25),
                  NsColors.violet.withValues(alpha: .025)
                ])),
            child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: NsColors.violet.withValues(alpha: .4))),
                child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFB999FF), width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: NsColors.violet.withValues(alpha: .4),
                              blurRadius: 38,
                              spreadRadius: 2)
                        ]),
                    child: NightshiftAvatar(
                        name: 'Companion',
                        size: 180,
                        assetPath: preview
                            ? (listener ? _sampleMan : _sampleWoman)
                            : null)))),
        const SizedBox(height: 22),
        _PeerHeading(
            name: preview
                ? (listener ? 'rahul_92' : 'mannat_046')
                : 'Not connected',
            caption: listener ? 'Customer · English' : 'Listener · English'),
        const SizedBox(height: 20),
        const _AudioBars(),
        const SizedBox(height: 12),
        const Text('A little company, a better night.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted, fontSize: 12)),
      ]);
}

class _AudioBars extends StatelessWidget {
  const _AudioBars();
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Audio waveform illustration',
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final h in [
          7.0,
          12.0,
          23.0,
          15.0,
          31.0,
          20.0,
          10.0,
          18.0,
          27.0,
          12.0,
          6.0
        ])
          Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                  color: NsColors.cyan.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(4))),
      ]));
}

class _VideoBackdrop extends StatelessWidget {
  const _VideoBackdrop({required this.asset, required this.hidden});
  final String asset;
  final bool hidden;
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: hidden ? 22 : 0, sigmaY: hidden ? 22 : 0),
            child: AvatarPortrait(
                assetPath: asset, borderRadius: BorderRadius.zero)),
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [
              0,
              .25,
              .55,
              1
            ],
                    colors: [
              Color(0x99040B16),
              Color(0x08040B16),
              Color(0x22040B16),
              Color(0xF2070C19)
            ]))),
      ]);
}

class _VideoStage extends StatelessWidget {
  const _VideoStage(
      {required this.height,
      required this.camera,
      required this.localAsset,
      required this.faceBox,
      required this.hidden});
  final double height;
  final bool camera, faceBox, hidden;
  final String localAsset;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      child: Stack(children: [
        if (faceBox || hidden)
          Align(
              alignment: const Alignment(-.22, -.12),
              child: Container(
                  width: 178,
                  height: 195,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: hidden
                          ? const Color(0x9C162234)
                          : const Color(0x400A1425),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: hidden ? Colors.white24 : NsColors.cyan,
                          width: 1.5)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            hidden
                                ? Icons.visibility_off_outlined
                                : Icons.face_retouching_off,
                            size: 35,
                            color: Colors.white70),
                        const SizedBox(height: 12),
                        Flexible(
                            child: Text(
                                hidden ? 'Camera hidden' : 'Face not visible',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                      ]))),
        Positioned(
            right: 0,
            top: 26,
            child: Container(
                width: 88,
                height: 126,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 20)
                    ]),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(fit: StackFit.expand, children: [
                      if (camera)
                        AvatarPortrait(
                            assetPath: localAsset,
                            borderRadius: BorderRadius.zero)
                      else
                        const ColoredBox(
                            color: NsColors.surface,
                            child: Icon(Icons.videocam_off_outlined,
                                color: NsColors.muted)),
                      const Positioned(
                          left: 8,
                          bottom: 7,
                          child: Text('You',
                              style: TextStyle(fontSize: 10, shadows: [
                                Shadow(color: Colors.black, blurRadius: 6)
                              ]))),
                    ])))),
      ]));
}

class _ConnectingDesign extends StatelessWidget {
  const _ConnectingDesign();
  @override
  Widget build(BuildContext context) => Column(children: [
        const _DesignPill(
            icon: Icons.info_outline,
            text: 'Keep this screen open while connecting',
            color: NsColors.gold),
        const SizedBox(height: 35),
        SizedBox(
            height: 270,
            child: Stack(alignment: Alignment.center, children: [
              Positioned(
                  left: 0,
                  top: 35,
                  child: Transform.rotate(
                      angle: -.12,
                      child: const Opacity(
                          opacity: .4,
                          child: AvatarPortrait(
                              assetPath: 'assets/avatars/female/avatar_03.png',
                              width: 132,
                              height: 204)))),
              Positioned(
                  right: 0,
                  top: 35,
                  child: Transform.rotate(
                      angle: .12,
                      child: const Opacity(
                          opacity: .4,
                          child: AvatarPortrait(
                              assetPath: 'assets/avatars/female/avatar_04.png',
                              width: 132,
                              height: 204)))),
              Container(
                  width: 186,
                  height: 253,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: NsColors.cyan, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: NsColors.cyan.withValues(alpha: .2),
                            blurRadius: 32)
                      ]),
                  child: Stack(fit: StackFit.expand, children: [
                    const AvatarPortrait(assetPath: _sampleWoman),
                    Align(
                        alignment: const Alignment(0, .35),
                        child: Container(
                            height: 2,
                            decoration: const BoxDecoration(
                                color: NsColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                      color: NsColors.cyan,
                                      blurRadius: 14,
                                      spreadRadius: 3)
                                ]))),
                  ])),
            ])),
        const SizedBox(height: 28),
        const Text('Finding your\nnext conversation',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8)),
        const SizedBox(height: 16),
        const Text('A familiar language. A fresh connection.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted, fontSize: 12)),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3; i++)
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NsColors.cyan.withValues(alpha: 1 - i * .3))),
        ]),
      ]);
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.controller});
  final CallDesignController controller;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F1FC),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.call_end_rounded, color: Color(0xFF7842C5), size: 35),
        const SizedBox(height: 14),
        const Text('End this call?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: Color(0xFF241633))),
        const SizedBox(height: 8),
        const Text('Starting another call will end this conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF695D7B))),
        const SizedBox(height: 20),
        Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Keep preview')),
              FilledButton(
                  onPressed: controller.endPreview,
                  child: const Text('End preview')),
            ]),
      ]));
}

class _RatingDesign extends StatelessWidget {
  const _RatingDesign({required this.state, required this.controller});
  final CallDesignState state;
  final CallDesignController controller;
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 48),
        const NightshiftAvatar(
            name: 'Mannat', assetPath: _sampleWoman, size: 110),
        const SizedBox(height: 24),
        const Text('How was your\nconversation?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -.7)),
        const SizedBox(height: 14),
        const Text('A little feedback goes a long way.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted, fontSize: 13)),
        const SizedBox(height: 26),
        Wrap(alignment: WrapAlignment.center, children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
                key: ValueKey('rating-$star'),
                tooltip: '$star stars',
                onPressed: () => controller.rate(star),
                iconSize: 36,
                color: star <= state.rating
                    ? NsColors.gold
                    : const Color(0xFFAFA8C8),
                icon: Icon(star <= state.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded)),
        ]),
        const SizedBox(height: 16),
        Text(
            state.rating == 0
                ? 'Tap a star to rate'
                : [
                    '',
                    'Could be better',
                    'It was okay',
                    'Good call',
                    'Great conversation!',
                    'An outstanding match!'
                  ][state.rating],
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.gold, fontSize: 13)),
        const SizedBox(height: 28),
        Wrap(
            spacing: 8,
            runSpacing: 10,
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
        const SizedBox(height: 38),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: state.rating > 0 ? controller.selectRating : null,
                child: const Text('Keep preview rating'))),
        const SizedBox(height: 16),
        Text(
            state.ratingSelected
                ? 'Rating selected locally. Nothing was submitted.'
                : 'Your rating stays in this preview.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.muted, fontSize: 11)),
      ]);
}

class _GameInvitation extends StatelessWidget {
  const _GameInvitation({required this.controller, required this.listener});
  final CallDesignController controller;
  final bool listener;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
          color: const Color(0xEE18152D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: NsColors.violet.withValues(alpha: .6)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 24)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: NsColors.violet.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.casino_rounded,
                  color: NsColors.gold, size: 38)),
          const SizedBox(width: 16),
          const Flexible(
              child: Text('Let’s play Ludo!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 14),
        const Text('A little friendly competition while you talk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: NsColors.muted)),
        const SizedBox(height: 16),
        _DesignPill(
            icon: listener ? Icons.diamond_rounded : Icons.toll,
            text: listener
                ? 'Sample prize · 100 diamonds'
                : 'Sample prize · 500 coins',
            color: NsColors.gold),
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: controller.acceptInvitation,
                child: const Text('Try local board'))),
      ]));
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls(
      {required this.state, required this.controller, required this.video});
  final CallDesignState state;
  final CallDesignController controller;
  final bool video;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 12,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            _RoundControl(
                label: state.speaker ? 'Speaker' : 'Earpiece',
                icon: state.speaker ? Icons.volume_up_rounded : Icons.hearing,
                onPressed: controller.toggleSpeaker),
            if (video)
              _RoundControl(
                  label: state.camera ? 'Camera on' : 'Camera off',
                  icon: state.camera
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  onPressed: controller.toggleCamera),
            _RoundControl(
                label: state.muted ? 'Unmute' : 'Mute',
                icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                active: !state.muted,
                onPressed: controller.toggleMute),
            _RoundControl(
                label: 'End preview',
                icon: Icons.call_end_rounded,
                danger: true,
                onPressed: controller.endPreview),
          ]);
}

class _RoundControl extends StatelessWidget {
  const _RoundControl(
      {required this.label,
      required this.icon,
      required this.onPressed,
      this.active = false,
      this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active, danger;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 70,
      child: Column(children: [
        Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: danger
                    ? [
                        BoxShadow(
                            color:
                                const Color(0xFFEB4163).withValues(alpha: .28),
                            blurRadius: 18,
                            offset: const Offset(0, 6))
                      ]
                    : null),
            child: IconButton.filled(
                tooltip: label,
                onPressed: onPressed,
                style: IconButton.styleFrom(
                    minimumSize: const Size(58, 58),
                    backgroundColor: danger
                        ? const Color(0xFFEB4163)
                        : active
                            ? Colors.white
                            : const Color(0xB32A3045),
                    foregroundColor:
                        active && !danger ? NsColors.background : Colors.white,
                    side: BorderSide(
                        color:
                            danger ? const Color(0xFFFC849B) : Colors.white12)),
                icon: Icon(icon, size: 25))),
        const SizedBox(height: 9),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]));
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip(
      {required this.name,
      required this.asset,
      required this.caption,
      required this.color,
      required this.trailing});
  final String name, asset, caption, trailing;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2)),
            child: NightshiftAvatar(name: name, assetPath: asset, size: 42)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: color, fontSize: 10)),
        ])),
        const SizedBox(width: 8),
        Text(trailing,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w600)),
      ]);
}

class _LudoDesign extends StatelessWidget {
  const _LudoDesign(
      {required this.state, required this.controller, required this.listener});
  final CallDesignState state;
  final CallDesignController controller;
  final bool listener;
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF24233B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 24,
                      offset: Offset(0, 8))
                ]),
            child: Semantics(
                label:
                    'Local Ludo board preview. Four colored yards, home lanes, safe spaces and tokens.',
                child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: CustomPaint(
                            key: const ValueKey('detailed-ludo-board'),
                            painter: CallBoardPainter(state.moves)))))),
        const SizedBox(height: 20),
        _PlayerStrip(
            name: 'You',
            asset: listener ? _sampleWoman : _sampleMan,
            caption: listener ? 'Yellow · Listener' : 'Red · Customer',
            color: listener ? _yellow : _red,
            trailing: '1 / 4 home'),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: const Color(0xFF20223B),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: NsColors.violet.withValues(alpha: .4))),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Your turn',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        listener
                            ? 'Sample prize · 100 diamonds'
                            : 'Sample prize · 500 coins',
                        style: const TextStyle(
                            fontSize: 10, color: NsColors.gold)),
                  ])),
              const SizedBox(width: 10),
              Semantics(
                  label: 'Roll local preview dice',
                  button: true,
                  child: InkWell(
                      key: const ValueKey('roll-preview-dice'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: controller.rollPreviewDice,
                      child: SizedBox(
                          width: 56,
                          height: 56,
                          child:
                              CustomPaint(painter: _DicePainter(state.dice))))),
            ])),
        const SizedBox(height: 12),
        const Text('Local moves only · no winnings',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted, fontSize: 10)),
      ]);
}

class _DicePainter extends CustomPainter {
  const _DicePainter(this.value);
  final int value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)),
        Paint()..color = const Color(0xFFF9F7FF));
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(13)),
        Paint()
          ..color = const Color(0xFFD6C8FC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final points = <Offset>[
      if (value.isOdd) const Offset(.5, .5),
      if (value >= 2) ...[const Offset(.28, .28), const Offset(.72, .72)],
      if (value >= 4) ...[const Offset(.72, .28), const Offset(.28, .72)],
      if (value == 6) ...[const Offset(.28, .5), const Offset(.72, .5)]
    ];
    for (final p in points) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 3.8,
          Paint()..color = const Color(0xFF613EAA));
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter oldDelegate) =>
      value != oldDelegate.value;
}

class _EndedPreview extends StatelessWidget {
  const _EndedPreview({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 100),
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
