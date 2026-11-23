import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design_system.dart';

/// Review-only presentation state. It never changes accounts, availability or money.
class HomeDesignState {
  const HomeDesignState(
      {this.language = 'Tamil',
      this.mood = 'Just talk',
      this.video = false,
      this.offer = 0,
      this.favorite = false,
      this.online = false,
      this.avatar = 0,
      this.nickname = ''});
  final String language, mood, nickname;
  final bool video, favorite, online;
  final int offer, avatar;
  HomeDesignState copyWith(
          {String? language,
          String? mood,
          String? nickname,
          bool? video,
          bool? favorite,
          bool? online,
          int? offer,
          int? avatar}) =>
      HomeDesignState(
          language: language ?? this.language,
          mood: mood ?? this.mood,
          nickname: nickname ?? this.nickname,
          video: video ?? this.video,
          favorite: favorite ?? this.favorite,
          online: online ?? this.online,
          offer: offer ?? this.offer,
          avatar: avatar ?? this.avatar);
}

class HomeDesignController extends StateNotifier<HomeDesignState> {
  HomeDesignController() : super(const HomeDesignState());
  void language(String value) => state = state.copyWith(language: value);
  void mood(String value) => state = state.copyWith(mood: value);
  void video(bool value) => state = state.copyWith(video: value);
  void offer(int value) => state = state.copyWith(offer: value);
  void favorite() => state = state.copyWith(favorite: !state.favorite);
  void online(bool value) => state = state.copyWith(online: value);
  void avatar(int value) => state = state.copyWith(avatar: value);
  void nickname(String value) => state = state.copyWith(nickname: value);
}

final homeDesignProvider = StateNotifierProvider.autoDispose
    .family<HomeDesignController, HomeDesignState, int>(
        (ref, id) => HomeDesignController());

