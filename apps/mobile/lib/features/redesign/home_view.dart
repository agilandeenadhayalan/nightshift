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
    final online = state.user?.online == true;
    return RefreshIndicator(
        onRefresh: state.refresh,
        child: PageBody(children: [
          const ErrorNotice(),
          Row(children: [
            NightshiftAvatar(
                name: state.user?.name ?? '', size: 62, listener: true),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.user?.name ?? '',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(state.text('Listener workspace', 'கேட்பவர் பணியிடம்'),
                      style: const TextStyle(color: NsColors.muted)),
                ]))
          ]),
          const SizedBox(height: 24),
          Text(
              state.text('Make room for a conversation.',
                  'உரையாடலுக்கு நேரம் ஒதுக்குங்கள்.'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          NightshiftSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(children: [
                  Icon(
                      online
                          ? Icons.radio_button_checked
                          : Icons.pause_circle_outline,
                      color: online ? NsColors.cyan : NsColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          state.offline
                              ? state.text('Connection unavailable',
                                  'இணைப்பு கிடைக்கவில்லை')
                              : online
                                  ? state.text('You are online',
                                      'நீங்கள் ஆன்லைனில் உள்ளீர்கள்')
                                  : state.text('You are offline',
                                      'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள்'),
                          style: Theme.of(context).textTheme.titleMedium))
                ]),
                const SizedBox(height: 22),
                FilledButton.icon(
                    onPressed: state.busy || state.offline
                        ? null
                        : () => state.setOnline(!online),
                    icon: Icon(online ? Icons.pause : Icons.headset_mic),
                    label: Text(online
                        ? state.text('Go offline', 'ஆஃப்லைன் செல்லவும்')
                        : state.text('Go online', 'ஆன்லைன் செல்லவும்'))),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  final width = MediaQuery.textScalerOf(context).scale(16) > 24
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(
                        width: width,
                        child: _MediaAvailabilityTile(
                            icon: Icons.headset_mic_outlined,
                            title: state.text('Audio', 'ஆடியோ'),
                            message: state.text(
                                'Your voice, a real conversation',
                                'உங்கள் குரல், உண்மையான உரையாடல்'))),
                    SizedBox(
                        width: width,
                        child: _MediaAvailabilityTile(
                            icon: Icons.videocam_outlined,
                            title: state.text('Video', 'வீடியோ'),
                            message: state.text('Camera consent for each call',
                                'ஒவ்வொரு அழைப்பிற்கும் கேமரா ஒப்புதல்'))),
                  ]);
                }),
                const SizedBox(height: 20),
                const SizedBox(height: 12),
                Text(
                    state.text(
                        'Keep the app open for live calls. Optional background audio invitations depend on your enabled invitation setting. Reconnect gaps do not earn test credits.',
                        'நேரடி அழைப்புகளுக்கு செயலியைத் திறந்து வைத்திருங்கள். பின்னணி ஆடியோ அழைப்பிதழ்கள் உங்கள் அறிவிப்பு அமைப்பைப் பொறுத்தவை. மீண்டும் இணையும் இடைவெளிக்கு சோதனை வருமானம் இல்லை.'),
                    style:
                        const TextStyle(color: NsColors.muted, fontSize: 12)),
              ])),
          const SizedBox(height: 20),
          NightshiftSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Icon(Icons.diamond_outlined,
                    color: NsColors.gold, size: 32),
                const SizedBox(height: 12),
                Text(
                    state.text(
                        'Earnings & calls', 'வருமானம் மற்றும் அழைப்புகள்'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(state.text(
                    'Review your server-confirmed test settlements.',
                    'சேவையகம் உறுதிப்படுத்திய சோதனை வருமானத்தைப் பாருங்கள்.')),
                TextButton.icon(
                    onPressed: () => context.push('/earnings'),
                    icon: const Icon(Icons.arrow_forward),
                    label:
                        Text(state.text('View earnings', 'வருமானத்தைப் பார்'))),
              ])),
          const SizedBox(height: 20),
          InvitationSettings(controller: state),
          const SizedBox(height: 12),
          Text(
              state.text(
                  'Proposed listener rate', 'முன்மொழியப்பட்ட கேட்பவர் விகிதம்'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              state.text(
                  '₹500 per 3,600 paid connected seconds. Six paid minutes = ₹50. These are test estimates, not cash earnings. Ringing, waiting and reconnect gaps earn nothing.',
                  '3,600 கட்டண இணைப்பு விநாடிகளுக்கு ₹500. ஆறு கட்டண நிமிடங்கள் = ₹50. இது சோதனை மதிப்பீடு; உண்மையான பணம் அல்ல. காத்திருப்பு மற்றும் இணைப்பு இடைவெளிக்கு வருமானம் இல்லை.'),
              style: const TextStyle(color: NsColors.muted)),
        ]));
  }
}

class _MediaAvailabilityTile extends StatelessWidget {
  const _MediaAvailabilityTile(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: NsColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Icon(icon, color: NsColors.cyan, size: 34),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.muted, fontSize: 12))
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
