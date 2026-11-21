import 'package:flutter/material.dart';
import '../core/models.dart';

/// Snapshot presentation only: no timer, wallet arithmetic or call mutation.
class CallAllowanceDisplay extends StatelessWidget {
  const CallAllowanceDisplay(
      {super.key,
      required this.call,
      required this.locale,
      this.endingLocally = false});

  final CallSession call;
  final String locale;
  final bool endingLocally;

  String text(String en, String ta) => locale == 'ta' ? ta : en;

  @override
  Widget build(BuildContext context) {
    final remaining = call.remainingConnectedMs;
    final seconds = remaining == null ? null : (remaining + 999) ~/ 1000;
    final warning = switch (call.durationLimitReason) {
      CallDurationLimitReason.testCreditBalance => text(
          'Test-credit call limit approaching',
          'சோதனை நாணயங்களுக்கான அழைப்பு நேர வரம்பு நெருங்குகிறது'),
      CallDurationLimitReason.testDurationCap => text(
          'Test call time limit approaching',
          'சோதனை அழைப்பின் நேர வரம்பு நெருங்குகிறது'),
      null => text('Call allowance nearly used',
          'அழைப்பிற்கான நேர ஒதுக்கீடு முடிவடைகிறது'),
    };
    return Semantics(
        container: true,
        // These values change with snapshots, not repeated live announcements.
        liveRegion: false,
        child: Column(children: [
          const SizedBox(height: 16),
          Text(
              remaining == null
                  ? text('Call time remaining unavailable',
                      'மீதமுள்ள அழைப்பு நேரம் கிடைக்கவில்லை')
                  : text('Confirmed call time remaining',
                      'உறுதிப்படுத்தப்பட்ட மீதமுள்ள அழைப்பு நேரம்'),
              textAlign: TextAlign.center),
          if (seconds != null) ...[
            Semantics(
                label: text(
                    '${seconds ~/ 60} minutes ${seconds % 60} seconds remaining',
                    '${seconds ~/ 60} நிமிடங்கள் ${seconds % 60} விநாடிகள் மீதம்'),
                child: ExcludeSemantics(
                    child: Text(durationLabel(seconds * 1000),
                        key: const ValueKey('call-remaining-value'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center))),
            Text(
                text('Allocated connected time. Charges may include a minimum.',
                    'ஒதுக்கப்பட்ட இணைப்பு நேரம். கட்டணத்தில் குறைந்தபட்ச தொகை இருக்கலாம்.'),
                textAlign: TextAlign.center),
          ],
          if (remaining != null && remaining <= 60000 && !endingLocally) ...[
            const SizedBox(height: 12),
            const Icon(Icons.info_outline),
            Text(
                remaining == 0
                    ? text('Call allowance exhausted',
                        'அழைப்பிற்கான நேர ஒதுக்கீடு முடிந்தது')
                    : warning,
                key: const ValueKey('call-allowance-warning'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall),
            if (remaining == 0)
              Text(
                  text(
                      'Waiting for server confirmation. You can still end the call.',
                      'சேவையக உறுதிப்படுத்தலுக்காக காத்திருக்கிறது. நீங்கள் அழைப்பை முடிக்கலாம்.'),
                  textAlign: TextAlign.center),
          ],
          if (call.state == 'reconnecting') ...[
            const SizedBox(height: 12),
            Text(
                text(
                    'Confirmed connection gaps are not charged. Recovery time is limited; the server ends the call if reconnection fails.',
                    'உறுதிப்படுத்தப்பட்ட இணைப்பு இடைவெளிகளுக்கு கட்டணம் இல்லை. மீண்டும் இணைவதற்கான நேரம் வரையறுக்கப்பட்டுள்ளது; இணைப்பு மீளவில்லை எனில் சேவையகம் அழைப்பை முடிக்கும்.'),
                textAlign: TextAlign.center),
          ],
        ]));
  }
}
