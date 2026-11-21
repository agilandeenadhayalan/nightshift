import 'package:flutter/material.dart';
import '../core/controller.dart';

class InvitationSettings extends StatefulWidget {
  const InvitationSettings({super.key, required this.controller});
  final AppController controller;
  @override
  State<InvitationSettings> createState() => _InvitationSettingsState();
}

class _InvitationSettingsState extends State<InvitationSettings> {
  bool consent = false;
  Object? owner;
  @override
  Widget build(BuildContext context) {
    final state = widget.controller, model = state.invitations;
    if (owner != state.accountIdentity) {
      owner = state.accountIdentity;
      consent = false;
    }
    final text = state.text;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    text('Background audio invitations',
                        'பின்னணி ஆடியோ அழைப்பிதழ்கள்'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(text(
                    'For up to 30 minutes, receive a generic notification while you are available as a Listener. Open NightShift to check and answer. Delivery depends on Android settings and connectivity. Accepted calls still end when the app goes into the background.',
                    'கேட்பவராகக் கிடைக்கும்போது அதிகபட்சம் 30 நிமிடங்களுக்கு பொதுவான அறிவிப்பைப் பெறலாம். சரிபார்த்துப் பதிலளிக்க NightShift ஐத் திறக்கவும். அறிவிப்பு Android அமைப்புகள் மற்றும் இணைப்பைப் பொறுத்தது. ஏற்ற அழைப்பின்போது செயலி பின்னணிக்குச் சென்றால் அழைப்பு முடியும்.')),
                const SizedBox(height: 8),
                Text(model.active
                    ? text(
                        'Invitation window: ${model.remainingSeconds} seconds remaining.',
                        'அழைப்பிதழ் காலம்: இன்னும் ${model.remainingSeconds} வினாடிகள்.')
                    : text('Background invitations are off or not confirmed.',
                        'பின்னணி அழைப்பிதழ்கள் முடக்கப்பட்டுள்ளன அல்லது உறுதிப்படுத்தப்படவில்லை.')),
                if (!model.eligibleSession ||
                    (model.loaded && !model.capability.available))
                  Text(text(
                      'Requires verified phone sign-in, Android 8 or newer, and configured notification service.',
                      'சரிபார்க்கப்பட்ட தொலைபேசி உள்நுழைவு, Android 8 அல்லது புதிய பதிப்பு மற்றும் அமைக்கப்பட்ட அறிவிப்புச் சேவை தேவை.')),
                if (model.error != null)
                  Text(model.error!.code == 'PUSH_PERMISSION_REQUIRED'
                      ? text(
                          'Allow notifications and the Audio invitations channel in Android settings.',
                          'Android அமைப்புகளில் அறிவிப்புகளையும் ஆடியோ அழைப்பிதழ் சேனலையும் அனுமதிக்கவும்.')
                      : text(
                          'Setup could not be confirmed. Check status before retrying.',
                          'அமைப்பை உறுதிப்படுத்த முடியவில்லை. மீண்டும் முயலும் முன் நிலையைச் சரிபார்க்கவும்.')),
                if (model.uncertain != null)
                  Text(text(
                      'The previous request may have reached the server. No automatic retry will occur.',
                      'முந்தைய கோரிக்கை சேவையகத்தை அடைந்திருக்கலாம். தானாக மீண்டும் முயற்சிக்காது.')),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: !model.eligibleSession ||
                            model.busy ||
                            model.uncertain != null
                        ? null
                        : (value) => setState(() => consent = value ?? false),
                    title: Text(text(
                        'I agree to this temporary invitation window.',
                        'இந்தத் தற்காலிக அழைப்பிதழ் காலத்திற்கு ஒப்புக்கொள்கிறேன்.'))),
                FilledButton(
                    onPressed: !model.eligibleSession ||
                            !consent ||
                            model.busy ||
                            model.loading ||
                            model.uncertain != null
                        ? null
                        : () async {
                            await model.enable(consent: consent);
                            if (mounted) setState(() => consent = false);
                          },
                    child: Text(text(
                        model.active
                            ? 'Renew invitation window'
                            : 'Enable invitations',
                        model.active
                            ? 'அழைப்பிதழ் காலத்தைப் புதுப்பி'
                            : 'அழைப்பிதழ்களை இயக்கு'))),
                OutlinedButton(
                    onPressed:
                        model.loading || model.busy ? null : model.recover,
                    child: Text(text('Check invitation status',
                        'அழைப்பிதழ் நிலையைச் சரிபார்'))),
                if (model.uncertain != null)
                  OutlinedButton(
                      onPressed: model.retryAllowed && !model.busy
                          ? model.retry
                          : null,
                      child: Text(text('Retry the same request',
                          'அதே கோரிக்கையை மீண்டும் முயற்சி'))),
                OutlinedButton(
                    onPressed: model.registration != null ||
                            model.busy ||
                            model.uncertain != null
                        ? model.disable
                        : null,
                    child: Text(
                        text('Turn invitations off', 'அழைப்பிதழ்களை முடக்கு'))),
              ],
            )));
  }
}