class HomeDesignScreen extends ConsumerWidget {
  const HomeDesignScreen({super.key, required this.designId});
  final int designId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDesignProvider(designId));
    final actions = ref.read(homeDesignProvider(designId).notifier);
    final profile = [17, 20, 22].contains(designId);
    final history = [24, 31].contains(designId);
    final listener = [20, 22, 24, 29].contains(designId);
    final offer = [43, 45].contains(designId);
    return Scaffold(
      appBar: AppBar(title: const NightshiftBrand(size: 22), actions: [
        const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
                avatar: Icon(Icons.toll, color: NsColors.gold),
                label: Text('Preview'))),
      ]),
      body: NightshiftBackdrop(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        if (profile)
          ..._profile(context, state, actions, listener)
        else if (history)
          ..._history(context, listener)
        else if (designId == 29)
          ..._availability(context, state, actions)
        else if (designId == 41)
          ..._filters(context, state, actions)
        else if (offer)
          ..._offer(context)
        else
          ..._feed(context, state, actions),
      ])),
      bottomNavigationBar: NavigationBar(
          selectedIndex: profile
              ? 2
              : history
                  ? 1
                  : 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.history_rounded), label: 'Recents'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ]),
    );
  }

  List<Widget> _feed(BuildContext context, HomeDesignState state,
      HomeDesignController actions) {
    final loading = [11, 32].contains(designId);
    return [
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                  colors: [Color(0xFF402073), Color(0xFF1D2143)])),
          child: Row(children: [
            const Icon(Icons.nightlight_round, color: NsColors.gold, size: 30),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Find your conversation',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('One-to-one · Customer & Listener',
                      style: TextStyle(color: NsColors.muted, fontSize: 12)),
                ]))
          ])),
      const SizedBox(height: 22),
      if (loading) ...[
        const Text('Finding available Listeners…'),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: NightshiftSurface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                        height: designId == 11 ? 180 : 120,
                        decoration: BoxDecoration(
                            color: NsColors.violet.withAlpha(22),
                            borderRadius: BorderRadius.circular(16))),
                    const SizedBox(height: 16),
                    _skeleton(140),
                    const SizedBox(height: 10),
                    _skeleton(220),
                  ]))),
      ] else ...[
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF35205B), Color(0xFF13162B)])),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Chip(
                            label: Text('Sample', softWrap: true),
                            avatar: Icon(Icons.circle,
                                color: NsColors.cyan, size: 10)),
                        IconButton(
                            tooltip: 'Save preview favorite',
                            onPressed: actions.favorite,
                            icon: Icon(
                                state.favorite
                                    ? Icons.favorite
                                    : Icons.favorite_outline,
                                color: NsColors.cyan)),
                      ]),
                  const SizedBox(height: 24),
                  const Center(
                      child: NightshiftAvatar(
                          name: 'Sample Listener', size: 150, listener: true)),
                  const SizedBox(height: 28),
                  Text('A little time to talk.',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Tamil · English',
                      style: TextStyle(color: NsColors.muted)),
                  const SizedBox(height: 14),
                  const Wrap(spacing: 8, runSpacing: 6, children: [
                    Chip(label: Text('Music')),
                    Chip(label: Text('Everyday life')),
                    Chip(label: Text('Just talk'))
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                      'Preview only. Live availability and prices come from the server.',
                      style: TextStyle(color: NsColors.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  const FilledButton(
                      onPressed: null, child: Text('Start a conversation')),
                ])),
        if ([34, 39].contains(designId)) ...[
          const SizedBox(height: 18),
          NightshiftSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Coin offers',
                    style: TextStyle(
                        color: NsColors.gold, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.toll_rounded,
                      color: NsColors.gold, size: 44),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(
                          'Offer design ${state.offer + 1} of 5\nPurchases are not available.')),
                  IconButton(
                      tooltip: 'Next offer design',
                      onPressed: () => actions.offer((state.offer + 1) % 5),
                      icon: const Icon(Icons.chevron_right))
                ]),
              ])),
        ],
        const SizedBox(height: 20),
        const FilledButton(
            onPressed: null, child: Text('Find me a Listener ✨')),
      ],
    ];
  }

  Widget _skeleton(double width) => Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
          color: NsColors.violet.withAlpha(35),
          borderRadius: BorderRadius.circular(8)));

  List<Widget> _filters(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        const Icon(Icons.auto_awesome, size: 46, color: NsColors.cyan),
        const SizedBox(height: 20),
        Text('Find your kind of conversation',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 26),
        const Text('Preferred language'),
        const SizedBox(height: 10),
        Wrap(spacing: 10, children: [
          for (final language in ['Tamil', 'English'])
            ChoiceChip(
                label: Text(language),
                selected: state.language == language,
                onSelected: (_) => actions.language(language))
        ]),
        const SizedBox(height: 26),
        const Text('Vibe & mood'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final mood in ['Just talk', 'Music', 'Share my day', 'Unwind'])
            ChoiceChip(
                label: Text(mood),
                selected: state.mood == mood,
                onSelected: (_) => actions.mood(mood))
        ]),
        const SizedBox(height: 26),
        const Text('Call mode'),
        const SizedBox(height: 10),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(
              value: false, label: Text('Audio'), icon: Icon(Icons.call)),
          ButtonSegment(
              value: true, label: Text('Video'), icon: Icon(Icons.videocam))
        ], selected: {
          state.video
        }, onSelectionChanged: (v) => actions.video(v.single)),
        const SizedBox(height: 32),
        const FilledButton(onPressed: null, child: Text('Find a Listener')),
        const SizedBox(height: 12),
        const Text(
            'Preview choices only. Live matching keeps its existing consent and eligibility checks.',
            style: TextStyle(color: NsColors.muted)),
      ];

  List<Widget> _offer(BuildContext context) => [
        const SizedBox(height: 26),
        Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: designId == 43
                        ? [const Color(0xFF45265C), const Color(0xFF221139)]
                        : [const Color(0xFF16754B), const Color(0xFF072E27)])),
            child: Column(children: [
              const Text('OFFER DESIGN'),
              const SizedBox(height: 14),
              Text(designId == 43 ? '₹800 off' : '₹2,000 off',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 30),
              const Icon(Icons.toll_rounded, size: 96, color: NsColors.gold),
              const SizedBox(height: 24),
              const Text(
                  'Sample offer from the supplied design.\nNo approved price or purchasable pack.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 26),
              const FilledButton(
                  onPressed: null, child: Text('Offers unavailable'))
            ])),
      ];

  List<Widget> _profile(BuildContext context, HomeDesignState state,
          HomeDesignController actions, bool listener) =>
      [
        const SizedBox(height: 18),
        Center(
            child: NightshiftAvatar(
                name: 'Preview profile', size: 118, listener: listener)),
        const SizedBox(height: 20),
        Text(listener ? 'Listener profile' : 'Customer profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        const Text('Tamil · English',
            textAlign: TextAlign.center,
            style: TextStyle(color: NsColors.muted)),
        const SizedBox(height: 26),
        if (designId == 22) ...[
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Nickname', hintText: 'Choose a display name'),
              onChanged: actions.nickname),
          const SizedBox(height: 20),
          const Text('Choose an avatar'),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 8; i++)
              ChoiceChip(
                  avatar: Icon([
                    Icons.person,
                    Icons.nightlight,
                    Icons.star,
                    Icons.music_note
                  ][i % 4]),
                  label: Text('${i + 1}'),
                  selected: state.avatar == i,
                  onSelected: (_) => actions.avatar(i))
          ]),
          const SizedBox(height: 24),
          const FilledButton(
              onPressed: null, child: Text('Profile editing unavailable')),
          const Text('This is a local draft. It does not change your account.',
              style: TextStyle(color: NsColors.muted)),
        ] else ...[
          NightshiftSurface(
              child: Row(children: [
            Icon(
                listener
                    ? Icons.diamond_outlined
                    : Icons.account_balance_wallet_outlined,
                size: 36,
                color: NsColors.gold),
            const SizedBox(width: 16),
            Expanded(
                child: Text(listener
                    ? 'Earnings & withdrawal history'
                    : 'Wallet & coins')),
            const Icon(Icons.chevron_right)
          ])),
          const SizedBox(height: 20),
          for (final entry in [
            (Icons.edit_outlined, 'Edit profile'),
            (Icons.translate, 'App language'),
            (Icons.help_outline, 'Help & support'),
            (Icons.privacy_tip_outlined, 'Privacy & account'),
            (Icons.logout, 'Sign out')
          ])
            ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                leading: Icon(entry.$1, color: NsColors.violet),
                title: Text(entry.$2),
                trailing: const Icon(Icons.chevron_right)),
        ],
      ];

  List<Widget> _history(BuildContext context, bool listener) => [
        Text(listener ? 'Call logs & earnings' : 'Recent sessions',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        if (listener)
          const NightshiftSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('TEST EARNINGS', style: TextStyle(color: NsColors.gold)),
                SizedBox(height: 12),
                Text('Server-confirmed amounts',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('No withdrawable cash balance is configured.'),
              ])),
        const SizedBox(height: 24),
        const Text('Layout preview'),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NightshiftSurface(
                  child: Row(children: [
                NightshiftAvatar(
                    name: 'Sample ${i + 1}', size: 50, listener: !listener),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Sample conversation ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Example row · no real call',
                          style:
                              TextStyle(color: NsColors.muted, fontSize: 12)),
                    ])),
                Icon(i.isEven ? Icons.call_outlined : Icons.videocam_outlined,
                    color: NsColors.cyan)
              ]))),
      ];

  List<Widget> _availability(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        const Center(
            child:
                NightshiftAvatar(name: 'Listener', size: 112, listener: true)),
        const SizedBox(height: 22),
        Text('Make room for a conversation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        NightshiftSurface(
            child: Column(children: [
          Icon(
              state.online
                  ? Icons.radio_button_checked
                  : Icons.pause_circle_outline,
              color: NsColors.cyan,
              size: 40),
          const SizedBox(height: 12),
          Text(state.online ? 'Online appearance' : 'Offline appearance',
              style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
              title: const Text('Preview availability'),
              value: state.online,
              onChanged: actions.online),
          const Text(
              'This switch only changes this design preview. Your real availability is unchanged.',
              style: TextStyle(color: NsColors.muted)),
        ])),
        const SizedBox(height: 22),
        const NightshiftSurface(
            child: Column(children: [
          Icon(Icons.diamond_outlined, color: NsColors.gold, size: 32),
          SizedBox(height: 12),
          Text('Audio & video controls'),
          SizedBox(height: 8),
          Text('Real calls use your approved permissions and server state.'),
        ])),
      ];
}
