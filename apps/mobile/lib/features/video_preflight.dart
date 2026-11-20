import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'message_copy.dart';
import 'video_view.dart';

String testRateLabel(AppController state, CallRate rate) => state.text(
    '${rate.coinsPerMinute} test coins / minute',
    'நிமிடத்திற்கு ${rate.coinsPerMinute} சோதனை நாணயங்கள்');

String testTariffDescription(AppController state, CallRate rate) {
  final minimum = (rate.minimumChargedSeconds *
          rate.microcreditsPerSecond /
          rate.microcreditsPerCoin)
      .toStringAsFixed(0);
  final perSecond = (rate.microcreditsPerSecond / rate.microcreditsPerCoin)
      .toStringAsFixed(0);
  return state.text(
      'Test credits only. Ringing is free. Up to ${rate.freeThroughSeconds} connected seconds is free; crossing ${rate.freeThroughSeconds} seconds charges $minimum coins covering the first ${rate.minimumChargedSeconds} seconds, then $perSecond coin(s) per additional second. Missing media and reconnect gaps do not advance the charge. Maximum 10 minutes, limited by your balance.',
      'சோதனை நாணயங்கள் மட்டுமே. காத்திருப்பு இலவசம். ${rate.freeThroughSeconds} இணைப்பு விநாடிகள் வரை இலவசம்; அதைத் தாண்டினால் முதல் ${rate.minimumChargedSeconds} விநாடிகளுக்கு $minimum நாணயங்கள், பின்னர் விநாடிக்கு $perSecond நாணயங்கள். ஊடகம் இல்லாத நேரமும் இணைப்பு இடைவெளியும் கட்டணத்தை அதிகரிக்காது. இருப்புக்கு உட்பட்டு அதிகபட்சம் 10 நிமிடங்கள்.');
}

Future<bool> showVideoPreflight(BuildContext context, AppController state,
    {required CallRate rate,
    required String confirmLabel,
    ListenerProfile? listener}) async {
  try {
    return await showDialog<bool>(
            context: context,
            builder: (context) => _VideoPreflight(
                state: state,
                rate: rate,
                confirmLabel: confirmLabel,
                listener: listener)) ==
        true;
  } finally {
    // Complete camera teardown before the caller sends consent/joins a channel.
    // Disposal does not repeat this: a late dialog animation must not tear down
    // an engine that has since joined the accepted call.
    await state.closeVideoPreview();
  }
}

class _VideoPreflight extends StatefulWidget {
  const _VideoPreflight(
      {required this.state,
      required this.rate,
      required this.confirmLabel,
      this.listener});
  final AppController state;
  final ListenerProfile? listener;
  final CallRate rate;
  final String confirmLabel;
  @override
  State<_VideoPreflight> createState() => _VideoPreflightState();
}

class _VideoPreflightState extends State<_VideoPreflight> {
  bool _consent = false, _closing = false;
  String? _callId;
  Object? _owner;

  @override
  void initState() {
    super.initState();
    _callId = widget.state.activeCall?.id;
    _owner = widget.state.accountIdentity;
    widget.state.addListener(_checkLifetime);
  }

  void _checkLifetime() {
    final state = widget.state;
    if (_closing || !mounted) return;
    if (!state.foreground ||
        state.user == null ||
        state.accountIdentity != _owner ||
        state.activeCall?.id != _callId ||
        state.activeCall?.ended == true) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A router redirect can remove this dialog before its exit animation
        // disposes the widget. Never pop the replacement screen in that gap.
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop(false);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_checkLifetime);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final video = state.video;
        final previewing = video?.previewing == true;
        final available =
            widget.listener == null || state.canCallListener(widget.listener!);
        final canConfirm = available &&
            previewing &&
            _consent &&
            !state.videoPreviewBusy &&
            !_closing &&
            state.foreground;
        return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
                state.text('Review your camera', 'கேமராவை சரிபார்க்கவும்')),
            content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      if (!available)
                        Text(state.text(
                            'Listener is no longer available. Refresh before calling.',
                            'கேட்பவர் தற்போது கிடைக்கவில்லை. அழைப்பதற்கு முன் புதுப்பிக்கவும்.')),
                      Text(testRateLabel(state, widget.rate),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(testTariffDescription(state, widget.rate)),
                      const SizedBox(height: 16),
                      Text(state.text(
                          'Preview stays on this phone. Your microphone is off during preview. Nothing is shared until you confirm and the call is accepted.',
                          'முன்னோட்டம் இந்த தொலைபேசியில் மட்டுமே தெரியும். முன்னோட்டத்தில் மைக்ரோஃபோன் இயங்காது. நீங்கள் உறுதிசெய்து அழைப்பு ஏற்கப்படும் வரை எதுவும் பகிரப்படாது.')),
                      const SizedBox(height: 16),
                      if (previewing) ...[
                        VideoCameraPane(
                            controller: video!.localVideo,
                            label: state.text('Only you · camera preview',
                                'நீங்கள் மட்டும் · கேமரா முன்னோட்டம்'),
                            placeholder: state.text('Camera preview ready',
                                'கேமரா முன்னோட்டம் தயார்')),
                        const SizedBox(height: 12),
                      ],
                      if (state.videoPreviewError != null) ...[
                        Semantics(
                            liveRegion: true,
                            child: Text(
                                errorMessage(
                                    state.videoPreviewError, state.locale),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                          onPressed:
                              state.videoPreviewBusy || previewing || _closing
                                  ? null
                                  : () async {
                                      setState(() => _consent = false);
                                      await state.prepareVideoPreview();
                                    },
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(state.videoPreviewBusy
                              ? state.text(
                                  'Opening camera…', 'கேமரா திறக்கிறது…')
                              : state.text(
                                  'Preview camera', 'கேமரா முன்னோட்டம்'))),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _consent,
                          onChanged:
                              previewing && !state.videoPreviewBusy && !_closing
                                  ? (value) =>
                                      setState(() => _consent = value == true)
                                  : null,
                          title: Text(state.text(
                              'I consent to share my camera and microphone in this video call.',
                              'இந்த வீடியோ அழைப்பில் எனது கேமராவையும் மைக்ரோஃபோனையும் பகிர ஒப்புக்கொள்கிறேன்.'))),
                      Text(state.text(
                          'You can turn your camera off or end at any time. NightShift does not record this call. The other person may still capture it.',
                          'எப்போது வேண்டுமானாலும் கேமராவை நிறுத்தலாம் அல்லது அழைப்பை முடிக்கலாம். NightShift இந்த அழைப்பைப் பதிவு செய்யாது. மற்ற நபர் பதிவு செய்யக்கூடும்.')),
                    ]))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(state.text('Cancel', 'ரத்து'))),
              FilledButton(
                  onPressed: canConfirm
                      ? () {
                          _closing = true;
                          Navigator.pop(context, true);
                        }
                      : null,
                  child: Text(widget.confirmLabel)),
            ]);
      });
}
