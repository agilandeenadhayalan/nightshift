import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/controller.dart';
import '../core/media_diagnostics.dart';

/// Connection evidence is optional, local and separate from Report or block.
class MediaDiagnosticsButton extends StatelessWidget {
  const MediaDiagnosticsButton(
      {super.key, required this.state, required this.callId});
  final AppController state;
  final String callId;

  @override
  Widget build(BuildContext context) {
    if (state.mediaDiagnosticsFor(callId) == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
        key: ValueKey('connection-details-$callId'),
        onPressed: () => showMediaDiagnostics(context, state, callId),
        icon: const Icon(Icons.network_check),
        label: Text(state.text('Connection details', 'இணைப்பு விவரங்கள்')));
  }
}

Future<void> showMediaDiagnostics(
    BuildContext context, AppController state, String callId,
    {Future<void> Function(String)? copy}) async {
  final owner = state.accountIdentity;
  final receipt = state.mediaDiagnosticsFor(callId);
  if (receipt == null) return;
  await showDialog<void>(
      context: context,
      builder: (_) => MediaDiagnosticsDialog(
          state: state,
          owner: owner,
          callId: callId,
          receiptId: receipt.receiptId,
          copy:
              copy ?? (text) => Clipboard.setData(ClipboardData(text: text))));
}

class MediaDiagnosticsDialog extends StatefulWidget {
  const MediaDiagnosticsDialog(
      {super.key,
      required this.state,
      required this.owner,
      required this.callId,
      required this.receiptId,
      required this.copy});
  final AppController state;
  final Object owner;
  final String callId, receiptId;
  final Future<void> Function(String) copy;

  @override
  State<MediaDiagnosticsDialog> createState() => _MediaDiagnosticsDialogState();
}

class _MediaDiagnosticsDialogState extends State<MediaDiagnosticsDialog> {
  DiagnosticSymptom? symptom;
  bool copying = false;
  String? copyStatus;

  MediaDiagnosticReceipt? get current {
    if (widget.owner != widget.state.accountIdentity) return null;
    final receipt = widget.state.mediaDiagnosticsFor(widget.callId);
    return receipt?.receiptId == widget.receiptId ? receipt : null;
  }

