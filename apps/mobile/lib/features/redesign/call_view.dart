part of '../screens.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});
  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Object? _owner;
  String? _callId;
  bool _games = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider), call = state.activeCall;
    if (call == null) {
      return Scaffold(
          body: Center(
              child: LoadingNotice(
                  label:
                      state.text('Loading call…', 'அழைப்பு ஏற்றப்படுகிறது…'))));
    }
    if (_owner != state.accountIdentity || _callId != call.id) {
      _owner = state.accountIdentity;
      _callId = call.id;
      _games = false;
    }
    final incoming = call.listenerId == state.user?.id;
    final removed =
        !state.isListener && state.discovery.removed(call.listenerId);
    final name = removed
        ? state.text('Unavailable listener', 'கிடைக்காத கேட்பவர்')
        : call.otherName(state.user!.id);
    final avatar = removed
        ? null
        : incoming
            ? call.customerAvatarCode
            : call.listenerAvatarCode;
    final localAvatar =
        incoming ? call.listenerAvatarCode : call.customerAvatarCode;
    final liveVideo = call.isVideo &&
        !call.ringing &&
        !state.needsVideoConsent &&
        state.video != null;
    final disabled =
        state.endingLocally || state.busy || state.needsVideoConsent;
    final customerRate = call.isVideo
        ? state.text('Video · ${testRateLabel(state, call.rate)}',
            'வீடியோ · ${testRateLabel(state, call.rate)}')
        : state.text('Audio · ${testRateLabel(state, call.rate)}',
            'ஆடியோ · ${testRateLabel(state, call.rate)}');
    final title = state.endingLocally
        ? state.text('Ending call · waiting for confirmation',
            'அழைப்பை முடிக்கிறது · உறுதிப்படுத்தலுக்காக காத்திருக்கிறது')
        : switch (call.state) {
            'ringing' => incoming
                ? call.isVideo
                    ? state.text('Incoming video call', 'வரும் வீடியோ அழைப்பு')
                    : state.text('Incoming audio call', 'வரும் ஆடியோ அழைப்பு')
                : state.text('Calling…', 'அழைக்கிறது…'),
            'connected' => state.text('Connected', 'இணைக்கப்பட்டது'),
            'reconnecting' => state.text('Reconnecting · not charging',
                'மீண்டும் இணைகிறது · கட்டணம் இல்லை'),
            _ => call.isVideo
                ? state.text('Connecting video · not charging',
                    'வீடியோ இணைகிறது · கட்டணம் இல்லை')
                : state.text('Connecting audio · not charging',
                    'ஆடியோ இணைகிறது · கட்டணம் இல்லை'),
          };
    final financial = incoming
        ? state.text(
            'Test earnings: ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
            'சோதனை வருமானம்: ₹${(call.earningPaise / 100).toStringAsFixed(2)}')
        : state.text('${creditAmount(state.balance)} test coins',
            '${creditAmount(state.balance)} சோதனை நாணயங்கள்');
    final financialValue = incoming
        ? '₹${(call.earningPaise / 100).toStringAsFixed(2)}'
        : creditAmount(state.balance);
    return PopScope(
        canPop: false,
        child: Scaffold(
            backgroundColor: const Color(0xFF0C1220),
            body: LiveCallStage(
              background: liveVideo && !_games
                  ? VideoCallView(
                      fullBleed: true,
                      video: state.video!,
                      remoteAvatarCode: avatar,
                      localAvatarCode: localAvatar,
                      remoteLabel: name,
                      localLabel: state.text('You', 'நீங்கள்'),
                      waitingLabel: state.text(
                          'Waiting for video', 'வீடியோவிற்காக காத்திருக்கிறது'),
                      cameraOffLabel:
                          state.text('Camera off', 'கேமரா நிறுத்தப்பட்டுள்ளது'))
                  : null,
              header: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                              label: financial,
                              child: ExcludeSemantics(
                                  child: CallStatusPill(
                                      label: financialValue,
                                      icon: incoming
                                          ? Icons.diamond_outlined
                                          : Icons.monetization_on_outlined,
                                      color: incoming
                                          ? NsColors.cyan
                                          : NsColors.gold))))),
                  const SizedBox(width: 12),
                  Flexible(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                              label: state.text(
                                  'Server-confirmed connected time',
                                  'சேவையகம் உறுதிப்படுத்திய இணைப்பு நேரம்'),
                              child: CallStatusPill(
                                  label: durationLabel(call.connectedMs)
                                      .padLeft(5, '0'),
                                  icon: Icons.graphic_eq,
                                  color: const Color(0xFFEBA9D5))))),
                ]),
                const SizedBox(height: 10),
                Semantics(
                    liveRegion: true,
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 12)))
              ]),
              content: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                          children: [
                            const ErrorNotice(),
                            if (_games)
                              UnavailableCallGame(
                                  name: name,
                                  avatarCode: avatar,
                                  title: state.text('Play Ludo together',
                                      'ஒன்றாக லூடோ விளையாடலாம்'),
                                  explanation: state.text(
                                      'Games are not available yet. Your call continues here. No invitation, coins or prizes are sent.',
                                      'விளையாட்டு இன்னும் கிடைக்கவில்லை. அழைப்பு இங்கே தொடரும். அழைப்போ நாணயங்களோ பரிசுகளோ அனுப்பப்படாது.'),
                                  disabledLabel: state
                                      .text('Games unavailable',
                                          'விளையாட்டு கிடைக்கவில்லை'),
                                  backLabel: state.text('Back to conversation',
                                      'உரையாடலுக்குத் திரும்பு'),
                                  onBack: () => setState(() => _games = false))
                            else ...[
                              if (liveVideo)
                                SizedBox(
                                    height: (MediaQuery.sizeOf(context).height *
                                            (MediaQuery.textScalerOf(context)
                                                        .scale(1) >
                                                    1.5
                                                ? .45
                                                : .32))
                                        .clamp(80, 420))
                              else
                                _CallPortrait(
                                    name: name,
                                    listener: !incoming,
                                    avatarCode: avatar,
                                    connecting: call.state != 'connected'),
                              Text(name,
                                  textAlign: liveVideo
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(
                                  incoming
                                      ? state.text('Customer', 'வாடிக்கையாளர்')
                                      : state.text('Listener', 'கேட்பவர்'),
                                  textAlign: liveVideo
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: const TextStyle(
                                      color: NsColors.muted, fontSize: 12)),
                              if (!call.isVideo && !call.ringing) ...[
                                const SizedBox(height: 20),
                                const CallWaveMotif(),
                              ],
                              const SizedBox(height: 20),
                              Text(
                                  incoming
                                      ? state.text(
                                          'Customer rate: $customerRate',
                                          'வாடிக்கையாளர் கட்டணம்: $customerRate')
                                      : customerRate,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12)),
                              if (call.ringing) ...[
                                const SizedBox(height: 12),
                                Text(
                                    state.text(
                                        'Ringing and waiting are free. The invitation expires automatically.',
                                        'காத்திருப்பு இலவசம். அழைப்பு தானாக காலாவதியாகும்.'),
                                    textAlign: TextAlign.center),
                                if (incoming)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                          state.text(
                                              'Proposed rate: ₹${(call.rate.listenerPaisePerHour / 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')} / paid connected hour. Test estimate only.',
                                              'முன்மொழியப்பட்ட விகிதம்: கட்டண இணைப்பு மணிநேரத்திற்கு ₹${(call.rate.listenerPaisePerHour / 100).toStringAsFixed(2)}. சோதனை மதிப்பீடு மட்டுமே.'),
                                          textAlign: TextAlign.center)),
                              ] else ...[
                                if (call.isVideo && state.needsVideoConsent)
                                  StatusCard(
                                      icon: Icons.videocam_off_outlined,
                                      title: state.text('Your camera is off',
                                          'உங்கள் கேமரா நிறுத்தப்பட்டுள்ளது'),
                                      message: state.text(
                                          'Review your camera and consent before joining this restored video call.',
                                          'மீட்டெடுக்கப்பட்ட வீடியோ அழைப்பில் சேருவதற்கு முன் கேமராவை சரிபார்த்து ஒப்புதல் அளிக்கவும்.'),
                                      action: FilledButton.icon(
                                          onPressed:
                                              state.busy || state.endingLocally
                                                  ? null
                                                  : () => _reviewVideoCall(
                                                      context, state, call),
                                          icon: const Icon(
                                              Icons.videocam_outlined),
                                          label: Text(state.text('Review camera', 'கேமராவை சரிபார்')))),
                                const SizedBox(height: 12),
                                Text(
                                    incoming
                                        ? state.text(
                                            'Test earnings: ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
                                            'சோதனை வருமானம்: ₹${(call.earningPaise / 100).toStringAsFixed(2)}')
                                        : state.text(
                                            'Test coins charged: ${creditAmount(call.chargeMicrocredits)}',
                                            'சோதனை நாணயக் கட்டணம்: ${creditAmount(call.chargeMicrocredits)}'),
                                    textAlign: TextAlign.center),
                                CallAllowanceDisplay(
                                    call: call,
                                    locale: state.locale,
                                    endingLocally: state.endingLocally),
                                if (call.isVideo &&
                                    !state.needsVideoConsent &&
                                    state.video != null) ...[
                                  if (!state.video!.cameraEnabled)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                            state.text(
                                                'Camera off. Healthy video time and test charging are paused.',
                                                'கேமரா நிறுத்தப்பட்டுள்ளது. வீடியோ இணைப்பு நேரமும் சோதனை கட்டணமும் நிறுத்தப்பட்டுள்ளன.'),
                                            textAlign: TextAlign.center)),
                                  TextButton.icon(
                                      onPressed: state.busy ||
                                              state.endingLocally ||
                                              !state.video!.cameraEnabled
                                          ? null
                                          : state.switchCamera,
                                      icon: const Icon(
                                          Icons.cameraswitch_outlined),
                                      label: Text(state.text(
                                          'Switch camera', 'கேமராவை மாற்று'))),
                                ],
                                if (call.isVideo &&
                                    state.video?.lowBandwidth == true)
                                  StatusCard(
                                      icon: Icons.network_check,
                                      title: state.text('Reduced video quality',
                                          'வீடியோ தரம் குறைக்கப்பட்டுள்ளது'),
                                      message: state.text(
                                          'Video quality is reduced for this connection. The video rate stays ${call.rate.coinsPerMinute} test coins / minute. You can end video and choose a new audio call.',
                                          'இந்த இணைப்பிற்கு வீடியோ தரம் குறைக்கப்பட்டுள்ளது. வீடியோ விகிதம் நிமிடத்திற்கு ${call.rate.coinsPerMinute} சோதனை நாணயங்களாகவே இருக்கும். வீடியோவை முடித்து புதிய ஆடியோ அழைப்பை தேர்வு செய்யலாம்.')),
                                if (call.isVideo)
                                  OutlinedButton.icon(
                                      onPressed:
                                          state.busy || state.endingLocally
                                              ? null
                                              : () => _confirmAudioFallback(
                                                  context, state, call),
                                      icon: const Icon(Icons.call_outlined),
                                      label: Text(state.text(
                                          'End video and use audio',
                                          'வீடியோவை முடித்து ஆடியோவை பயன்படுத்து'))),
                                const SizedBox(height: 16),
                                Text(
                                    call.isVideo
                                        ? state.text(
                                            'Leaving or locking the app ends this test call. No audio or video is recorded.',
                                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோவும் வீடியோவும் பதிவு செய்யப்படாது.')
                                        : state.text(
                                            'Leaving or locking the app ends this test call. No audio is recorded.',
                                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோ பதிவு செய்யப்படுவதில்லை.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: NsColors.muted, fontSize: 12)),
                              ],
                              const SizedBox(height: 16),
                              SelectableText(
                                  state.text('Call ID: ${call.id}',
                                      'அழைப்பு எண்: ${call.id}'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall),
                              MediaDiagnosticsButton(
                                  state: state, callId: call.id),
                            ],
                          ]))),
              controls: Column(mainAxisSize: MainAxisSize.min, children: [
                CallControlRow(
                    children: call.ringing
                        ? [
                            if (incoming)
                              CallRoundControl(
                                  label: call.isVideo
                                      ? state.text('Review video invitation',
                                          'வீடியோ அழைப்பை சரிபார்')
                                      : state.text('Accept', 'ஏற்கவும்'),
                                  icon: call.isVideo
                                      ? Icons.videocam_outlined
                                      : Icons.call,
                                  selected: true,
                                  onPressed: state.busy || state.endingLocally
                                      ? null
                                      : call.isVideo
                                          ? () => _reviewVideoCall(
                                              context, state, call,
                                              accepting: true)
                                          : () => state.transition('accept')),
                            CallRoundControl(
                                label: incoming
                                    ? state.text('Decline', 'நிராகரி')
                                    : state.text(
                                        'Cancel call', 'அழைப்பை ரத்து செய்'),
                                icon: Icons.call_end,
                                end: true,
                                onPressed: state.endingLocally
                                    ? null
                                    : () => state.transition(
                                        incoming ? 'decline' : 'cancel')),
                          ]
                        : [
                            CallRoundControl(
                                label: state.audio.speaker
                                    ? state.text(
                                        'Speaker on', 'ஒலிபெருக்கி இயங்குகிறது')
                                    : state.text('Earpiece', 'காதொலி'),
                                icon: state.audio.speaker
                                    ? Icons.volume_up
                                    : Icons.hearing,
                                onPressed: disabled
                                    ? null
                                    : () => state
                                        .perform(state.audio.toggleSpeaker)),
                            if (call.isVideo)
                              CallRoundControl(
                                  label: state.video?.cameraEnabled == true
                                      ? state.text(
                                          'Turn camera off', 'கேமராவை நிறுத்து')
                                      : state.text(
                                          'Turn camera on', 'கேமராவை இயக்கு'),
                                  icon: state.video?.cameraEnabled == true
                                      ? Icons.videocam
                                      : Icons.videocam_off_outlined,
                                  onPressed: disabled || state.video == null
                                      ? null
                                      : () => state.setCameraEnabled(
                                          !state.video!.cameraEnabled)),
                            CallRoundControl(
                                label: state.audio.muted
                                    ? state.text('Unmute', 'ஒலியை இயக்கு')
                                    : state.text('Mute', 'ஒலியை நிறுத்து'),
                                icon: state.audio.muted
                                    ? Icons.mic_off
                                    : Icons.mic,
                                selected: true,
                                onPressed: disabled
                                    ? null
                                    : () =>
                                        state.perform(state.audio.toggleMute)),
                            CallRoundControl(
                                label: state.text('End call', 'அழைப்பை முடி'),
                                icon: Icons.call_end,
                                end: true,
                                onPressed: state.endingLocally
                                    ? null
                                    : () => state.transition('end')),
                          ]),
                Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                  TextButton.icon(
                      onPressed: state.busy
                          ? null
                          : () => showSafetyDialog(context, state, call),
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(
                          state.text('Report or block', 'புகாரளி அல்லது தடு'))),
                  if (!call.ringing)
                    TextButton.icon(
                        onPressed: state.endingLocally
                            ? null
                            : () => setState(() => _games = !_games),
                        icon: Icon(
                            _games
                                ? Icons.forum_outlined
                                : Icons.casino_outlined,
                            size: 16),
                        label: Text(_games
                            ? state.text('Conversation', 'உரையாடல்')
                            : state.text('Games', 'விளையாட்டுகள்'))),
                ]),
              ]),
            )));
  }
}

