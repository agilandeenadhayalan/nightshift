part of '../screens.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final index = switch (path) { '/history' => 1, '/profile' => 2, _ => 0 };
    return Scaffold(
        appBar: AppBar(title: const NightshiftBrand(size: 23), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ActionChip(
                avatar: const Icon(Icons.toll_rounded,
                    color: NsColors.gold, size: 18),
                label: Text(creditAmount(state.balance - state.held)),
                tooltip: state.text('Open test wallet', 'சோதனை பணப்பையைத் திற'),
                onPressed: () => context.push('/wallet'),
              )),
        ]),
        body: NightshiftBackdrop(
            child: Column(children: [
          Material(
              color: Colors.transparent,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                            state.isListener
                                ? state.text('Listener', 'கேட்பவர்')
                                : state.text('Customer', 'வாடிக்கையாளர்'),
                            style: Theme.of(context).textTheme.labelLarge),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.science_outlined, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(
                                  state.text(
                                      'TEST CREDITS · Keep the app open for calls',
                                      'சோதனை நாணயங்கள் · அழைப்புக்கு செயலியை திறந்து வைத்திருங்கள்'),
                                  style:
                                      Theme.of(context).textTheme.labelMedium))
                        ]),
                      ]))),
          if (state.busy)
            LinearProgressIndicator(
                minHeight: 2,
                semanticsLabel: state.text('Updating…', 'புதுப்பிக்கிறது…')),
          Expanded(child: child),
        ])),
        bottomNavigationBar: NavigationBar(
          height: 68,
          indicatorColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: (next) {
            final location = ['/home', '/history', '/profile'][next];
            unawaited(state.navigate(location));
            context.go(location);
          },
          destinations: [
            NavigationDestination(
                icon: Icon(state.isListener
                    ? Icons.headset_mic_outlined
                    : Icons.explore_outlined),
                label: state.isListener
                    ? state.text('Availability', 'கிடைப்பது')
                    : state.text('Discover', 'கண்டறி')),
            NavigationDestination(
                icon: Icon(state.isListener
                    ? Icons.receipt_long_outlined
                    : Icons.history),
                label: state.isListener
                    ? state.text('Earnings', 'வருமானம்')
                    : state.text('Recents', 'சமீபத்தில்')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: state.text('Profile', 'சுயவிவரம்')),
          ],
        ));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (state.snapshotLoaded) {
      return state.isListener
          ? _ListenerDashboard(state: state)
          : DirectoryScreen(state: state);
    }
    return RefreshIndicator(
        onRefresh: state.refresh,
        child: PageBody(children: [
          const ErrorNotice(),
          Text(
              state.isListener
                  ? state.text('Make room for a conversation.',
                      'உரையாடலுக்கு நேரம் ஒதுக்குங்கள்.')
                  : state.text('Who would you like to talk to?',
                      'யாருடன் பேச விரும்புகிறீர்கள்?'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          if (state.snapshotLoading)
            LoadingNotice(
                label: state.text(
                    'Loading availability…', 'கிடைக்கும் நிலை ஏற்றப்படுகிறது…'))
          else if (state.error == null)
            StatusCard(
                title: state.text('Connect to see availability',
                    'கிடைக்கும் நிலையை பார்க்க இணைக்கவும்'),
                message: state.text('Refresh to retrieve the latest status.',
                    'சமீபத்திய நிலையை பெற புதுப்பிக்கவும்.'),
                action: OutlinedButton.icon(
                    onPressed: state.refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(state.text('Refresh', 'புதுப்பி')))),
        ]));
  }
}

