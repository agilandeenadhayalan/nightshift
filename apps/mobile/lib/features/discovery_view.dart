import 'dart:async';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/discovery.dart';
import '../core/models.dart';
import 'screens.dart' show showAudioCallConfirmation, StatusCard, ErrorNotice;
import 'state_widgets.dart';
import 'video_preflight.dart';

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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount: cards.length + 2,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(state.text(
                                                      'Your test credits',
                                                      'உங்கள் சோதனை நாணயங்கள்')),
                                                  Text(
                                                      creditAmount(
                                                          state.balance -
                                                              state.held),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headlineMedium),
                                                  Text(state.text(
                                                      'Available coins • no purchase required',
                                                      'கிடைக்கும் நாணயங்கள் • வாங்க வேண்டியதில்லை')),
                                                ]))),
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
                                      onChanged: (value) {
                                        if (value != null) {
                                          _scroll.jumpTo(0);
                                          unawaited(state.setLanguage(value));
                                        }
                                      }),
                                  SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(state.text('Available only',
                                          'கிடைப்பவர்கள் மட்டும்')),
                                      value: directory.availableOnly,
                                      onChanged: (value) {
                                        _scroll.jumpTo(0);
                                        unawaited(directory.filter(
                                            availableOnly: value));
                                      }),
                                  if (page.error != null)
                                    FailureNotice(
                                        offline: page.error!.code == 'OFFLINE',
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
                                        onRetry: page.loading
                                            ? null
                                            : () => directory.load(widget.kind)),
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
                                        label: state.text('Loading listeners…',
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
                          if (index == cards.length + 1) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (page.loading && cards.isNotEmpty)
                                    LoadingNotice(
                                        label: state.text('Loading listeners…',
                                            'கேட்பவர்கள் ஏற்றப்படுகின்றனர்…')),
                                  if (page.cursor != null)
                                    OutlinedButton(
                                        onPressed: page.loading
                                            ? null
                                            : () => directory.load(widget.kind,
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
                          final card = cards[index - 1];
                          return ListenerCard(
                              key: _keys.putIfAbsent(card.id, GlobalKey.new),
                              state: state,
                              listener: card);
                        })))));
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
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const CircleAvatar(child: Icon(Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(listener.name,
                            style: Theme.of(context).textTheme.titleLarge))
                  ]),
                  const SizedBox(height: 12),
                  Text(availabilityLabel(state, listener.id)),
                  Text(listener.languages
                      .map((l) => l == 'ta' ? 'தமிழ்' : 'English')
                      .join(' · ')),
                  const SizedBox(height: 8),
                  Text(testRateLabel(state, listener.rate)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: directory.favoriteBusy.contains(listener.id)
                          ? null
                          : () => directory.favorite(
                              listener.id, retry ?? !listener.favorite),
                      icon: Icon(listener.favorite
                          ? Icons.favorite
                          : Icons.favorite_border),
                      label: Text(retry != null &&
                              !directory.favoriteBusy.contains(listener.id)
                          ? state.text('Retry favorite change',
                              'விருப்ப மாற்றத்தை மீண்டும் முயற்சி')
                          : listener.favorite
                              ? state.text('Remove favorite',
                                  'விருப்பத்திலிருந்து நீக்கு')
                              : state.text(
                                  'Save favorite', 'விருப்பத்தில் சேமி'))),
                  FilledButton.icon(
                      onPressed: canCall
                          ? () => showAudioCallConfirmation(
                              context, state, listener)
                          : null,
                      icon: const Icon(Icons.call_outlined),
                      label: Text(state.text('Call', 'அழை'),
                          semanticsLabel: state.text('Call ${listener.name}',
                              '${listener.name} அழைக்கவும்'))),
                  if (listener.videoRate != null && state.video != null) ...[
                    const SizedBox(height: 8),
                    Text(state.text(
                        'Video · ${testRateLabel(state, listener.videoRate!)}',
                        'வீடியோ · ${testRateLabel(state, listener.videoRate!)}')),
                    OutlinedButton.icon(
                        onPressed: canCall &&
                                state.canCallListener(listener, video: true)
                            ? () async {
                                final owner = state.accountIdentity;
                                final agreed = await showVideoPreflight(
                                    context, state,
                                    rate: listener.videoRate!,
                                    listener: listener,
                                    confirmLabel: state.text('Start video call',
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
                        icon: const Icon(Icons.videocam_outlined),
                        label:
                            Text(state.text('Video call', 'வீடியோ அழைப்பு'))),
                  ],
                ])));
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