class _CallPortrait extends StatelessWidget {
  const _CallPortrait({
    required this.name,
    required this.listener,
    required this.connecting,
    this.avatarCode,
  });
  final String name;
  final String? avatarCode;
  final bool listener, connecting;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: NsColors.violet.withValues(alpha: .2)),
                  gradient: RadialGradient(colors: [
                    NsColors.violet.withValues(alpha: .3),
                    NsColors.violet.withValues(alpha: .04),
                  ])),
              child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: connecting
                              ? NsColors.violet
                              : const Color(0xFFB999FF),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: NsColors.violet.withValues(alpha: .35),
                            blurRadius: 40)
                      ]),
                  child: NightshiftAvatar(
                      name: name,
                      size: 160,
                      listener: listener,
                      avatarCode: avatarCode)))));
}

/// A completed real conversation can reach its feedback design. No rating
/// endpoint exists yet, so selection/submission remain explicitly unavailable.
Future<void> showCallRating(
    BuildContext context, AppController state, CallSession call) async {
  if (!call.ended ||
      call.connectedMs <= 0 ||
      state.hasCall ||
      call.customerId != state.user?.id) {
    return;
  }
  await showDialog<void>(
      context: context,
      builder: (_) => _CallRatingDialog(state: state, call: call));
}

class _CallRatingDialog extends StatefulWidget {
  const _CallRatingDialog({required this.state, required this.call});
  final AppController state;
  final CallSession call;
  @override
  State<_CallRatingDialog> createState() => _CallRatingDialogState();
}

