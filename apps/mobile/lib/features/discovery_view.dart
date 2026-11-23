import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/discovery.dart';
import '../core/models.dart';
import 'screens.dart' show showAudioCallConfirmation, StatusCard, ErrorNotice;
import 'state_widgets.dart';
import 'video_preflight.dart';
import 'redesign/design_system.dart';
import 'redesign/home_components.dart';

String availabilityLabel(AppController state, String id) {
  final card = state.discovery.lookup(id);
  if (state.discovery.removed(id)) {
    return state.text('Unavailable', 'கிடைக்கவில்லை');
  }
  if (!state.discovery.fresh(id)) {
    return state.text('Availability unknown', 'கிடைக்கும் நிலை தெரியவில்லை');
  }
  if (card == null) return state.text('Unavailable', 'கிடைக்கவில்லை');
  if (card.busy) return state.text('Busy', 'பிஸியாக உள்ளார்');
  if (card.available && card.reachability == 'background_eligible') {
    return state.text('Audio invitation enabled · delivery may vary',
        'ஆடியோ அழைப்பிதழ் இயக்கப்பட்டுள்ளது · அறிவிப்பு கிடைப்பது மாறலாம்');
  }
  if (card.available && card.audioAvailable == false) {
    return state.text('Available for video', 'வீடியோ அழைப்புக்கு கிடைக்கிறார்');
  }
  if (card.available && card.videoAvailable == false) {
    return state.text('Available for audio', 'ஆடியோ அழைப்புக்கு கிடைக்கிறார்');
  }
  return card.available
      ? state.text('Available now', 'இப்போது கிடைக்கிறார்')
      : state.text('Offline', 'ஆஃப்லைன்');
}

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen(
      {super.key, required this.state, this.kind = DirectoryKind.discover});
  final AppController state;
  final DirectoryKind kind;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  bool _scrolling = false, _measurePending = false;
  int _featurePage = 0;
  Object? _owner;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.state.discovery.activate(widget.kind);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    if (widget.state.discovery.active == widget.kind) {
      widget.state.discovery.activate(null);
    }
    super.dispose();
  }

  void _measure() {
    if (_measurePending) return;
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted || !_scroll.hasClients) return;
      final viewport = context.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = viewport.localToGlobal(Offset.zero).dy,
          bottom = top + viewport.size.height;
      final ids = <String>[];
      for (final entry in _keys.entries) {
        final box = entry.value.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || !box.attached) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        if (y < bottom && y + box.size.height > top) ids.add(entry.key);
      }
      widget.state.discovery
          .viewport(ids, scrolling: _scrolling, atTop: _scroll.offset <= 24);
    });
  }

  Future<void> _showFilters(BuildContext context, AppController state) async {
    final owner = state.accountIdentity;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFF151827),
        builder: (sheetContext) => AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              final current = owner == state.accountIdentity;
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                state.text('Find your kind of conversation',
                                    'உங்களுக்கு ஏற்ற உரையாடலைக் கண்டறியுங்கள்'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 24),
                            Text(
                                state.text(
                                    'Conversation language', 'உரையாடல் மொழி'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final language in ['ta', 'en'])
                                ChoiceChip(
                                    label: Text(language == 'ta'
                                        ? 'தமிழ் · Tamil'
                                        : 'English'),
                                    selected: state.language == language,
                                    onSelected: !current
                                        ? null
                                        : (_) {
                                            if (owner !=
                                                state.accountIdentity) {
                                              return;
                                            }
                                            if (_scroll.hasClients) {
                                              _scroll.jumpTo(0);
                                            }
                                            unawaited(
                                                state.setLanguage(language));
                                          }),
                            ]),
                            const SizedBox(height: 12),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(state.text(
                                    'Available only', 'கிடைப்பவர்கள் மட்டும்')),
                                value: state.discovery.availableOnly,
                                onChanged: !current
                                    ? null
                                    : (value) {
                                        if (owner != state.accountIdentity) {
                                          return;
                                        }
                                        if (_scroll.hasClients) {
                                          _scroll.jumpTo(0);
                                        }
                                        unawaited(state.discovery
                                            .filter(availableOnly: value));
                                      }),
                            const SizedBox(height: 18),
                            FilledButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(state.text(
                                    'Show Listeners', 'கேட்பவர்களைக் காட்டு'))),
                          ])));
            }));
  }

  Future<void> _showWalletInfo(
      BuildContext context, AppController state) async {
    final owner = state.accountIdentity;
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF171329),
        builder: (sheetContext) => AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              if (owner != state.accountIdentity) {
                return const SizedBox.shrink();
              }
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                                child: NightshiftIllustration(
                                    icon: Icons.toll_rounded,
                                    size: 76,
                                    color: NsColors.gold)),
                            const SizedBox(height: 18),
                            Text(
                                state.text('Your next conversation',
                                    'உங்கள் அடுத்த உரையாடல்'),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 20),
                            Text(creditAmount(state.balance - state.held),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: NsColors.gold)),
                            Text(
                                state.text('Available test coins',
                                    'கிடைக்கும் சோதனை நாணயங்கள்'),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            Text(
                                state.text(
                                    'Test credits are not cash. Your call quote shows the server rate before you connect.',
                                    'சோதனை நாணயங்கள் பணம் அல்ல. இணைவதற்கு முன் அழைப்பு விவரங்களில் சேவையக விகிதம் காட்டப்படும்.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: NsColors.muted, fontSize: 12)),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: () {
                                  if (owner != state.accountIdentity) return;
                                  Navigator.pop(sheetContext);
                                  this.context.push('/wallet');
                                },
                                child: Text(state.text(
                                    'Open wallet', 'பணப்பையைத் திற'))),
                          ])));
            }));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state, directory = state.discovery;
    final page = directory.page(widget.kind),
        cards = directory.items(widget.kind);
    if (_owner != state.accountIdentity) {
      _owner = state.accountIdentity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) directory.activate(widget.kind);
      });
    }
    _measure();
    return LayoutBuilder(builder: (context, viewport) {
      final columns = viewport.maxWidth >= 360 &&
              MediaQuery.textScalerOf(context).scale(12) <= 18
          ? 2
          : 1;
      final rowCount = (cards.length / columns).ceil();
      return Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: NotificationListener<ScrollNotification>(
                  onNotification: (event) {
                    if (event is ScrollStartNotification) _scrolling = true;
                    if (event is ScrollEndNotification) _scrolling = false;
                    _measure();
                    return false;
                  },
                  child: RefreshIndicator(
                      onRefresh: () => directory.load(widget.kind),
                      child: ListView.builder(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: rowCount + 2,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const ErrorNotice(),
                                    if (widget.kind ==
                                        DirectoryKind.discover) ...[
                                      NightshiftFeatureBanner(
                                          compact: true,
                                          icon: _featurePage == 0
                                              ? Icons.toll_rounded
                                              : Icons.auto_awesome,
                                          title: _featurePage == 0
                                              ? state.text(
                                                  'Your test credits', 'உங்கள் சோதனை நாணயங்கள்')
                                              : _featurePage == 1
                                                  ? state.text(
                                                      'A little time to connect',
                                                      'உரையாட சிறிது நேரம்')
                                                  : state.text(
                                                      'Your kind of conversation',
                                                      'உங்களுக்கு ஏற்ற உரையாடல்'),
                                          subtitle: _featurePage == 0
                                              ? creditAmount(state.balance - state.held) +
                                                  state.text(
                                                      ' test coins available',
                                                      ' சோதனை நாணயங்கள் கிடைக்கின்றன')
                                              : _featurePage == 1
                                                  ? state.text(
                                                      'Find an available audio Listener.',
                                                      'கிடைக்கும் ஆடியோ கேட்பவரைத் தேடுங்கள்.')
                                                  : state.text(
                                                      'Choose a language and see who is available.',
                                                      'மொழியைத் தேர்ந்து கிடைப்பவர்களைப் பாருங்கள்.'),
                                          actionLabel: _featurePage == 0
                                              ? state.text('View test coins', 'சோதனை நாணயங்களைப் பார்')
                                              : _featurePage == 1
                                                  ? state.text('Find a Listener', 'கேட்பவரைத் தேடு')
                                                  : state.text('Choose filters', 'வடிகட்டிகளைத் தேர்ந்தெடு'),
                                          onPressed: _featurePage == 0
                                              ? () => _showWalletInfo(context, state)
                                              : _featurePage == 1
                                                  ? (state.busy || state.hasCall || state.offline ? null : () => state.matching.open())
                                                  : () => _showFilters(context, state),
                                          page: _featurePage,
                                          pageCount: 3,
                                          trailing: IconButton(tooltip: state.text('Next feature', 'அடுத்த அம்சம்'), onPressed: () => setState(() => _featurePage = (_featurePage + 1) % 3), icon: const Icon(Icons.chevron_right, color: NsColors.cyan))),
                                      const SizedBox(height: 16),
                                    ],
                                    Row(children: [
                                      Expanded(
                                          child: Text(
                                              widget.kind ==
                                                      DirectoryKind.favorites
                                                  ? state.text('Favorites',
                                                      'விருப்பமானவர்கள்')
                                                  : state.text(
                                                      'Who would you like to talk to?',
                                                      'யாருடன் பேச விரும்புகிறீர்கள்?'),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      TextButton.icon(
                                          onPressed: () =>
                                              _showFilters(context, state),
                                          icon: const Icon(Icons.tune_rounded,
                                              size: 16),
                                          label: Text(
                                              state.text(
                                                  'Filters', 'வடிகட்டிகள்'),
                                              style: const TextStyle(
                                                  fontSize: 11))),
                                    ]),
                                    if (widget.kind == DirectoryKind.favorites)
                                      Text(state.text(
                                          'Saved listeners are not guaranteed to be available.',
                                          'சேமித்த கேட்பவர்கள் எப்போதும் கிடைப்பார்கள் என்பது உறுதியல்ல.')),
                                    const SizedBox(height: 12),
                                    if (page.error != null)
                                      FailureNotice(
                                          offline:
                                              page.error!.code == 'OFFLINE',
                                          title: state.text(
                                              'Could not update availability',
                                              'கிடைக்கும் நிலையை புதுப்பிக்க முடியவில்லை'),
                                          message: [
                                            'DIRECTORY_VIEW_EXPIRED',
                                            'DIRECTORY_VIEW_NOT_FOUND'
                                          ].contains(page.error!.code)
                                              ? state.text(
                                                  'This view has expired. Refresh to see current listeners.',
                                                  'இந்த பட்டியல் காலாவதியானது. தற்போதைய கேட்பவர்களை பார்க்க புதுப்பிக்கவும்.')
                                              : state.text(
                                                  'Check your connection and retry. Existing cards may be out of date.',
                                                  'இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும். காட்டப்படும் நிலை பழையதாக இருக்கலாம்.'),
                                          retryLabel:
                                              state.text('Refresh', 'புதுப்பி'),
                                          onRetry: page.loading ? null : () => directory.load(widget.kind)),
                                    if (directory.favoriteError != null)
                                      Text(state.text(
                                          'Favorite change was not confirmed. Retry the same action on the card.',
                                          'விருப்ப மாற்றம் உறுதியாகவில்லை. அட்டையில் அதே செயலை மீண்டும் முயற்சிக்கவும்.')),
                                    if (cards.isNotEmpty &&
                                        directory.visibleIds
                                            .any((id) => !directory.fresh(id)))
                                      Text(
                                          state.text(
                                              'Reconnecting · availability unknown',
                                              'மீண்டும் இணைகிறது · கிடைக்கும் நிலை தெரியவில்லை'),
                                          semanticsLabel: state.text(
                                              'Availability is stale',
                                              'கிடைக்கும் நிலை பழையது')),
                                    if (page.pendingRefresh)
                                      TextButton.icon(
                                          onPressed: page.loading
                                              ? null
                                              : () {
                                                  _scroll.jumpTo(0);
                                                  unawaited(directory
                                                      .load(widget.kind));
                                                },
                                          icon: const Icon(Icons.refresh),
                                          label: Text(state.text(
                                              'Refresh list order',
                                              'பட்டியல் வரிசையை புதுப்பி'))),
                                    if (!page.loaded && page.error == null ||
                                        page.loading && cards.isEmpty)
                                      NightshiftFeedSkeleton(
                                          compact: page.loaded,
                                          label: state.text(
                                              'Loading listeners…',
                                              'கேட்பவர்கள் ஏற்றப்படுகின்றனர்…')),
                                    if (page.loaded &&
                                        !page.loading &&
                                        page.error == null &&
                                        cards.isEmpty &&
                                        page.cursor == null &&
                                        !page.truncated)
                                      StatusCard(
                                          title: widget.kind ==
                                                  DirectoryKind.favorites
                                              ? state.text(
                                                  'No favorites in this view',
                                                  'இந்த பட்டியலில் விருப்பமானவர்கள் இல்லை')
                                              : state.text(
                                                  'No listeners match this filter',
                                                  'இந்த வடிகட்டலில் கேட்பவர்கள் இல்லை'),
                                          message: state.text(
                                              'Try another language, turn off Available only, or refresh later.',
                                              'வேறு மொழியை தேர்ந்தெடுக்கவும், கிடைப்பவர்கள் மட்டும் என்பதை அணைக்கவும் அல்லது பின்னர் புதுப்பிக்கவும்.')),
                                    const SizedBox(height: 8),
                                  ]);
                            }
                            if (index == rowCount + 1) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.kind ==
                                        DirectoryKind.discover) ...[
                                      FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: NsColors.violet,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 17)),
                                          onPressed: state.busy ||
                                                  state.hasCall ||
                                                  state.offline
                                              ? null
                                              : () => state.matching.open(),
                                          icon: const Icon(Icons.auto_awesome,
                                              color: NsColors.gold),
                                          label: Text(state.text(
                                              'Find an audio Listener',
                                              'ஆடியோ கேட்பவரைத் தேடு'))),
                                      const SizedBox(height: 12),
                                    ],
                                    if (page.loading && cards.isNotEmpty)
                                      LoadingNotice(
                                          label: state.text(
                                              'Loading listeners…',
                                              'கேட்பவர்கள் ஏற்றப்படுகின்றனர்…')),
                                    if (page.cursor != null)
                                      OutlinedButton(
                                          onPressed: page.loading
                                              ? null
                                              : () => directory.load(
                                                  widget.kind,
                                                  append: true),
                                          child: Text(state.text(
                                              'Load more listeners',
                                              'மேலும் கேட்பவர்களை காட்டு'))),
                                    if (page.truncated)
                                      Text(state.text(
                                          'Only part of the directory is shown. Availability may be incomplete.',
                                          'பட்டியலின் ஒரு பகுதி மட்டுமே காட்டப்படுகிறது. கிடைக்கும் நிலை முழுமையாக இல்லாமல் இருக்கலாம்.')),
                                  ]);
                            }
                            final offset = (index - 1) * columns;
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var column = 0;
                                          column < columns;
                                          column++) ...[
                                        if (column > 0)
                                          const SizedBox(width: 12),
                                        Expanded(
                                            child: offset + column <
                                                    cards.length
                                                ? ListenerCard(
                                                    key: _keys.putIfAbsent(
                                                        cards[offset + column]
                                                            .id,
                                                        GlobalKey.new),
                                                    state: state,
                                                    listener:
                                                        cards[offset + column])
                                                : const SizedBox.shrink()),
                                      ]
                                    ]));
                          })))));
    });
  }
}