  Future<void> copyDetails() async {
    if (copying || current == null) return;
    final text = widget.state.exportMediaDiagnostics(
        expectedOwner: widget.owner,
        callId: widget.callId,
        receiptId: widget.receiptId,
        symptom: symptom);
    if (text == null) return;
    setState(() {
      copying = true;
      copyStatus = null;
    });
    try {
      // No asynchronous gap between the owner check and explicit OS dispatch.
      // A dispatched clipboard write cannot be revoked by a later logout.
      await widget.copy(text);
      if (!mounted || current == null) return;
      setState(() => copyStatus = 'copied');
    } catch (_) {
      if (!mounted || current == null) return;
      setState(() => copyStatus = 'failed');
    } finally {
      if (mounted) setState(() => copying = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state, receipt = current;
        return AlertDialog(
          title: Text(state.text('Connection details', 'இணைப்பு விவரங்கள்')),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: receipt == null
                      ? Text(state.text(
                          'These local details are no longer available.',
                          'இந்தச் சாதனத்தில் இருந்த விவரங்கள் இப்போது கிடைக்கவில்லை.'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(state.text(
                                  'Technical readings only. They do not prove that either person heard audio and do not determine charges.',
                                  'இவை தொழில்நுட்ப அளவீடுகள் மட்டுமே. இருவரும் ஒலியைக் கேட்டதை உறுதிப்படுத்தாது; கட்டணத்தையும் தீர்மானிக்காது.')),
                              const SizedBox(height: 12),
                              Text(state.text(
                                  'These in-app details expire after 15 minutes, when another call replaces them or when you sign out. Opening this view sends nothing. Copy creates a separate clipboard copy.',
                                  'இந்தச் செயலியில் உள்ள விவரங்கள் 15 நிமிடங்களுக்குப் பின், அடுத்த அழைப்பு தொடங்கும்போது அல்லது வெளியேறும்போது நீங்கும். இங்கே பார்ப்பதால் எதுவும் அனுப்பப்படாது. நகலெடுப்பது தனியான கிளிப்போர்டு நகலை உருவாக்கும்.')),
                              const SizedBox(height: 12),
                              SelectableText(state.text(
                                  'Local reference: ${receipt.receiptId}',
                                  'சாதனக் குறிப்பு: ${receipt.receiptId}')),
                              SelectableText(state.text(
                                  'Call ID: ${receipt.callId}',
                                  'அழைப்பு எண்: ${receipt.callId}')),
                              Text(state.text(
                                  'This local reference cannot be looked up by support. Copying shares the displayed technical details, without conversation audio.',
                                  'இந்தச் சாதனக் குறிப்பை ஆதரவுக் குழு தேடிப் பெற முடியாது. நகலெடுப்பதில் தொழில்நுட்ப விவரங்கள் மட்டும் இருக்கும்; உரையாடல் ஒலி இருக்காது.')),
                              const SizedBox(height: 18),
                              Text(
                                  state.text('Observed connection steps',
                                      'கவனிக்கப்பட்ட இணைப்பு நிலைகள்'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(state.text(
                                  'Times are relative to when this device began observing this call.',
                                  'இந்தச் சாதனம் அழைப்பைக் கவனிக்கத் தொடங்கியதிலிருந்து நேரங்கள் கணக்கிடப்பட்டுள்ளன.')),
                              for (final entry in receipt.milestones.entries)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        '${_milestone(state, entry.key)}: ${(entry.value / 1000).toStringAsFixed(2)} s')),
                              const SizedBox(height: 12),
                              Text(state.text(
                                  'Capture observation: ${_capture(state, receipt.capture)}',
                                  'மைக்ரோஃபோன் நிலை: ${_capture(state, receipt.capture)}')),
                              Text(state.text(
                                  'Local mute: ${_mute(state, receipt.localMute)}',
                                  'உங்கள் ஒலி முடக்கம்: ${_mute(state, receipt.localMute)}')),
                              Text(state.text(
                                  'Remote mute: ${_mute(state, receipt.remoteMute)}',
                                  'மற்றவரின் ஒலி முடக்கம்: ${_mute(state, receipt.remoteMute)}')),
                              Text(state.text(
                                  'Cleanup observation: ${_cleanup(state, receipt.cleanup)}',
                                  'இணைப்பை நிறுத்தும் நிலை: ${_cleanup(state, receipt.cleanup)}')),
                              if (receipt.previousCleanup != null)
                                Text(state.text(
                                    'Previous attempt ${receipt.previousCleanupAttempt} cleanup: ${_cleanup(state, receipt.previousCleanup!)}',
                                    'முந்தைய முயற்சி ${receipt.previousCleanupAttempt} நிறுத்தம்: ${_cleanup(state, receipt.previousCleanup!)}')),
                              if (receipt.failure != null)
                                Text(state.text(
                                    'Failure category: ${_failure(state, receipt.failure!)}',
                                    'பிழை வகை: ${_failure(state, receipt.failure!)}')),
                              const SizedBox(height: 18),
                              Text(
                                  state.text('Connection measurements',
                                      'இணைப்பு அளவீடுகள்'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(state.text(
                                  'Missing readings are unavailable, not zero. These readings do not establish why speech was not heard.',
                                  'கிடைக்காத அளவீடுகள் பூஜ்ஜியம் அல்ல. பேச்சு ஏன் கேட்கவில்லை என்பதை இந்த அளவீடுகள் உறுதிப்படுத்தாது.')),
                              for (final metric in DiagnosticMetric.values)
                                Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(receipt.metrics[metric] == null
                                        ? '${_metric(state, metric)}: ${state.text('Unavailable', 'கிடைக்கவில்லை')}'
                                        : '${_metric(state, metric)}: ${state.text('latest', 'சமீபத்தியது')} ${receipt.metrics[metric]!.latest}; ${state.text('highest', 'அதிகபட்சம்')} ${receipt.metrics[metric]!.maximum}; ${state.text('samples', 'மாதிரிகள்')} ${receipt.metrics[metric]!.samples}')),
                              const SizedBox(height: 18),
                              Text(
                                  state.text('What did you notice? (optional)',
                                      'நீங்கள் கவனித்தது என்ன? (விருப்பம்)'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(state.text(
                                  'Your selection is your report, separate from the measurements. It is included only if you copy these details.',
                                  'உங்கள் தேர்வு அளவீடுகளிலிருந்து தனியான உங்கள் கருத்து. விவரங்களை நகலெடுத்தால் மட்டும் அதில் சேர்க்கப்படும்.')),
                              RadioListTile<DiagnosticSymptom?>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(state.text(
                                      'No selection', 'தேர்வு இல்லை')),
                                  value: null,
                                  groupValue: symptom,
                                  onChanged: copying
                                      ? null
                                      : (value) =>
                                          setState(() => symptom = value)),
                              for (final value in DiagnosticSymptom.values)
                                RadioListTile<DiagnosticSymptom?>(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(_symptom(state, value)),
                                    value: value,
                                    groupValue: symptom,
                                    onChanged: copying
                                        ? null
                                        : (value) =>
                                            setState(() => symptom = value)),
                              if (copyStatus != null)
                                Text(copyStatus == 'copied'
                                    ? state.text(
                                        'Technical details copied. Nothing was sent to support.',
                                        'தொழில்நுட்ப விவரங்கள் நகலெடுக்கப்பட்டன. ஆதரவுக் குழுவுக்கு எதுவும் அனுப்பப்படவில்லை.')
                                    : state.text(
                                        'Could not copy the details. Try again.',
                                        'விவரங்களை நகலெடுக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.')),
                            ]))),
          actions: [
            if (receipt != null)
              TextButton.icon(
                  key: const ValueKey('copy-connection-details'),
                  onPressed: copying ? null : copyDetails,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(state.text('Copy technical details',
                      'தொழில்நுட்ப விவரங்களை நகலெடு'))),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(state.text('Close', 'மூடு'))),
          ],
        );
      });
}

