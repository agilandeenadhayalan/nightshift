part of '../screens.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _favorites = false, _measurePending = false;
  late final Discovery _discovery;
  final Map<String, GlobalKey> _recentKeys = {};
  void _watchVisible() {
    if (_measurePending) return;
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted || _favorites) return;
      final state = ref.read(appControllerProvider);
      if (state.isListener) return;
      final viewport = context.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = viewport.localToGlobal(Offset.zero).dy,
          bottom = top + viewport.size.height;
      final ids = <String>[];
      for (final call in state.history) {
        final box = _recentKeys[call.id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || !box.attached) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        if (y < bottom && y + box.size.height > top) ids.add(call.listenerId);
      }
      state.discovery.watchRecents(ids);
    });
  }

  @override
  void dispose() {
    _discovery.watchRecents([]);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _discovery = ref.read(appControllerProvider).discovery;
    Future.microtask(() {
      if (!mounted) return;
      final state = ref.read(appControllerProvider);
      if (!state.historyLoaded && state.historyError == null) {
        unawaited(state.loadHistory());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    _watchVisible();
    if (state.isListener) return _history(context, state);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false,
                    label: Text(
                        state.text('Recent calls', 'சமீபத்திய அழைப்புகள்'))),
                ButtonSegment(
                    value: true,
                    label: Text(state.text('Favorites', 'விருப்பமானவர்கள்')))
              ],
              selected: {
                _favorites
              },
              onSelectionChanged: (value) {
                state.discovery.watchRecents([]);
                setState(() => _favorites = value.single);
              })),
      Expanded(
          child: _favorites
              ? DirectoryScreen(state: state, kind: DirectoryKind.favorites)
              : NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _watchVisible();
                    return false;
                  },
                  child: _history(context, state))),
    ]);
  }

  Widget _history(BuildContext context, AppController state) {
    final earned = state.history
        .where((c) => c.listenerId == state.user?.id)
        .fold<int>(0, (sum, call) => sum + call.earningPaise);
    return RefreshIndicator(
        onRefresh: () async {
          await state.loadHistory();
          await state.discovery.refreshRecents();
        },
        child: PageBody(children: [
          const ErrorNotice(),
          Text(
              state.isListener
                  ? state.text(
                      'Earnings & calls', 'வருமானம் மற்றும் அழைப்புகள்')
                  : state.text('Your conversations', 'உங்கள் உரையாடல்கள்'),
              style: Theme.of(context).textTheme.headlineSmall),
          if (state.isListener && state.historyLoaded)
            StatusCard(
                title: '₹${(earned / 100).toStringAsFixed(2)}',
                message: state.text(
                    'Test earnings in this history · No cash payouts.',
                    'காட்டப்பட்ட வரலாற்றின் சோதனை வருமானம். உண்மையான பணம் வழங்கப்படாது. விகிதமும் தீர்வும் சேவையகத்தால் கணக்கிடப்படும்.')),
          const SizedBox(height: 16),
          if (state.historyError != null)
            FailureNotice(
              offline: state.historyError!.code == 'OFFLINE',
              title: state.historyError!.code == 'OFFLINE'
                  ? state.text(
                      'Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
                  : state.text(
                      'Could not load calls', 'அழைப்புகளை ஏற்ற முடியவில்லை'),
              message: errorMessage(state.historyError!.code, state.locale),
              reference: state.historyError!.requestId == null
                  ? null
                  : state.text('Reference: ${state.historyError!.requestId}',
                      'குறிப்பு: ${state.historyError!.requestId}'),
              retryLabel: state.text('Retry', 'மீண்டும் முயற்சி'),
              onRetry: state.historyLoading ? null : state.retryHistory,
            ),
          if (state.history.isEmpty &&
              state.historyLoaded &&
              !state.historyLoading &&
              state.historyError == null)
            StatusCard(
                title: state.text('No completed calls yet',
                    'முடிந்த அழைப்புகள் இன்னும் இல்லை'),
                message: state.text(
                    'Your completed, cancelled and declined calls will appear here.',
                    'முடிந்த, ரத்தான, நிராகரிக்கப்பட்ட அழைப்புகள் இங்கே தெரியும்.')),
          for (final (index, call) in state.history.indexed) ...[
            if (index == 0 ||
                historyDay(call.createdAt, DateTime.now()) !=
                    historyDay(
                        state.history[index - 1].createdAt, DateTime.now()))
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      switch (historyDay(call.createdAt, DateTime.now())) {
                        'today' => state.text('Today', 'இன்று'),
                        'yesterday' => state.text('Yesterday', 'நேற்று'),
                        _ => state.text('Earlier', 'முன்பு'),
                      },
                      style: Theme.of(context).textTheme.titleMedium)),
            Card(
                key: _recentKeys.putIfAbsent(call.id, GlobalKey.new),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            NightshiftAvatar(
                                name: call.otherName(state.user!.id),
                                size: 46,
                                avatarCode: state.isListener
                                    ? call.customerAvatarCode
                                    : call.listenerAvatarCode),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(call.otherName(state.user!.id),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            Icon(
                                call.isVideo
                                    ? Icons.videocam_outlined
                                    : Icons.call_outlined,
                                color: NsColors.cyan),
                          ]),
                          const SizedBox(height: 8),
                          Text(call.isVideo
                              ? state.text('Video call', 'வீடியோ அழைப்பு')
                              : state.text('Audio call', 'ஆடியோ அழைப்பு')),
                          const SizedBox(height: 8),
                          Text(
                              '${_localDate(call.createdAt)} · ${durationLabel(call.connectedMs)}'),
                          Text(state.text(
                              'End reason: ${endReasonLabel(call.reason, state.locale)}',
                              'முடிவு காரணம்: ${endReasonLabel(call.reason, state.locale)}')),
                          Text(state.text(
                              '${creditAmount(call.chargeMicrocredits)} test coins',
                              '${creditAmount(call.chargeMicrocredits)} சோதனை நாணயங்கள்')),
                          if (call.listenerId == state.user!.id)
                            Text(state.text(
                                'Test earnings ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
                                'சோதனை வருமானம் ₹${(call.earningPaise / 100).toStringAsFixed(2)}')),
                          if (!state.isListener)
                            RecentAvailability(
                                state: state, listenerId: call.listenerId),
                          const SizedBox(height: 8),
                          SelectableText(
                              state.text('Call ID: ${call.id}',
                                  'அழைப்பு எண்: ${call.id}'),
                              style: const TextStyle(
                                  color: NsColors.muted, fontSize: 10)),
                          MediaDiagnosticsButton(state: state, callId: call.id),
                          TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () =>
                                      showSafetyDialog(context, state, call),
                              icon: const Icon(Icons.shield_outlined),
                              label: Text(state.text(
                                  'Report or block', 'புகாரளி அல்லது தடு'))),
                        ]))),
          ],
          if (state.historyLoading ||
              (!state.historyLoaded && state.historyError == null))
            LoadingNotice(
                label: state.text(
                    'Loading calls…', 'அழைப்புகள் ஏற்றப்படுகின்றன…')),
          if (state.historyCursor != null)
            OutlinedButton(
                onPressed: state.historyLoading
                    ? null
                    : () => state.loadHistory(append: true),
                child: Text(state.text(
                    'Load earlier calls', 'முந்தைய அழைப்புகளை காட்டு'))),
        ]));
  }

  String _localDate(DateTime time) {
    final local = time.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.timeZoneName}';
  }
}

