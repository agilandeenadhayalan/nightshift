import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'message_copy.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appControllerProvider).privacy.load());
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider), state = app.privacy;
    return Scaffold(
        appBar: AppBar(
            title: Text(
                app.text('Privacy and account', 'தனியுரிமை மற்றும் கணக்கு')),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: app.text('Back', 'பின்செல்'),
                onPressed: () => context
                    .go(app.needsOnboarding ? '/onboarding' : '/profile'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(
                      app.text(
                          'Your consent history', 'உங்கள் ஒப்புதல் வரலாறு'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (state.busy && !state.loaded)
                    const Center(child: CircularProgressIndicator()),
                  if (state.loaded && state.consents.isEmpty)
                    Text(app.text(
                        'No consent events are recorded for this account.',
                        'இந்தக் கணக்கிற்கு ஒப்புதல் நிகழ்வுகள் பதிவாகவில்லை.')),
                  for (final item in state.consents)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_purpose(
                                      item['purpose'] as String, app.locale)),
                                  Text(
                                      '${app.text('Notice', 'அறிவிப்பு')}: ${item['noticeVersion']}'),
                                  Text(item['granted'] == true
                                      ? app.text('Accepted', 'ஏற்கப்பட்டது')
                                      : app.text('Withdrawn',
                                          'திரும்பப் பெறப்பட்டது')),
                                  Text(_date(item['createdAt'] as String)),
                                ]))),
                  const SizedBox(height: 24),
                  Text(
                      app.text('Request account deletion',
                          'கணக்கு நீக்கத்தைக் கோரு'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (state.notice != null) ...[
                    Text(state.notice!['text'] as String,
                        key: const Key('deletion-server-notice')),
                    const SizedBox(height: 12),
                    Text(app.text(
                        'This private test request suspends the account and signs you out. Test credits become inaccessible and are not refundable or transferable. Illustrative Listener earnings are not payable. Profile data is removed where permitted; restricted financial or dispute evidence can remain pending a retention review. This does not confirm complete legal deletion.',
                        'இந்த தனிப்பட்ட சோதனைக் கோரிக்கை கணக்கை முடக்கி உங்களை வெளியேற்றும். சோதனை நாணயங்களை அணுக முடியாது; அவற்றை திருப்பித் தரவோ மாற்றவோ முடியாது. கேட்பவரின் சோதனை வருமானம் செலுத்தப்படாது. அனுமதிக்கப்பட்ட சுயவிவரத் தரவு நீக்கப்படும்; நிதி அல்லது சர்ச்சை ஆதாரங்கள் தக்கவைப்பு மதிப்பாய்விற்காக இருக்கலாம். இது முழுமையான சட்டபூர்வ நீக்கத்தை உறுதிசெய்யாது.')),
                    const SizedBox(height: 12),
                    Text(app.text(
                        'A new SMS sign-in within the last five minutes is required. Refreshing an existing session does not count. End any active call first.',
                        'கடந்த ஐந்து நிமிடங்களுக்குள் புதிய SMS உள்நுழைவு தேவை. பழைய அமர்வை புதுப்பிப்பது கணக்கில் வராது. செயலில் உள்ள அழைப்பை முதலில் முடிக்கவும்.')),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: state.canDelete
                            ? () async {
                                final owner = app.user?.id;
                                if (owner == null) return;
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        _DeletionConfirmation(app: app));
                                if (confirmed == true) {
                                  await state.submit(
                                      confirmed: true, expectedOwnerId: owner);
                                }
                              }
                            : null,
                        label: Text(app.text('Review deletion request',
                            'நீக்கக் கோரிக்கையை மதிப்பாய்வு செய்'))),
                  ],
                  if (state.errorCode != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(
                                errorMessage(state.errorCode, app.locale)))),
                  if (state.errorCode == 'FRESH_SIGN_IN_REQUIRED')
                    OutlinedButton(
                        onPressed: state.busy ? null : app.logout,
                        child: Text(app.text('Sign out for a new SMS sign-in',
                            'புதிய SMS உள்நுழைவிற்கு வெளியேறு'))),
                  if (!state.loaded && !state.busy)
                    OutlinedButton(
                        onPressed: state.load,
                        child: Text(app.text('Retry privacy information',
                            'தனியுரிமை தகவலை மீண்டும் ஏற்று'))),
                  if (state.hasSavedReceipt)
                    OutlinedButton(
                        onPressed: () => context.go('/deletion-status'),
                        child: Text(app.text('Check saved deletion receipt',
                            'சேமிக்கப்பட்ட நீக்க ரசீதை சரிபார்'))),
                ]))));
  }
}