String _symptom(AppController state, DiagnosticSymptom value) =>
    switch (value) {
      DiagnosticSymptom.couldNotConnect =>
        state.text('The call could not connect', 'அழைப்பை இணைக்க முடியவில்லை'),
      DiagnosticSymptom.couldNotHearOther => state.text(
          'I could not hear the other person',
          'மற்றவர் பேசுவது எனக்குக் கேட்கவில்லை'),
      DiagnosticSymptom.otherCouldNotHearMe => state.text(
          'The other person said they could not hear me',
          'என் பேச்சு கேட்கவில்லை என்று மற்றவர் கூறினார்'),
      DiagnosticSymptom.interruptedAudio =>
        state.text('The audio kept breaking up', 'ஒலி தொடர்ந்து தடைப்பட்டது'),
    };

// Enum-to-label mappings stay explicit; no provider message becomes UI text.
String _milestone(AppController state, DiagnosticMilestone value) =>
    switch (value) {
      DiagnosticMilestone.callObserved =>
        state.text('Call observed', 'அழைப்பு கவனிக்கப்பட்டது'),
      DiagnosticMilestone.acceptedObserved => state.text(
          'Server acceptance observed', 'சேவையக ஏற்பு கவனிக்கப்பட்டது'),
      DiagnosticMilestone.joinRequested =>
        state.text('Media join requested', 'ஊடக இணைப்பு கோரப்பட்டது'),
      DiagnosticMilestone.sdkJoined =>
        state.text('SDK channel joined', 'SDK சேனல் இணைந்தது'),
      DiagnosticMilestone.localCaptureObserved => state.text(
          'Local microphone capture observed',
          'உள்ளூர் மைக்ரோஃபோன் செயல்பாடு கவனிக்கப்பட்டது'),
      DiagnosticMilestone.remoteDecodeObserved => state.text(
          'Remote audio decoding observed',
          'மற்றவரின் ஒலி செயலாக்கம் கவனிக்கப்பட்டது'),
      DiagnosticMilestone.callEndedObserved => state.text(
          'Server call end observed', 'சேவையக அழைப்பு முடிவு கவனிக்கப்பட்டது'),
    };

String _capture(AppController state, DiagnosticCapture value) =>
    switch (value) {
      DiagnosticCapture.active => state.text('Microphone capture observed',
          'மைக்ரோஃபோன் செயல்பாடு கவனிக்கப்பட்டது'),
      DiagnosticCapture.stopRequested => state.text(
          'Stop requested; awaiting confirmation',
          'நிறுத்தக் கோரப்பட்டது; உறுதிக்காக காத்திருக்கிறது'),
      DiagnosticCapture.stopped =>
        state.text('Stop callback observed', 'நிறுத்த அறிவிப்பு கிடைத்தது'),
      DiagnosticCapture.uncertain =>
        state.text('Uncertain', 'உறுதியாகத் தெரியவில்லை'),
      DiagnosticCapture.unknown =>
        state.text('Not observed', 'கவனிக்கப்படவில்லை'),
    };

