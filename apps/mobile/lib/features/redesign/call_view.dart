part of '../screens.dart';

class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider),
        call = ref.watch(appControllerProvider).activeCall;
    if (call == null) {
      return Scaffold(
          body: Center(
              child: LoadingNotice(
                  label:
                      state.text('Loading call…', 'அழைப்பு ஏற்றப்படுகிறது…'))));
    }
    final incoming = call.listenerId == state.user?.id;
    final listenerHourlyRate = (call.rate.listenerPaisePerHour / 100)
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.00$'), '');
    final frozenCustomerRate = call.isVideo
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
    return PopScope(
        canPop: false,
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                title: Text(call.isVideo
                    ? state.text('Video call', 'வீடியோ அழைப்பு')
                    : state.text('Audio call', 'ஆடியோ அழைப்பு'))),
            bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: double.infinity,
                      child: call.ringing
                          ? OutlinedButton(
                              onPressed: state.endingLocally
                                  ? null
                                  : () => state.transition(
                                      incoming ? 'decline' : 'cancel'),
                              child: Text(incoming
                                  ? state.text('Decline', 'நிராகரி')
                                  : state.text(
                                      'Cancel call', 'அழைப்பை ரத்து செய்')))
                          : _endCallButton(context, state)),
                  if (call.isVideo && !call.ringing)
                    TextButton.icon(
                        onPressed: state.busy
                            ? null
                            : () => showSafetyDialog(context, state, call),
                        icon: const Icon(Icons.shield_outlined),
                        label: Text(state.text(
                            'Report or block', 'புகாரளி அல்லது தடு'))),
                ])),
            body: NightshiftBackdrop(
                child: _CallBody(children: [
              const ErrorNotice(),
              if (call.isVideo &&
                  !call.ringing &&
                  !state.needsVideoConsent &&
                  state.video != null)
                VideoCallView(
                    video: state.video!,
                    remoteAvatarCode: !state.isListener &&
                            state.discovery.removed(call.listenerId)
                        ? null
                        : incoming
                            ? call.customerAvatarCode
                            : call.listenerAvatarCode,
                    localAvatarCode: incoming
                        ? call.listenerAvatarCode
                        : call.customerAvatarCode,
                    remoteLabel: call.otherName(state.user!.id),
                    localLabel: state.text('You', 'நீங்கள்'),
                    waitingLabel: state.text(
                        'Waiting for video', 'வீடியோவிற்காக காத்திருக்கிறது'),
                    cameraOffLabel:
                        state.text('Camera off', 'கேமரா நிறுத்தப்பட்டுள்ளது'))
              else
                _CallPortrait(
                    name: !state.isListener &&
                            state.discovery.removed(call.listenerId)
                        ? state.text(
                            'Unavailable listener', 'கிடைக்காத கேட்பவர்')
                        : call.otherName(state.user!.id),
                    listener: !incoming,
                    avatarCode: !state.isListener &&
                            state.discovery.removed(call.listenerId)
                        ? null
                        : incoming
                            ? call.customerAvatarCode
                            : call.listenerAvatarCode,
                    connecting: call.state != 'connected'),
              const SizedBox(height: 24),
              Text(
                  !state.isListener && state.discovery.removed(call.listenerId)
                      ? state.text('Unavailable listener', 'கிடைக்காத கேட்பவர்')
                      : call.otherName(state.user!.id),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Center(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                          color: NsColors.violet.withValues(alpha: .13),
                          border: Border.all(
                              color: NsColors.violet.withValues(alpha: .35)),
                          borderRadius: BorderRadius.circular(24)),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: NsColors.cyan))))),
              const SizedBox(height: 24),
              Text(
                  incoming
                      ? state.text('Customer rate: $frozenCustomerRate',
                          'வாடிக்கையாளர் கட்டணம்: $frozenCustomerRate')
                      : frozenCustomerRate,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (call.ringing) ...[
                Text(
                    state.text(
                        'Ringing and waiting are free. The invitation expires automatically.',
                        'காத்திருப்பு இலவசம். அழைப்பு தானாக காலாவதியாகும்.'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (incoming) ...[
                  Text(state.text(
                      'Proposed rate: ₹$listenerHourlyRate / paid connected hour. Test estimate only.',
                      'முன்மொழியப்பட்ட விகிதம்: கட்டண இணைப்பு மணிநேரத்திற்கு ₹$listenerHourlyRate. சோதனை மதிப்பீடு மட்டுமே.')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: state.busy
                          ? null
                          : call.isVideo
                              ? () => _reviewVideoCall(context, state, call,
                                  accepting: true)
                              : () => state.transition('accept'),
                      icon: Icon(
                          call.isVideo ? Icons.videocam_outlined : Icons.call),
                      label: Text(call.isVideo
                          ? state.text('Review video invitation',
                              'வீடியோ அழைப்பை சரிபார்')
                          : state.text('Accept', 'ஏற்கவும்'))),
                  const SizedBox(height: 12),
                ],
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
                          onPressed: state.busy || state.endingLocally
                              ? null
                              : () => _reviewVideoCall(context, state, call),
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(
                              state.text('Review camera', 'கேமராவை சரிபார்')))),
                Center(
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 28),
                        decoration: BoxDecoration(
                            color: const Color(0xFF20273C),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: const Color(0xFFB997DB)),
                            boxShadow: [
                              BoxShadow(
                                  color: NsColors.violet.withValues(alpha: .12),
                                  blurRadius: 24)
                            ]),
                        child: Text(
                            durationLabel(call.connectedMs).padLeft(5, '0'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3)))),
                const SizedBox(height: 10),
                Text(
                    state.text('Server-confirmed connected time',
                        'சேவையகம் உறுதிப்படுத்திய இணைப்பு நேரம்'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
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
                const SizedBox(height: 24),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _LiveCallControl(
                          onPressed: state.endingLocally ||
                                  state.busy ||
                                  state.needsVideoConsent
                              ? null
                              : () => state.perform(state.audio.toggleMute),
                          icon: Icon(
                              state.audio.muted ? Icons.mic_off : Icons.mic),
                          label: Text(state.audio.muted
                              ? state.text('Unmute', 'ஒலியை இயக்கு')
                              : state.text('Mute', 'ஒலியை நிறுத்து'))),
                      _LiveCallControl(
                          onPressed: state.endingLocally ||
                                  state.busy ||
                                  state.needsVideoConsent
                              ? null
                              : () => state.perform(state.audio.toggleSpeaker),
                          icon: Icon(state.audio.speaker
                              ? Icons.volume_up
                              : Icons.hearing),
                          label: Text(state.audio.speaker
                              ? state.text(
                                  'Speaker on', 'ஒலிபெருக்கி இயங்குகிறது')
                              : state.text('Earpiece', 'காதொலி'))),
                    ]),
                if (call.isVideo &&
                    !state.needsVideoConsent &&
                    state.video != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                            onPressed: state.busy || state.endingLocally
                                ? null
                                : () => state.setCameraEnabled(
                                    !state.video!.cameraEnabled),
                            icon: Icon(state.video!.cameraEnabled
                                ? Icons.videocam_off_outlined
                                : Icons.videocam_outlined),
                            label: Text(state.video!.cameraEnabled
                                ? state.text(
                                    'Turn camera off', 'கேமராவை நிறுத்து')
                                : state.text(
                                    'Turn camera on', 'கேமராவை இயக்கு'))),
                        OutlinedButton.icon(
                            onPressed: state.busy ||
                                    state.endingLocally ||
                                    !state.video!.cameraEnabled
                                ? null
                                : state.switchCamera,
                            icon: const Icon(Icons.cameraswitch_outlined),
                            label: Text(
                                state.text('Switch camera', 'கேமராவை மாற்று'))),
                      ]),
                  if (!state.video!.cameraEnabled)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                            state.text(
                                'Camera off. Healthy video time and test charging are paused.',
                                'கேமரா நிறுத்தப்பட்டுள்ளது. வீடியோ இணைப்பு நேரமும் சோதனை கட்டணமும் நிறுத்தப்பட்டுள்ளன.'),
                            textAlign: TextAlign.center)),
                ],
                if (call.isVideo && state.video?.lowBandwidth == true)
                  StatusCard(
                      icon: Icons.network_check,
                      title: state.text('Reduced video quality',
                          'வீடியோ தரம் குறைக்கப்பட்டுள்ளது'),
                      message: state.text(
                          'Video quality is reduced for this connection. The video rate stays ${call.rate.coinsPerMinute} test coins / minute. You can end video and choose a new audio call.',
                          'இந்த இணைப்பிற்கு வீடியோ தரம் குறைக்கப்பட்டுள்ளது. வீடியோ விகிதம் நிமிடத்திற்கு ${call.rate.coinsPerMinute} சோதனை நாணயங்களாகவே இருக்கும். வீடியோவை முடித்து புதிய ஆடியோ அழைப்பை தேர்வு செய்யலாம்.')),
                if (call.isVideo) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: state.busy || state.endingLocally
                          ? null
                          : () => _confirmAudioFallback(context, state, call),
                      icon: const Icon(Icons.call_outlined),
                      label: Text(state.text('End video and use audio',
                          'வீடியோவை முடித்து ஆடியோவை பயன்படுத்து'))),
                ],
                const SizedBox(height: 24),
                const SizedBox(height: 16),
                Text(
                    call.isVideo
                        ? state.text(
                            'Leaving or locking the app ends this test call. No audio or video is recorded.',
                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோவும் வீடியோவும் பதிவு செய்யப்படாது.')
                        : state.text(
                            'Leaving or locking the app ends this test call. No audio is recorded.',
                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோ பதிவு செய்யப்படுவதில்லை.'),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              if (!call.isVideo || call.ringing)
                TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => showSafetyDialog(context, state, call),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                        state.text('Report or block', 'புகாரளி அல்லது தடு'))),
              const SizedBox(height: 24),
              SelectableText(
                  state.text('Call ID: ${call.id}', 'அழைப்பு எண்: ${call.id}'),
                  style: Theme.of(context).textTheme.bodySmall),
              MediaDiagnosticsButton(state: state, callId: call.id),
            ]))));
  }
}