class _ListenerDashboard extends StatelessWidget {
  const _ListenerDashboard({required this.state});
  final AppController state;
  @override
  Widget build(BuildContext context) {
    final audioEnabled = state.listenerAudioEnabled;
    final videoEnabled = state.listenerVideoEnabled;
    final live = state.user?.online == true &&
        state.foreground &&
        !state.offline &&
        !state.hasCall &&
        (audioEnabled || videoEnabled);
    final status = state.offline
        ? state.text('Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
        : state.user?.listenerApproved != true
            ? state.text('Listener approval required', 'கேட்பவர் ஒப்புதல் தேவை')
            : state.hasCall
                ? state.text('In a call · New calls paused',
                    'அழைப்பில் உள்ளீர்கள் · புதிய அழைப்புகள் நிறுத்தப்பட்டுள்ளன')
                : live
                    ? audioEnabled && videoEnabled
                        ? state.text('Live · Accepting audio & video',
                            'நேரலையில் · ஆடியோ மற்றும் வீடியோ அழைப்புகள்')
                        : audioEnabled
                            ? state.text('Live · Audio only',
                                'நேரலையில் · ஆடியோ மட்டும்')
                            : state.text('Live · Video only',
                                'நேரலையில் · வீடியோ மட்டும்')
                    : audioEnabled || videoEnabled
                        ? state.text('Reconnecting · Calls paused',
                            'மீண்டும் இணைகிறது · அழைப்புகள் நிறுத்தப்பட்டுள்ளன')
                        : state.text(
                            'Standby · Offline', 'காத்திருப்பு · ஆஃப்லைன்');
    final earned = state.history
        .where((call) => call.listenerId == state.user?.id)
        .fold<int>(0, (sum, call) => sum + call.earningPaise);
    return RefreshIndicator(
        onRefresh: state.refreshListenerAvailability,
        child: PageBody(children: [
          const ErrorNotice(),
          Row(children: [
            NightshiftAvatar(
                name: state.user?.name ?? '',
                size: 46,
                avatarCode: state.user?.avatarCode),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.user?.name ?? '',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(state.text('Listener workspace', 'கேட்பவர் பணியிடம்'),
                      style:
                          const TextStyle(color: NsColors.muted, fontSize: 10)),
                ]))
          ]),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                  color: NsColors.violet.withAlpha(17),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: NsColors.violet.withAlpha(55))),
              child: Row(children: [
                Icon(live ? Icons.circle : Icons.pause_circle_outline,
                    size: 13, color: live ? NsColors.cyan : NsColors.muted),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(status,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)))
              ])),
          const SizedBox(height: 14),
          NightshiftSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final width =
                          MediaQuery.textScalerOf(context).scale(16) > 24
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: width,
                            child: _MediaAvailabilityTile(
                                switchKey: const ValueKey(
                                    'listener-audio-availability'),
                                icon: Icons.headset_mic_outlined,
                                title: state.text('Audio', 'ஆடியோ'),
                                label: state.text('Audio call availability',
                                    'ஆடியோ அழைப்பு கிடைப்பது'),
                                enabled: audioEnabled,
                                color: NsColors.cyan,
                                status: audioEnabled
                                    ? state.text('On', 'இயக்கம்')
                                    : state.text('Off', 'முடக்கம்'),
                                onChanged: state.canSetMediaAvailability
                                    ? (value) =>
                                        state.setMediaAvailability(audio: value)
                                    : null)),
                        SizedBox(
                            width: width,
                            child: _MediaAvailabilityTile(
                                switchKey: const ValueKey(
                                    'listener-video-availability'),
                                icon: Icons.videocam_outlined,
                                title: state.text('Video', 'வீடியோ'),
                                label: state.text('Video call availability',
                                    'வீடியோ அழைப்பு கிடைப்பது'),
                                enabled: videoEnabled,
                                color: const Color(0xFF34D399),
                                status: state.listenerVideoCapabilityLoading
                                    ? state.text('Checking…', 'சரிபார்க்கிறது…')
                                    : !state.listenerVideoSupported
                                        ? state.text(
                                            'Unavailable', 'கிடைக்கவில்லை')
                                        : videoEnabled
                                            ? state.text('On', 'இயக்கம்')
                                            : state.text('Off', 'முடக்கம்'),
                                onChanged: state.canSetMediaAvailability &&
                                        state.listenerVideoSupported
                                    ? (value) =>
                                        state.setMediaAvailability(video: value)
                                    : null)),
                      ]);
                    }),
                    const SizedBox(height: 14),
                    if (state.availabilityUpdating)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                              state.text('Saving availability…',
                                  'கிடைக்கும் நிலை சேமிக்கப்படுகிறது…'),
                              style: const TextStyle(
                                  color: NsColors.cyan, fontSize: 12))),
                    Text(
                        state.text(
                            'Keep the app open for live calls. Camera permission is requested for each video call.',
                            'நேரடி அழைப்புகளுக்கு செயலியைத் திறந்து வையுங்கள். ஒவ்வொரு வீடியோ அழைப்பிற்கும் கேமரா அனுமதி கேட்கப்படும்.'),
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 11)),
                  ])),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: NsColors.violet.withAlpha(40)),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF15192D), Color(0xFF292147)])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        state.text(
                            'Earnings & calls', 'வருமானம் மற்றும் அழைப்புகள்'),
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: Text(
                              state.historyLoaded
                                  ? '₹${(earned / 100).toStringAsFixed(2)}'
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip:
                              state.text('View earnings', 'வருமானத்தைப் பார்'),
                          onPressed: () => context.push('/earnings'),
                          icon: const Icon(Icons.arrow_forward,
                              color: NsColors.violet)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                        state.text(
                            'Test earnings in loaded history · No cash payouts',
                            'ஏற்றப்பட்ட வரலாற்றின் சோதனை வருமானம் · பணம் வழங்கப்படாது'),
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 10)),
                  ])),
          const SizedBox(height: 14),
          InvitationSettings(controller: state),
          const SizedBox(height: 14),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                  state.text('Proposed listener rate',
                      'முன்மொழியப்பட்ட கேட்பவர் விகிதம்'),
                  style: const TextStyle(fontSize: 13)),
              children: [
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                        state.text(
                            '₹500 per 3,600 paid connected seconds. Six paid minutes = ₹50. These are test estimates, not cash earnings. Ringing, waiting and reconnect gaps earn nothing.',
                            '3,600 கட்டண இணைப்பு விநாடிகளுக்கு ₹500. ஆறு கட்டண நிமிடங்கள் = ₹50. இது சோதனை மதிப்பீடு; உண்மையான பணம் அல்ல. காத்திருப்பு மற்றும் இணைப்பு இடைவெளிக்கு வருமானம் இல்லை.'),
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 12)))
              ]),
        ]));
  }
}