String _mute(AppController state, DiagnosticMute value) => switch (value) {
      DiagnosticMute.muted => state.text('Muted', 'ஒலி முடக்கப்பட்டது'),
      DiagnosticMute.unmuted => state.text('Unmuted', 'ஒலி இயங்குகிறது'),
      DiagnosticMute.unknown => state.text('Not observed', 'கவனிக்கப்படவில்லை'),
    };

String _cleanup(AppController state, DiagnosticCleanup value) =>
    switch (value) {
      DiagnosticCleanup.requested => state.text(
          'Requested; awaiting confirmation',
          'கோரப்பட்டது; உறுதிக்காக காத்திருக்கிறது'),
      DiagnosticCleanup.pending => state.text(
          'Pending; shutdown is not confirmed',
          'நிலுவையில் உள்ளது; நிறுத்தம் உறுதியாகவில்லை'),
      DiagnosticCleanup.released => state.text(
          'Native release completed', 'சாதன இணைப்பு விடுவிக்கப்பட்டது'),
      DiagnosticCleanup.failed => state.text(
          'Failed; shutdown is not confirmed',
          'தோல்வி; நிறுத்தம் உறுதியாகவில்லை'),
      DiagnosticCleanup.notRequested =>
        state.text('Not requested', 'கோரப்படவில்லை'),
    };

String _failure(AppController state, DiagnosticFailure value) =>
    switch (value) {
      DiagnosticFailure.microphoneDenied => state.text(
          'Microphone permission denied', 'மைக்ரோஃபோன் அனுமதி மறுக்கப்பட்டது'),
      DiagnosticFailure.cameraDenied =>
        state.text('Camera permission denied', 'கேமரா அனுமதி மறுக்கப்பட்டது'),
      DiagnosticFailure.credentialsUnavailable => state.text(
          'Media authorization unavailable', 'ஊடக அனுமதி கிடைக்கவில்லை'),
      DiagnosticFailure.joinFailed =>
        state.text('Media join failed', 'ஊடக இணைப்பு தோல்வி'),
      DiagnosticFailure.connectionFailed =>
        state.text('Connection failed', 'இணைப்பு தோல்வி'),
      DiagnosticFailure.mediaFailure => state.text('Media error', 'ஊடகப் பிழை'),
      DiagnosticFailure.cleanupFailed => state.text(
          'Cleanup could not be confirmed',
          'நிறுத்தத்தை உறுதிப்படுத்த முடியவில்லை'),
    };

String _metric(AppController state, DiagnosticMetric value) => switch (value) {
      DiagnosticMetric.localPacketLossPercent => state.text(
          'Outgoing audio packet loss (%)',
          'வெளிச்செல்லும் ஒலிப் பொதி இழப்பு (%)'),
      DiagnosticMetric.localSentKbps => state.text(
          'Outgoing audio bitrate (Kbps)',
          'வெளிச்செல்லும் ஒலி தரவு வேகம் (Kbps)'),
      DiagnosticMetric.remoteFrameLossPercent => state.text(
          'Incoming audio frame loss (%)', 'உள்வரும் ஒலி சட்டக இழப்பு (%)'),
      DiagnosticMetric.remoteReceivedKbps => state.text(
          'Incoming audio bitrate (Kbps)', 'உள்வரும் ஒலி தரவு வேகம் (Kbps)'),
      DiagnosticMetric.networkTransportDelayMs => state.text(
          'Sender-to-receiver delay (ms)',
          'அனுப்புநரிலிருந்து பெறுநருக்கு தாமதம் (ms)'),
      DiagnosticMetric.jitterBufferDelayMs => state.text(
          'Receiver-to-buffer delay (ms)',
          'பெறுநரிலிருந்து இடையகத்திற்கு தாமதம் (ms)'),
      DiagnosticMetric.clientServerDelayMs => state.text(
          'Client-to-server delay (ms)',
          'சாதனத்திலிருந்து சேவையகத்திற்கு தாமதம் (ms)'),
    };