Widget _endCallButton(BuildContext context, AppController state) =>
    FilledButton.icon(
        style: FilledButton.styleFrom(
            minimumSize: const Size(180, 60),
            shape: const StadiumBorder(),
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFFE74365)),
        onPressed: state.endingLocally ? null : () => state.transition('end'),
        icon: const Icon(Icons.call_end),
        label: Text(state.text('End call', 'அழைப்பை முடி')));

class _CallBody extends StatelessWidget {
  const _CallBody({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children)
              ])));
}

class _LiveCallControl extends StatelessWidget {
  const _LiveCallControl(
      {required this.onPressed, required this.icon, required this.label});
  final VoidCallback? onPressed;
  final Widget icon, label;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 144 : 112,
      child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onPressed == null
                        ? NsColors.surface
                        : const Color(0xFF293149),
                    border: Border.all(color: Colors.white24)),
                child: IconTheme(
                    data: IconThemeData(
                        color:
                            onPressed == null ? NsColors.muted : Colors.white,
                        size: 25),
                    child: icon)),
            const SizedBox(height: 10),
            DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                child: label),
          ])));
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

Future<void> _reviewVideoCall(
    BuildContext context, AppController state, CallSession call,
    {bool accepting = false}) async {
  final consent = await showVideoPreflight(context, state,
      rate: call.rate,
      confirmLabel: accepting
          ? state.text('Accept video call', 'வீடியோ அழைப்பை ஏற்கவும்')
          : state.text('Join video call', 'வீடியோ அழைப்பில் சேர்'));
  if (!consent || !context.mounted || state.activeCall?.id != call.id) return;
  if (accepting) {
    await state.transition('accept', cameraConsent: true);
  } else {
    await state.joinConsentedVideo();
  }
}

Future<void> _confirmAudioFallback(
    BuildContext context, AppController state, CallSession call) async {
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
  if (agreed != true || state.activeCall?.id != call.id) return;
  final wasCustomer = call.customerId == state.user?.id;
  await state.endVideoForAudio();
  if (state.hasCall || state.error != null || !navigator.mounted) return;
  if (wasCustomer) {
    await state.refresh();
    if (!navigator.mounted || state.user == null || state.hasCall) return;
    final peers = state.listeners
        .where(
            (listener) => listener.id == call.listenerId && listener.available)
        .toList();
    if (peers.isNotEmpty && !state.offline && state.error == null) {
      // Let the call-to-history redirect install its page before adding a
      // dialog; otherwise the router can remove the new quote with CallScreen.
      await WidgetsBinding.instance.endOfFrame;
      if (!navigator.mounted || state.hasCall || state.user == null) return;
      await showAudioCallConfirmation(navigator.context, state, peers.first);
      return;
    }
  }
  if (messenger.mounted) {
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