Future<void> showSafetyDialog(
    BuildContext context, AppController state, CallSession call) async {
  final owner = state.accountIdentity;
  final result = await showDialog<(String, bool)>(
      context: context, builder: (context) => _SafetyDialog(controller: state));
  if (result != null && owner == state.accountIdentity) {
    await state.submitSafety(call, result.$1, block: result.$2);
    if (context.mounted &&
        owner == state.accountIdentity &&
        state.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.text(
              'Your action was saved.', 'உங்கள் செயல் சேமிக்கப்பட்டது.'))));
    }
  }
}

class _SafetyDialog extends StatefulWidget {
  const _SafetyDialog({required this.controller});
  final AppController controller;
  @override
  State<_SafetyDialog> createState() => _SafetyDialogState();
}

class _SafetyDialogState extends State<_SafetyDialog> {
  final reason = TextEditingController();
  bool block = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    return AlertDialog(
      title: Text(state.text('Report or block', 'புகாரளி அல்லது தடு')),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(state.text(
            'Blocking stops this call and prevents further calls between you. Reports in this test build are stored for review; no staffed response time is promised.',
            'தடுப்பது இந்த அழைப்பை நிறுத்தி எதிர்கால அழைப்புகளைத் தடுக்கும். சோதனை புகார்கள் ஆய்விற்காக சேமிக்கப்படும்; பதிலளிக்கும் நேரம் உறுதி செய்யப்படவில்லை.')),
        const SizedBox(height: 16),
        TextField(
            controller: reason,
            maxLength: 1000,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: state.text('Reason (optional when blocking)',
                    'காரணம் (தடுக்கும்போது விருப்பம்)'))),
        CheckboxListTile(
            value: block,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => block = value!),
            title: Text(state.text('Block this person', 'இவரை தடு'))),
      ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.text('Cancel', 'ரத்து'))),
        FilledButton(
            onPressed: !block && reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (reason.text, block)),
            child: Text(state.text('Submit', 'சமர்ப்பி')))
      ],
    );
  }
}