class ListenerCard extends StatelessWidget {
  const ListenerCard(
      {super.key,
      required this.state,
      required this.listener,
      this.hero = false});
  final AppController state;
  final ListenerProfile listener;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final directory = state.discovery;
    final canCall = state.canCallListener(listener) && !state.busy;
    final canVideo =
        state.canCallListener(listener, video: true) && !state.busy;
    final retry = directory.favoriteRetry[listener.id];
    final showVideo = listener.videoRate != null && state.video != null;
    return NightshiftPortraitCard(
        name: listener.name,
        avatarCode: listener.avatarCode,
        hero: hero,
        portraitLabel: state.text(
            'View ${listener.name}', '${listener.name} விவரத்தைப் பார்'),
        onPortraitTap: hero ? null : () => _showListenerCard(context),
        languages: listener.languages
            .map((l) => l == 'ta' ? 'தமிழ்' : 'English')
            .join(' · '),
        status: availabilityLabel(state, listener.id),
        available: canCall || canVideo,
        rateLabel: testRateLabel(state, listener.rate),
        secondaryRateLabel: showVideo
            ? state.text('Video · ', 'வீடியோ · ') +
                testRateLabel(state, listener.videoRate!)
            : null,
        favorite: listener.favorite,
        favoriteLabel: retry != null
            ? state.text(
                'Retry favorite change', 'விருப்ப மாற்றத்தை மீண்டும் முயற்சி')
            : listener.favorite
                ? state.text('Remove favorite', 'விருப்பத்திலிருந்து நீக்கு')
                : state.text('Save favorite', 'விருப்பத்தில் சேமி'),
        onFavorite: directory.favoriteBusy.contains(listener.id)
            ? null
            : () =>
                directory.favorite(listener.id, retry ?? !listener.favorite),
        actions: [
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: NsColors.cyan,
                  foregroundColor: NsColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(44, 44)),
              onPressed: canCall
                  ? () => showAudioCallConfirmation(context, state, listener)
                  : null,
              child: Text(state.text('Call', 'அழை'),
                  semanticsLabel: state.text(
                      'Call ${listener.name}', '${listener.name} அழைக்கவும்'),
                  style: const TextStyle(fontSize: 11))),
          if (showVideo)
            OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(44, 44)),
                onPressed: canVideo
                    ? () async {
                        final owner = state.accountIdentity;
                        final agreed = await showVideoPreflight(context, state,
                            rate: listener.videoRate!,
                            listener: listener,
                            confirmLabel: state.text('Start video call',
                                'வீடியோ அழைப்பைத் தொடங்கு'));
                        if (agreed &&
                            context.mounted &&
                            owner == state.accountIdentity &&
                            state.canCallListener(listener, video: true)) {
                          await state.startCall(listener,
                              video: true, cameraConsent: true);
                        }
                      }
                    : null,
                child: Text(state.text('Video call', 'வீடியோ அழைப்பு'),
                    style: const TextStyle(fontSize: 10))),
        ]);
  }

  Future<void> _showListenerCard(BuildContext context) async {
    final owner = state.accountIdentity;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => AnimatedBuilder(
            animation: state,
            builder: (context, _) {
              if (owner != state.accountIdentity) {
                return const SizedBox.shrink();
              }
              final current = state.discovery.lookup(listener.id);
              if (current == null) {
                return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(state.text(
                        'Listener is unavailable', 'கேட்பவர் கிடைக்கவில்லை')));
              }
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListenerCard(
                            state: state, listener: current, hero: true),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(state.text('Close', 'மூடு'))),
                      ])));
            }));
  }
}

