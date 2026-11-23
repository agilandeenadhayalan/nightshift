import 'dart:async';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/discovery.dart';
import '../core/models.dart';
import 'screens.dart' show showAudioCallConfirmation, StatusCard, ErrorNotice;
import 'state_widgets.dart';
import 'video_preflight.dart';
import 'redesign/design_system.dart';

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
                            DropdownButtonFormField<String>(
                                value: state.language,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: state.text(
                                        'Conversation language',
                                        'உரையாடல் மொழி')),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'ta',
                                      child: Text('தமிழ் · Tamil')),
                                  DropdownMenuItem(
                                      value: 'en', child: Text('English'))
                                ],
                                onChanged: !current
                                    ? null
                                    : (value) {
                                        if (value != null &&
                                            owner == state.accountIdentity) {
                                          if (_scroll.hasClients) {
                                            _scroll.jumpTo(0);
                                          }
                                          unawaited(state.setLanguage(value));
                                        }
                                      }),
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
                                    Text(
                                        widget.kind == DirectoryKind.favorites
                                            ? state.text(
                                                'Favorites', 'விருப்பமானவர்கள்')
                                            : state.text(
                                                'Who would you like to talk to?',
                                                'யாருடன் பேச விரும்புகிறீர்கள்?'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    if (widget.kind == DirectoryKind.discover)
                                      Container(
                                          margin:
                                              const EdgeInsets.only(top: 16),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF382064),
                                                    Color(0xFF1B2242)
                                                  ])),
                                          child: Row(children: [
                                            const Icon(Icons.toll_rounded,
                                                color: NsColors.gold, size: 32),
                                            const SizedBox(width: 14),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(
                                                      state.text(
                                                          'Your test credits',
                                                          'உங்கள் சோதனை நாணயங்கள்'),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      state.text(
                                                          'Available coins • no purchase required',
                                                          'கிடைக்கும் நாணயங்கள் • வாங்க வேண்டியதில்லை'),
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              NsColors.muted)),
                                                ])),
                                            const SizedBox(width: 10),
                                            Flexible(
                                                child: Text(
                                                    creditAmount(state.balance -
                                                        state.held),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge)),
                                          ])),
                                    if (widget.kind == DirectoryKind.favorites)
                                      Text(state.text(
                                          'Saved listeners are not guaranteed to be available.',
                                          'சேமித்த கேட்பவர்கள் எப்போதும் கிடைப்பார்கள் என்பது உறுதியல்ல.')),
                                    const SizedBox(height: 16),
                                    if (widget.kind == DirectoryKind.discover)
                                      OutlinedButton.icon(
                                          onPressed: state.busy ||
                                                  state.hasCall ||
                                                  state.offline
                                              ? null
                                              : () => state.matching.open(),
                                          icon: const Icon(
                                              Icons.headset_mic_outlined),
                                          label: Text(state.text(
                                              'Find an audio Listener',
                                              'ஆடியோ கேட்பவரைத் தேடு'))),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                        onPressed: () =>
                                            _showFilters(context, state),
                                        icon: const Icon(Icons.tune_rounded),
                                        label: Text(state.text(
                                            'Filters · ${state.language == 'ta' ? 'Tamil' : 'English'}${directory.availableOnly ? ' · Available only' : ''}',
                                            'வடிகட்டிகள் · ${state.language == 'ta' ? 'தமிழ்' : 'English'}${directory.availableOnly ? ' · கிடைப்பவர்கள் மட்டும்' : ''}'))),
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
                                      LoadingNotice(
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
  const ListenerCard({super.key, required this.state, required this.listener});
  final AppController state;
  final ListenerProfile listener;
  @override
  Widget build(BuildContext context) {
    final directory = state.discovery,
        canCall = state.canCallListener(listener) && !state.busy;
    final retry = directory.favoriteRetry[listener.id];
    final portrait = avatarAssetPath(listener.avatarCode);
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: const Color(0xFF111424),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(14))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: 190,
              child: Stack(fit: StackFit.expand, children: [
                if (portrait != null)
                  AvatarPortrait(
                      assetPath: portrait, borderRadius: BorderRadius.zero)
                else
                  Container(
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF282344), Color(0xFF172234)])),
                      child: Center(
                          child: NightshiftAvatar(
                              name: listener.name,
                              size: 78,
                              avatarCode: listener.avatarCode))),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xF2090D18)]))),
                Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(listener.name,
                        style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w800))),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(availabilityLabel(state, listener.id),
                        style: TextStyle(
                            fontSize: 10,
                            color: canCall ? NsColors.cyan : NsColors.muted)),
                    const SizedBox(height: 5),
                    Text(
                        listener.languages
                            .map((l) => l == 'ta' ? 'தமிழ்' : 'English')
                            .join(' · '),
                        style: const TextStyle(
                            color: NsColors.muted, fontSize: 10)),
                    const SizedBox(height: 7),
                    Text(testRateLabel(state, listener.rate),
                        style: const TextStyle(
                            color: NsColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                    const SizedBox(height: 7),
                    TextButton.icon(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 6),
                            minimumSize: const Size(44, 40)),
                        onPressed: directory.favoriteBusy.contains(listener.id)
                            ? null
                            : () => directory.favorite(
                                listener.id, retry ?? !listener.favorite),
                        icon: Icon(
                            listener.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 17),
                        label: Text(
                            retry != null &&
                                    !directory.favoriteBusy
                                        .contains(listener.id)
                                ? state.text('Retry favorite change',
                                    'விருப்ப மாற்றத்தை மீண்டும் முயற்சி')
                                : listener.favorite
                                    ? state.text('Remove favorite',
                                        'விருப்பத்திலிருந்து நீக்கு')
                                    : state.text(
                                        'Save favorite', 'விருப்பத்தில் சேமி'),
                            style: const TextStyle(fontSize: 10))),
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: NsColors.cyan,
                            foregroundColor: NsColors.background,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            minimumSize: const Size(44, 44)),
                        onPressed: canCall
                            ? () => showAudioCallConfirmation(
                                context, state, listener)
                            : null,
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text(state.text('Call', 'அழை'),
                            semanticsLabel: state.text('Call ${listener.name}',
                                '${listener.name} அழைக்கவும்'))),
                    if (listener.videoRate != null && state.video != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          state.text(
                              'Video · ${testRateLabel(state, listener.videoRate!)}',
                              'வீடியோ · ${testRateLabel(state, listener.videoRate!)}'),
                          style: const TextStyle(
                              color: NsColors.muted, fontSize: 10)),
                      OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 8),
                              minimumSize: const Size(44, 42)),
                          onPressed: canCall &&
                                  state.canCallListener(listener, video: true)
                              ? () async {
                                  final owner = state.accountIdentity;
                                  final agreed = await showVideoPreflight(
                                      context, state,
                                      rate: listener.videoRate!,
                                      listener: listener,
                                      confirmLabel: state.text(
                                          'Start video call',
                                          'வீடியோ அழைப்பைத் தொடங்கு'));
                                  if (agreed &&
                                      context.mounted &&
                                      owner == state.accountIdentity &&
                                      state.canCallListener(listener,
                                          video: true)) {
                                    await state.startCall(listener,
                                        video: true, cameraConsent: true);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: Text(
                              state.text('Video call', 'வீடியோ அழைப்பு'),
                              style: const TextStyle(fontSize: 10))),
                    ],
                  ])),
        ]));
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