class _CallRatingDialogState extends State<_CallRatingDialog> {
  late final Object _owner;
  bool _closing = false;
  bool get _current =>
      widget.state.accountIdentity == _owner &&
      widget.state.user?.id == widget.call.customerId &&
      !widget.state.hasCall;
  @override
  void initState() {
    super.initState();
    _owner = widget.state.accountIdentity;
    widget.state.addListener(_checkOwner);
  }

  void _checkOwner() {
    if (_current || _closing) return;
    _closing = true;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null && route.isActive) {
        // Remove only our rating route, including while another dialog covers
        // it. Never pop a replacement route or leave a stale modal barrier.
        route.navigator?.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    widget.state.removeListener(_checkOwner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        if (!_current) return const SizedBox.shrink();
        final state = widget.state, call = widget.call;
        final removed = state.discovery.removed(call.listenerId);
        return Dialog(
            insetPadding: const EdgeInsets.all(18),
            backgroundColor: const Color(0xFF11172D),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  NightshiftAvatar(
                      name: removed ? '' : call.listenerName,
                      avatarCode: removed ? null : call.listenerAvatarCode,
                      size: 104),
                  const SizedBox(height: 24),
                  Text(
                      state.text('How was your conversation?',
                          'உங்கள் உரையாடல் எப்படி இருந்தது?'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  Text(
                      removed
                          ? state.text(
                              'Unavailable listener', 'கிடைக்காத கேட்பவர்')
                          : call.listenerName,
                      textAlign: TextAlign.center),
                  Text(
                      state.text('${durationLabel(call.connectedMs)} connected',
                          '${durationLabel(call.connectedMs)} இணைப்பு நேரம்'),
                      style: const TextStyle(color: NsColors.muted)),
                  const SizedBox(height: 28),
                  Row(children: [
                    for (var star = 1; star <= 5; star++)
                      Expanded(
                          child: IconButton(
                              onPressed: null,
                              tooltip: state.text('Ratings unavailable',
                                  'மதிப்பீடு கிடைக்கவில்லை'),
                              icon: const Icon(Icons.star_border_rounded,
                                  size: 30)))
                  ]),
                  const SizedBox(height: 20),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in [
                          state.text('Great listener', 'சிறந்த கேட்பவர்'),
                          state.text('Friendly', 'நட்பானவர்'),
                          state.text('Clear audio', 'தெளிவான ஆடியோ'),
                          state.text('Helpful', 'உதவியாக இருந்தது')
                        ])
                          Chip(label: Text(label))
                      ]),
                  const SizedBox(height: 24),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: null,
                          child: Text(state.text('Rating unavailable',
                              'மதிப்பீடு கிடைக்கவில்லை')))),
                  const SizedBox(height: 12),
                  Text(
                      state.text(
                          'Feedback is not collected yet. Nothing is submitted from this screen.',
                          'கருத்துகள் இன்னும் சேகரிக்கப்படவில்லை. இந்த திரையிலிருந்து எதுவும் அனுப்பப்படாது.'),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: NsColors.muted, fontSize: 12)),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(state.text(
                          'Back to history', 'வரலாற்றிற்குத் திரும்பு'))),
                ])));
      });
}