class RecentAvailability extends StatelessWidget {
  const RecentAvailability(
      {super.key, required this.state, required this.listenerId});
  final AppController state;
  final String listenerId;
  @override
  Widget build(BuildContext context) {
    final listener = state.discovery.lookup(listenerId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text(state.text(
          'Current availability: ${availabilityLabel(state, listenerId)}',
          'தற்போதைய நிலை: ${availabilityLabel(state, listenerId)}')),
      if (listener != null)
        Wrap(spacing: 8, children: [
          OutlinedButton(
              onPressed: state.busy || !state.canCallListener(listener)
                  ? null
                  : () => showAudioCallConfirmation(context, state, listener),
              child: Text(state.text('Call again', 'மீண்டும் அழை'))),
          TextButton(
              onPressed: state.discovery.favoriteBusy.contains(listenerId)
                  ? null
                  : () => state.discovery.favorite(
                      listenerId,
                      state.discovery.favoriteRetry[listenerId] ??
                          !listener.favorite),
              child: Text(state.discovery.favoriteRetry.containsKey(listenerId)
                  ? state.text('Retry favorite change',
                      'விருப்ப மாற்றத்தை மீண்டும் முயற்சி')
                  : listener.favorite
                      ? state.text(
                          'Remove favorite', 'விருப்பத்திலிருந்து நீக்கு')
                      : state.text('Save favorite', 'விருப்பத்தில் சேமி'))),
        ])
    ]);
  }
}