class _DeletionConfirmation extends StatefulWidget {
  const _DeletionConfirmation({required this.app});
  final AppController app;
  @override
  State<_DeletionConfirmation> createState() => _DeletionConfirmationState();
}

class _DeletionConfirmationState extends State<_DeletionConfirmation> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AlertDialog(
        title: Text(app.text(
            'Submit deletion request?', 'நீக்கக் கோரிக்கையை சமர்ப்பிக்கவா?')),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(app.text(
              'This suspends your account immediately. Removed profile data cannot be restored through this app. Retained financial and dispute records still require review. Your recovery receipt stays on this device.',
              'இது உங்கள் கணக்கை உடனடியாக முடக்கும். நீக்கப்பட்ட சுயவிவரத் தரவை இந்த செயலியில் மீட்டெடுக்க முடியாது. தக்கவைக்கப்பட்ட நிதி மற்றும் சர்ச்சைப் பதிவுகளுக்கு மதிப்பாய்வு தேவை. மீட்பு ரசீது இந்தச் சாதனத்தில் இருக்கும்.')),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (value) => setState(() => confirmed = value ?? false),
              title: Text(app.text('I understand and want to request deletion.',
                  'புரிந்துகொண்டேன்; நீக்கத்தைக் கோர விரும்புகிறேன்.'))),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(app.text('Cancel', 'ரத்து'))),
          FilledButton(
              onPressed: confirmed ? () => Navigator.pop(context, true) : null,
              child: Text(app.text('Submit request', 'கோரிக்கையை சமர்ப்பி')))
        ]);
  }
}

class DeletionStatusScreen extends ConsumerStatefulWidget {
  const DeletionStatusScreen({super.key});
  @override
  ConsumerState<DeletionStatusScreen> createState() =>
      _DeletionStatusScreenState();
}

