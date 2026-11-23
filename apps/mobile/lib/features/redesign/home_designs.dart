import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design_system.dart';
import 'home_components.dart';
import 'call_designs.dart';
import 'commerce_designs.dart';

/// Review-only presentation state. It never changes accounts, availability or money.
class HomeDesignState {
  const HomeDesignState(
      {this.language = 'Tamil',
      this.mood = 'Just talk',
      this.video = false,
      this.offer = 0,
      this.favorite = false,
      this.favorites = const {},
      this.online = false,
      this.avatar = 0,
      this.nickname = ''});
  final String language, mood, nickname;
  final bool video, favorite, online;
  final Set<int> favorites;
  final int offer, avatar;
  HomeDesignState copyWith(
          {String? language,
          String? mood,
          String? nickname,
          bool? video,
          bool? favorite,
          Set<int>? favorites,
          bool? online,
          int? offer,
          int? avatar}) =>
      HomeDesignState(
          language: language ?? this.language,
          mood: mood ?? this.mood,
          nickname: nickname ?? this.nickname,
          video: video ?? this.video,
          favorite: favorite ?? this.favorite,
          favorites: favorites ?? this.favorites,
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
  void favorite([int index = 0]) {
    final values = {...state.favorites};
    if (!values.add(index)) values.remove(index);
    state = state.copyWith(favorites: values, favorite: values.contains(0));
  }

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
  String _asset(int index, {bool male = false}) =>
      'assets/avatars/${male ? 'male' : 'female'}/avatar_${index.toString().padLeft(2, '0')}.png';
  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  void _sheet(BuildContext context, String title, Widget child) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 18),
                        child
                      ]))));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeDesignProvider(designId));
    final actions = ref.read(homeDesignProvider(designId).notifier);
    final profile = [17, 20, 22].contains(designId);
    final history = [24, 31].contains(designId);
    final listener = [20, 22, 24, 29].contains(designId);
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D17),
      appBar: AppBar(
          toolbarHeight: 56,
          titleSpacing: 16,
          title: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: NightshiftBrand(size: 22)),
          bottom: largeText
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(24),
                  child: Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: _PreviewBadge()))
              : null,
          actions: [
            if (!largeText) ...[
              const _PreviewBadge(),
              const SizedBox(width: 8),
            ],
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _open(
                        context,
                        CommerceDesignScreen(
                            designId: listener ? 10 : 15, preview: true)),
                    child: _pill(listener ? '₹20.35' : '133',
                        Icons.toll_rounded, NsColors.gold))),
          ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (profile)
              ..._profile(context, state, actions, listener)
            else if (history)
              ..._history(context, listener)
            else if (designId == 29)
              ..._availability(context, state, actions)
            else if (designId == 41)
              ..._filters(context, state, actions)
            else if ([43, 45].contains(designId))
              ..._offer(context, state, actions)
            else
              ..._feed(context, state, actions),
          ]),
      bottomNavigationBar: _navigation(
          context,
          profile
              ? 2
              : history
                  ? 1
                  : 0,
          listener),
    );
  }

  Widget _navigation(BuildContext context, int index, bool listener) =>
      SafeArea(
          top: false,
          child: Container(
              decoration: const BoxDecoration(
                  color: Color(0xFF0B0D17),
                  border: Border(top: BorderSide(color: Color(0xFF202438)))),
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                      child: TextButton(
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              foregroundColor:
                                  i == index ? Colors.white : NsColors.muted),
                          onPressed: i == index
                              ? null
                              : () => _open(
                                  context,
                                  HomeDesignScreen(
                                      designId: [
                                    listener ? 29 : 44,
                                    listener ? 24 : 31,
                                    listener ? 20 : 17
                                  ][i])),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                [
                                  Icons.home_rounded,
                                  Icons.history_rounded,
                                  Icons.person_outline
                                ][i],
                                color:
                                    i == index ? Colors.white : NsColors.muted,
                                size: 23),
                            const SizedBox(height: 4),
                            Text(
                                [
                                  listener ? 'Home' : 'Home',
                                  listener ? 'Call logs' : 'Recents',
                                  'Profile'
                                ][i],
                                style: TextStyle(
                                    fontSize: 10,
                                    color: i == index
                                        ? Colors.white
                                        : NsColors.muted)),
                            const SizedBox(height: 4),
                            Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == index
                                        ? NsColors.cyan
                                        : Colors.transparent))
                          ])))
              ])));

  Widget _pill(String text, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withAlpha(17),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withAlpha(70))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)))
      ]));

  Widget _banner(BuildContext context, HomeDesignState state,
      HomeDesignController actions) {
    final offers = [34, 39].contains(designId);
    return NightshiftFeatureBanner(
        compact: true,
        title: offers
            ? [
                'Make more time to talk',
                'A little extra connection',
                'Your next conversation'
              ][state.offer % 3]
            : 'Play games on call',
        actionLabel: offers ? 'SAMPLE COIN OFFERS' : 'EXPLORE TOGETHER',
        onPressed: offers
            ? () => actions.offer((state.offer + 1) % 3)
            : () => _open(
                context, const CallDesignScreen(designId: 33, preview: true)),
        page: state.offer % 3,
        pageCount: 3,
        trailing: Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            NightshiftAvatar(
                name: 'Sample friend', assetPath: _asset(1), size: 30),
            NightshiftAvatar(
                name: 'Sample friend',
                assetPath: _asset(1, male: true),
                size: 30)
          ]),
          IconButton(
              tooltip: offers ? 'Next offer design' : 'Explore game preview',
              onPressed: offers
                  ? () => actions.offer((state.offer + 1) % 3)
                  : () => _open(context,
                      const CallDesignScreen(designId: 33, preview: true)),
              icon: Icon(offers ? Icons.chevron_right : Icons.casino_outlined,
                  color: NsColors.cyan))
        ]));
  }

  List<Widget> _feed(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        _banner(context, state, actions),
        const SizedBox(height: 16),
        if ([11, 32].contains(designId)) ...[
          NightshiftFeedSkeleton(
              label: 'Finding available Listeners…', compact: designId == 32),
        ] else ...[
          if (designId == 6)
            _portraitCard(context, state, actions, 0, hero: true)
          else ...[
            Row(children: [
              const Expanded(
                  child: Text('Find your conversation',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton.icon(
                  onPressed: () =>
                      _open(context, const HomeDesignScreen(designId: 41)),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Filters', style: TextStyle(fontSize: 11)))
            ]),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final columns =
                  MediaQuery.textScalerOf(context).scale(12) > 18 ? 1 : 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                      width: columns == 1 ? c.maxWidth : (c.maxWidth - 12) / 2,
                      child: _portraitCard(context, state, actions, i))
              ]);
            }),
          ],
          const SizedBox(height: 14),
          _matchDock(context),
        ],
      ];

  Widget _portraitCard(BuildContext context, HomeDesignState state,
      HomeDesignController actions, int index,
      {bool hero = false}) {
    final name = ['Maya', 'Nila', 'Ananya', 'Meera'][index];
    return NightshiftPortraitCard(
        name: name,
        assetPath: _asset(index + 1),
        languages: index.isEven ? 'Tamil · English' : 'English · Tamil',
        status: 'ONLINE',
        available: true,
        rateLabel: '60 coins / min',
        hero: hero,
        favorite: state.favorites.contains(index),
        favoriteLabel:
            state.favorites.contains(index) ? 'Remove $name' : 'Save $name',
        onFavorite: () => actions.favorite(index),
        actions: [
          Align(
              alignment: Alignment.centerRight,
              child: IconButton.filled(
                  tooltip: 'Preview call with $name',
                  style: IconButton.styleFrom(
                      backgroundColor: NsColors.cyan,
                      foregroundColor: NsColors.background),
                  onPressed: () => _open(context,
                      const CallDesignScreen(designId: 50, preview: true)),
                  icon: const Icon(Icons.call, size: 18)))
        ]);
  }

  Widget _matchDock(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [
            Color(0xFF7C3AED),
            Color(0xFF6366F1),
            Color(0xFF4F46E5)
          ])),
      child: Row(children: [
        const Icon(Icons.auto_awesome, size: 21, color: NsColors.gold),
        const SizedBox(width: 9),
        const Expanded(
            child: Text('Find me the right conversation',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        IconButton.filled(
            tooltip: 'Audio match preview',
            style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: NsColors.background),
            onPressed: () =>
                _open(context, const HomeDesignScreen(designId: 41)),
            icon: const Icon(Icons.call, size: 19)),
        IconButton(
            tooltip: 'Video preview',
            onPressed: () => _open(
                context, const CallDesignScreen(designId: 52, preview: true)),
            icon: const Icon(Icons.videocam, size: 21))
      ]));

  List<Widget> _profile(BuildContext context, HomeDesignState state,
          HomeDesignController actions, bool listener) =>
      [
        NightshiftProfileHero(
            name: state.nickname.isNotEmpty
                ? state.nickname
                : listener
                    ? 'Priya Sharma'
                    : 'Arjun',
            assetPath: _asset(state.avatar + 1, male: !listener),
            subtitle: listener ? '@priya_270' : '@arjun_090',
            roleLabel:
                listener ? 'Listener · ★ 4.9' : 'Customer · Joined Nov 2026',
            roleIcon: listener ? Icons.headset_mic : Icons.person_outline,
            editLabel: 'Edit preview profile',
            onEdit: () => _open(context, const HomeDesignScreen(designId: 22)),
            footer: listener
                ? null
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF22212A),
                        borderRadius: BorderRadius.circular(17)),
                    child: LayoutBuilder(builder: (context, constraints) {
                      const balance = Row(children: [
                        Icon(Icons.toll_rounded,
                            color: NsColors.gold, size: 30),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('133 Coins',
                                style: TextStyle(
                                    color: NsColors.gold,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800))),
                      ]);
                      final action = TextButton(
                          onPressed: () => _open(
                              context,
                              const CommerceDesignScreen(
                                  designId: 15, preview: true)),
                          child: const Text('+ Recharge'));
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              balance,
                              const SizedBox(height: 6),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: action)
                            ]);
                      }
                      return Row(
                          children: [const Expanded(child: balance), action]);
                    }))),
        const SizedBox(height: 14),
        if (designId == 22) ...[
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Nickname', hintText: 'Choose a display name'),
              onChanged: actions.nickname),
          const SizedBox(height: 18),
          const Text('Choose an avatar',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < 8; i++)
              InkWell(
                  onTap: () => actions.avatar(i),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: state.avatar == i
                                  ? NsColors.cyan
                                  : Colors.transparent,
                              width: 2)),
                      child: NightshiftAvatar(
                          name: 'Avatar ${i + 1}',
                          assetPath: _asset(i + 1),
                          size: 58)))
          ]),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: () => _sheet(context, 'Preview saved',
                  const Text('Your local design choices are ready to review.')),
              child: const Text('Save preview'))
        ] else ...[
          NightshiftModeCard(
              title: listener ? 'Switch to Customer' : 'Become a Listener',
              subtitle: listener
                  ? 'Find a conversation, at your pace'
                  : 'Good conversations start with listening',
              icon: Icons.headset_mic_outlined,
              onTap: () => listener
                  ? _open(context, const HomeDesignScreen(designId: 6))
                  : _sheet(
                      context,
                      'Become a Listener',
                      const Text(
                          'Discover one-to-one conversations in Tamil and English.'))),
          const SizedBox(height: 14),
          Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: const Color(0xFF171923),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10)),
              child: Column(children: [
                _menu(
                    Icons.account_balance_wallet_outlined,
                    'Wallet',
                    () => _open(
                        context,
                        CommerceDesignScreen(
                            designId: listener ? 10 : 15, preview: true)),
                    value: listener ? '1,250 diamonds' : '133 Coins'),
                _menu(
                    Icons.receipt_long_outlined,
                    'Transactions',
                    () => _open(context,
                        HomeDesignScreen(designId: listener ? 24 : 31))),
                _menu(
                    Icons.translate,
                    'Language Settings',
                    () => _sheet(
                        context,
                        'App language',
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          for (final language in ['English', 'தமிழ்'])
                            ListTile(
                                title: Text(language),
                                leading: const Icon(Icons.language),
                                onTap: () {
                                  actions.language(language == 'தமிழ்'
                                      ? 'Tamil'
                                      : 'English');
                                  Navigator.pop(context);
                                })
                        ])),
                    value: state.language),
                _menu(
                    Icons.help_outline,
                    'Help & Support',
                    () => _open(
                        context,
                        const CommerceDesignScreen(
                            designId: 35, preview: true))),
                _menu(Icons.settings_outlined, 'Account Settings',
                    () => _open(context, const HomeDesignScreen(designId: 22)),
                    last: true),
              ])),
          const SizedBox(height: 14),
          Container(
              decoration: BoxDecoration(
                  color: const Color(0xFF171923),
                  borderRadius: BorderRadius.circular(20)),
              child: _menu(
                  Icons.logout,
                  'Log Out',
                  () => _sheet(context, 'Design preview',
                      const Text('Your signed-in account is unchanged.')),
                  color: const Color(0xFFF43F5E),
                  last: true)),
        ]
      ];

  Widget _menu(IconData icon, String title, VoidCallback action,
          {String? value, Color color = NsColors.muted, bool last = false}) =>
      Column(children: [
        ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white10)),
                child: Icon(icon, size: 18, color: color)),
            title: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color == NsColors.muted ? Colors.white : color)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (value != null) ...[
                Text(value,
                    style: const TextStyle(fontSize: 10, color: NsColors.gold)),
                const SizedBox(width: 8)
              ],
              const Icon(Icons.chevron_right, size: 17, color: NsColors.muted)
            ]),
            onTap: action),
        if (!last) const Divider(height: 1, color: Color(0xFF242738))
      ]);

  List<Widget> _history(BuildContext context, bool listener) => [
        Row(children: [
          Expanded(
              child: Text(listener ? 'Call Logs & Earnings' : 'Recent sessions',
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'History filters',
              onPressed: () => _sheet(context, 'Call type',
                  const Text('All calls · Audio · Video')),
              icon: const Icon(Icons.tune, size: 20))
        ]),
        const SizedBox(height: 14),
        if (listener) ...[
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF282249), Color(0xFF131625)])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TODAY'S EARNINGS",
                        style: TextStyle(
                            fontSize: 10,
                            color: NsColors.muted,
                            letterSpacing: 1)),
                    const SizedBox(height: 10),
                    const Text('₹20.24',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('2 sessions  ·  18 mins on call',
                        style: TextStyle(fontSize: 11, color: NsColors.muted)),
                    const SizedBox(height: 15),
                    Row(children: [
                      Expanded(
                          child:
                              _pill('Audio ₹12.24', Icons.call, NsColors.cyan)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: _pill(
                              'Video ₹8.00', Icons.videocam, NsColors.violet))
                    ])
                  ])),
          const SizedBox(height: 18)
        ],
        const Text('TODAY',
            style: TextStyle(
                fontSize: 10, letterSpacing: 1.5, color: NsColors.muted)),
        const SizedBox(height: 10),
        for (var i = 0; i < 5; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: NightshiftSessionSummary(
                  name: listener
                      ? ['Arjun', 'Rohan', 'Dev', 'Vikram', 'Kiran'][i]
                      : ['Maya', 'Nila', 'Ananya', 'Meera', 'Kavya'][i],
                  assetPath: _asset(i + 1, male: listener),
                  description: i == 2
                      ? 'Missed call'
                      : '${i.isEven ? 'Audio' : 'Video'} · 0${i + 2}:24',
                  date: 'Today, ${10 + i}:24 AM',
                  amount: listener
                      ? i == 2
                          ? '—'
                          : '+₹${i + 3}.50'
                      : null,
                  video: i.isOdd,
                  missed: i == 2,
                  action: IconButton(
                      tooltip: 'Preview recent conversation',
                      onPressed: () => _open(context,
                          const CallDesignScreen(designId: 50, preview: true)),
                      icon: const Icon(Icons.chevron_right,
                          size: 20, color: NsColors.muted))))
      ];

  List<Widget> _availability(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        _pill(
            state.online
                ? 'Live · Accepting calls'
                : 'Offline · Ready when you are',
            Icons.circle,
            state.online ? NsColors.cyan : NsColors.muted),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: NsColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NsColors.violet.withAlpha(45))),
            child: Column(children: [
              LayoutBuilder(builder: (context, c) {
                final wide = MediaQuery.textScalerOf(context).scale(12) <= 18;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final video in [false, true])
                    SizedBox(
                        width: wide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                        child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0E1221),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withAlpha(12))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(video ? 'Video' : 'Audio',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15))),
                                    Icon(
                                        video
                                            ? Icons.videocam
                                            : Icons.graphic_eq,
                                        color: video
                                            ? NsColors.cyan
                                            : NsColors.violet,
                                        size: 18)
                                  ]),
                                  const SizedBox(height: 15),
                                  Row(children: [
                                    Expanded(
                                        child: Text(
                                            (video ? state.video : state.online)
                                                ? 'ONLINE'
                                                : 'OFFLINE',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: (video
                                                        ? state.video
                                                        : state.online)
                                                    ? NsColors.cyan
                                                    : NsColors.muted))),
                                    Switch(
                                        value:
                                            video ? state.video : state.online,
                                        onChanged: video
                                            ? actions.video
                                            : actions.online,
                                        activeColor: NsColors.cyan,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap)
                                  ])
                                ])))
                ]);
              }),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 7, children: [
                _pill('Basic', Icons.star, NsColors.gold),
                _pill('₹0.9 / min', Icons.call, NsColors.muted),
                _pill('₹5 / min', Icons.videocam, NsColors.muted)
              ])
            ])),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    colors: [Color(0xFF15192D), Color(0xFF292147)])),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("TODAY'S EARNINGS",
                  style: TextStyle(
                      fontSize: 10, color: NsColors.muted, letterSpacing: .7)),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(
                    child: Text('₹20.24',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800))),
                IconButton(
                    tooltip: 'View earnings preview',
                    onPressed: () =>
                        _open(context, const HomeDesignScreen(designId: 24)),
                    icon:
                        const Icon(Icons.arrow_forward, color: NsColors.violet))
              ]),
              const Text('2 sessions · 18 mins on call',
                  style: TextStyle(fontSize: 11, color: NsColors.muted))
            ])),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NsColors.gold.withAlpha(80)),
                gradient: const LinearGradient(
                    colors: [Color(0xFF35230F), Color(0xFF102C3C)])),
            child: const Row(children: [
              Icon(Icons.local_fire_department, color: NsColors.gold, size: 31),
              SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('NIGHT OWL HOURS',
                        style: TextStyle(
                            color: NsColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('A little time. A meaningful conversation.',
                        style: TextStyle(fontSize: 11))
                  ]))
            ])),
        const SizedBox(height: 16),
        NightshiftSurface(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CALL PREFERENCES',
                  style: TextStyle(
                      fontSize: 10, color: NsColors.muted, letterSpacing: .7)),
              _menu(
                  Icons.translate,
                  'Speaking language',
                  () => _sheet(context, 'Speaking language',
                      const Text('Tamil · English')),
                  value: state.language),
              _menu(
                  Icons.favorite_outline,
                  'Conversation interests',
                  () => _sheet(context, 'Your interests',
                      const Text('Music · Stories · Everyday life')),
                  last: true)
            ]))
      ];

  List<Widget> _filters(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        _banner(context, state, actions),
        const SizedBox(height: 22),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFF151827),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: NsColors.violet.withAlpha(70))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)))),
                  const SizedBox(height: 20),
                  const Text('Find your kind of conversation',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text('A little more you. A better match.',
                      style: TextStyle(color: NsColors.muted, fontSize: 12)),
                  const SizedBox(height: 22),
                  const Text('Preferred language',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final language in ['Tamil', 'English'])
                      ChoiceChip(
                          label: Text(language),
                          selected: state.language == language,
                          onSelected: (_) => actions.language(language))
                  ]),
                  const SizedBox(height: 20),
                  const Text('Vibe & mood',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final mood in [
                      'Just talk',
                      'Music',
                      'Share my day',
                      'Unwind'
                    ])
                      ChoiceChip(
                          label: Text(mood),
                          selected: state.mood == mood,
                          onSelected: (_) => actions.mood(mood))
                  ]),
                  const SizedBox(height: 20),
                  const Text('Call mode',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('Audio'),
                        icon: Icon(Icons.call)),
                    ButtonSegment(
                        value: true,
                        label: Text('Video'),
                        icon: Icon(Icons.videocam))
                  ], selected: {
                    state.video
                  }, onSelectionChanged: (v) => actions.video(v.single)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                      onPressed: () => _open(
                          context,
                          CallDesignScreen(
                              designId: state.video ? 52 : 54, preview: true)),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Find a Listener'))
                ]))
      ];

  List<Widget> _offer(BuildContext context, HomeDesignState state,
          HomeDesignController actions) =>
      [
        _banner(context, state, actions),
        const SizedBox(height: 18),
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: (designId == 43 ? NsColors.violet : NsColors.cyan)
                        .withAlpha(70)),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: designId == 43
                        ? [const Color(0xFF45265C), const Color(0xFF1F1137)]
                        : [const Color(0xFF0D704D), const Color(0xFF082F2E)])),
            child: Column(children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 27),
              _pill('LIMITED-TIME DESIGN', Icons.bolt, NsColors.gold),
              const SizedBox(height: 22),
              const Text('Your next connection,\na little closer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              const Icon(Icons.toll_rounded, size: 85, color: NsColors.gold),
              const SizedBox(height: 15),
              Text(designId == 43 ? 'FLAT ₹800 OFF' : 'FLAT ₹2,000 OFF',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: NsColors.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('A sample offer from the design collection',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 25),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => _open(
                          context,
                          const CommerceDesignScreen(
                              designId: 15, preview: true)),
                      child: const Text('Explore coin packs'))),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () =>
                      _open(context, const HomeDesignScreen(designId: 44)),
                  child: const Text('Maybe later',
                      style: TextStyle(color: Colors.white70)))
            ]))
      ];
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();
  @override
  Widget build(BuildContext context) => const Text('PREVIEW',
      style: TextStyle(fontSize: 8, color: NsColors.muted, letterSpacing: 1));
}