Future<void> _reviewVideoCall(
    BuildContext context, AppController state, CallSession call,
    {bool accepting = false}) async {
  final owner = state.accountIdentity;
  final consent = await showVideoPreflight(context, state,
      rate: call.rate,
      confirmLabel: accepting
          ? state.text('Accept video call', 'வீடியோ அழைப்பை ஏற்கவும்')
          : state.text('Join video call', 'வீடியோ அழைப்பில் சேர்'));
  if (!consent ||
      !context.mounted ||
      state.accountIdentity != owner ||
      state.activeCall?.id != call.id) {
    return;
  }
  if (accepting) {
    await state.transition('accept', cameraConsent: true);
  } else {
    await state.joinConsentedVideo();
  }
}

Future<void> _confirmAudioFallback(
    BuildContext context, AppController state, CallSession call) async {
  final owner = state.accountIdentity;
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              scrollable: true,
              title: Text(state.text(
                  'End video first?', 'முதலில் வீடியோவை முடிக்கவா?')),
              content: Text(state.text(
                  'This ends and settles the video call at its existing video rate. An audio call is a new invitation with a separate audio-rate confirmation. Nothing is repriced or redialled automatically.',
                  'தற்போதைய வீடியோ விகிதத்தில் இந்த அழைப்பு முடிக்கப்பட்டு கணக்கிடப்படும். ஆடியோ அழைப்பு தனி விகித ஒப்புதலுடன் புதிய அழைப்பாகும். விகிதம் தானாக மாறாது; தானாக மீண்டும் அழைக்கப்படாது.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(state.text('Keep video', 'வீடியோ தொடரட்டும்'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(state.text('End video', 'வீடியோவை முடி'))),
              ]));
  if (agreed != true ||
      state.accountIdentity != owner ||
      state.activeCall?.id != call.id) {
    return;
  }
  final wasCustomer = call.customerId == state.user?.id;
  await state.endVideoForAudio();
  if (state.accountIdentity != owner ||
      state.hasCall ||
      state.error != null ||
      !navigator.mounted) {
    return;
  }
  if (wasCustomer) {
    await state.refresh();
    if (!navigator.mounted ||
        state.accountIdentity != owner ||
        state.user == null ||
        state.hasCall) {
      return;
    }
    final peers = state.listeners
        .where(
            (listener) => listener.id == call.listenerId && listener.available)
        .toList();
    if (peers.isNotEmpty && !state.offline && state.error == null) {
      // Let the call-to-history redirect install its page before adding a
      // dialog; otherwise the router can remove the new quote with CallScreen.
      await WidgetsBinding.instance.endOfFrame;
      if (!navigator.mounted ||
          state.accountIdentity != owner ||
          state.hasCall ||
          state.user == null) {
        return;
      }
      await showAudioCallConfirmation(navigator.context, state, peers.first);
      return;
    }
  }
  if (messenger.mounted && state.accountIdentity == owner) {
    messenger.showSnackBar(SnackBar(
        content: Text(wasCustomer
            ? state.text(
                'Video ended. Find the Listener in Discover to start a new audio call.',
                'வீடியோ முடிந்தது. புதிய ஆடியோ அழைப்பிற்கு கண்டறியில் கேட்பவரை தேர்வு செய்யவும்.')
            : state.text(
                'Video ended. Ask the Customer to start a new audio call.',
                'வீடியோ முடிந்தது. புதிய ஆடியோ அழைப்பை தொடங்க வாடிக்கையாளரிடம் கூறவும்.'))));
  }
}