class _DeletionStatusScreenState extends ConsumerState<DeletionStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final privacy = ref.read(appControllerProvider).privacy;
      if (privacy.hasSavedReceipt && privacy.receipt == null) {
        unawaited(privacy.recoverStatus());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider),
        state = app.privacy,
        receipt = state.receipt;
    return Scaffold(
        appBar: AppBar(
            title: Text(app.text('Deletion receipt', 'நீக்க ரசீது')),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: app.text('Back', 'பின்செல்'),
                onPressed: () => context.go(app.user == null
                    ? '/login'
                    : app.needsOnboarding
                        ? '/onboarding'
                        : '/profile'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(app.text(
                      'This receipt is saved securely on this device. It can check your request after sign-out. Do not clear app data while you need it.',
                      'இந்த ரசீது சாதனத்தில் பாதுகாப்பாக சேமிக்கப்பட்டுள்ளது. வெளியேறிய பிறகும் கோரிக்கையை சரிபார்க்கலாம். இது தேவைப்படும்போது செயலித் தரவை அழிக்க வேண்டாம்.')),
                  if (state.savedReceiptChoices.length > 1) ...[
                    const SizedBox(height: 16),
                    Text(app.text('Choose a saved request',
                        'சேமிக்கப்பட்ட கோரிக்கையைத் தேர்வுசெய்')),
                    DropdownButton<int>(
                        key: const Key('deletion-receipt-selector'),
                        isExpanded: true,
                        itemHeight: null,
                        value: state.selectedReceiptIndex,
                        items: [
                          for (final choice in state.savedReceiptChoices)
                            DropdownMenuItem(
                                value: choice.index,
                                child: Text(
                                    '${app.text('Saved request', 'சேமிக்கப்பட்ட கோரிக்கை')} ${choice.index + 1} · ${choice.serviceHost}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: state.busy
                            ? null
                            : (index) {
                                if (index != null) state.selectReceipt(index);
                              }),
                  ],
                  if (receipt != null) ...[
                    const SizedBox(height: 20),
                    Text(
                        receipt['status'] == 'pending_hold'
                            ? app.text('Restricted records are on hold',
                                'கட்டுப்படுத்தப்பட்ட பதிவுகள் தக்கவைக்கப்பட்டுள்ளன')
                            : app.text('Retention review is required',
                                'தக்கவைப்பு மதிப்பாய்வு தேவை'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    SelectableText(
                        '${app.text('Request', 'கோரிக்கை')}: ${receipt['requestId']}'),
                    Text(
                        '${app.text('Requested', 'கோரப்பட்ட நேரம்')}: ${_date(receipt['requestedAt'] as String)}'),
                    Text(receipt['personalDataDeletedAt'] == null
                        ? app.text(
                            'Profile-data removal has not been confirmed.',
                            'சுயவிவரத் தரவு நீக்கம் உறுதிசெய்யப்படவில்லை.')
                        : app.text(
                            'Removable profile data was cleared. Restricted evidence may still remain.',
                            'நீக்கக்கூடிய சுயவிவரத் தரவு அழிக்கப்பட்டது. கட்டுப்படுத்தப்பட்ட ஆதாரங்கள் இன்னும் இருக்கலாம்.')),
                    for (final hold in receipt['holds'] as List)
                      Text(_hold(hold as String, app.locale)),
                    const SizedBox(height: 12),
                    Text(app.text(
                        'This test receipt does not confirm that all retained data has been deleted. Financial history remains unchanged; no refund or Listener payout is promised.',
                        'தக்கவைக்கப்பட்ட அனைத்து தரவும் நீக்கப்பட்டதை இந்த சோதனை ரசீது உறுதிசெய்யாது. நிதி வரலாறு மாற்றப்படாது; பணத்தைத் திருப்பித் தரவோ கேட்பவருக்கு பணம் செலுத்தவோ உறுதியில்லை.')),
                  ],
                  if (state.errorCode != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(
                                errorMessage(state.errorCode, app.locale)))),
                  const SizedBox(height: 20),
                  if (state.busy)
                    const Center(child: CircularProgressIndicator()),
                  OutlinedButton(
                      onPressed: state.busy || !state.hasSavedReceipt
                          ? null
                          : state.recoverStatus,
                      child: Text(app.text(
                          'Check request status', 'கோரிக்கை நிலையை சரிபார்'))),
                  if (!state.hasSavedReceipt)
                    Text(app.text('There is no saved receipt on this device.',
                        'இந்தச் சாதனத்தில் சேமிக்கப்பட்ட ரசீது இல்லை.')),
                ]))));
  }
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null
      ? '—'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.timeZoneName}';
}

String _purpose(String purpose, String locale) {
  final ta = locale == 'ta';
  return switch (purpose) {
    'phone_signin' ||
    'phone-signin' =>
      ta ? 'தொலைபேசி உள்நுழைவு' : 'Phone sign-in',
    'adult_onboarding' ||
    'adult-onboarding' ||
    'adult-service-onboarding' =>
      ta ? 'பெரியவர் சுயவிவரம்' : 'Adult profile',
    'account_deletion' ||
    'account-deletion' =>
      ta ? 'கணக்கு நீக்கம்' : 'Account deletion',
    'listener-review-material' =>
      ta ? 'கேட்பவர் மதிப்பாய்வு மாதிரி' : 'Listener review sample',
    _ => ta ? 'ஒப்புதல் பதிவு' : 'Consent record'
  };
}

String _hold(String hold, String locale) {
  final ta = locale == 'ta';
  return switch (hold) {
    'financial_records' ||
    'financial' ||
    'financial_pending' =>
      ta ? 'நிதிப் பதிவுகள் தக்கவைப்பு' : 'Financial-record retention',
    'dispute' ||
    'open_dispute' ||
    'dispute_open' ||
    'safety_evidence' ||
    'profile_evidence' =>
      ta
          ? 'சர்ச்சை அல்லது பாதுகாப்பு ஆதாரம் தக்கவைப்பு'
          : 'Dispute or safety evidence retention',
    'age_safety_review' =>
      ta ? 'வயது பாதுகாப்பு மதிப்பாய்வு தேவை' : 'Age-safety review required',
    'private_material_cleanup' => ta
        ? 'தனிப்பட்ட பொருட்கள் நீக்கம் நிலுவையில் உள்ளது'
        : 'Private material cleanup pending',
    _ => ta
        ? 'கட்டுப்படுத்தப்பட்ட ஆதாரம்: மதிப்பாய்வு தேவை'
        : 'Restricted evidence: review required'
  };
}