class _MediaAvailabilityTile extends StatelessWidget {
  const _MediaAvailabilityTile(
      {required this.switchKey,
      required this.icon,
      required this.title,
      required this.label,
      required this.status,
      required this.enabled,
      required this.color,
      required this.onChanged});
  final Key switchKey;
  final IconData icon;
  final String title, label, status;
  final bool enabled;
  final Color color;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: NsColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  enabled ? color.withAlpha(75) : Colors.white.withAlpha(14))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(width: 8),
          Icon(icon, color: enabled ? color : NsColors.muted, size: 22),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Text(status,
                  style: TextStyle(
                      color: enabled ? color : NsColors.muted, fontSize: 11))),
          Semantics(
              label: label,
              child: Switch(
                  key: switchKey,
                  value: enabled,
                  activeColor: Colors.white,
                  activeTrackColor: color,
                  onChanged: onChanged)),
        ])
      ]));
}

Future<void> showAudioCallConfirmation(
    BuildContext context, AppController state, ListenerProfile listener) async {
  final owner = state.accountIdentity;
  final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final available = owner == state.accountIdentity &&
                state.canCallListener(listener) &&
                !state.busy;
            return AlertDialog(
                title: Text(state.text(
                    'Call ${listener.name}', '${listener.name} அழைக்கவும்')),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${testRateLabel(state, listener.rate)}\n\n${testTariffDescription(state, listener.rate)}\n\n${state.text('Both phones must keep the app open.', 'இரு செயலிகளும் திறந்திருப்பது அவசியம்.')}'),
                      if (!available)
                        Text(state.text(
                            'Listener is no longer available. Refresh before calling.',
                            'கேட்பவர் தற்போது கிடைக்கவில்லை. அழைப்பதற்கு முன் புதுப்பிக்கவும்.')),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(state.text('Cancel', 'ரத்து'))),
                  FilledButton(
                      onPressed:
                          available ? () => Navigator.pop(context, true) : null,
                      child: Text(state.text(
                          'Start audio call', 'ஆடியோ அழைப்பைத் தொடங்கு'))),
                ]);
          }));
  if (agreed == true &&
      context.mounted &&
      owner == state.accountIdentity &&
      state.canCallListener(listener)) {
    await state.startCall(listener);
  }
}
