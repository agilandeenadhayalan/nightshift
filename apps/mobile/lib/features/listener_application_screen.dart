import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import 'message_copy.dart';
import 'redesign/design_system.dart';
import 'redesign/entry_designs.dart';
import 'redesign/entry_components.dart';

class ListenerApplicationScreen extends ConsumerStatefulWidget {
  const ListenerApplicationScreen({super.key});
  @override
  ConsumerState<ListenerApplicationScreen> createState() =>
      _ApplicationScreenState();
}

class _ApplicationScreenState extends ConsumerState<ListenerApplicationScreen> {
  final _bio = TextEditingController();
  @override
  void initState() {
    super.initState();
    final flow = ref.read(appControllerProvider).listenerApplication;
    Future.microtask(() {
      if (mounted) flow.load();
    });
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider),
        state = app.listenerApplication;
    if (_bio.text != state.bio) {
      _bio.value = TextEditingValue(
          text: state.bio,
          selection: TextSelection.collapsed(offset: state.bio.length));
    }
    final editing = state.canEdit;
    final status = state.application?['state'] as String? ?? 'new';
    final review = state.reviewOutcome;
    return Scaffold(
        appBar: AppBar(
            title:
                Text(app.text('Listener application', 'கேட்பவர் விண்ணப்பம்')),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: app.text('Back', 'பின்செல்'),
                onPressed: () => context.go('/profile'))),
        body: NightshiftBackdrop(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                        children: [
                          const Center(child: NightshiftBrand()),
                          const SizedBox(height: 28),
                          if (status == 'submitted') ...[
                            Text(
                                app.text('Almost done…',
                                    'கிட்டத்தட்ட முடிந்துவிட்டது…'),
                                key: const Key('live-application-pending'),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 28),
                            Center(
                                child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(colors: [
                                          Color(0xff412074),
                                          Color(0xff122b43)
                                        ]),
                                        border: Border.all(
                                            color:
                                                NsColors.cyan.withAlpha(95))),
                                    child: const Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 46,
                                        color: NsColors.cyan))),
                            const SizedBox(height: 28),
                            Text(
                                app.text('Application received',
                                    'விண்ணப்பம் பெறப்பட்டது'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge),
                          ] else ...[
                            Text(
                                app.text('Your voice is your superpower.',
                                    'உங்கள் குரலே உங்கள் பலம்.'),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const NightshiftEntryPortraitScene(
                                key: Key('live-listener-introduction')),
                            Text(
                                app.text('Make room for a conversation.',
                                    'உரையாடலுக்கு நேரம் ஒதுக்குங்கள்.'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: NsColors.cyan)),
                            const SizedBox(height: 24),
                            NightshiftSurface(
                                child: Column(children: [
                              Text(
                                  app.text('Customer + Listener',
                                      'வாடிக்கையாளர் + கேட்பவர்'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(
                                  app.text('One account. Two ways to connect.',
                                      'ஒரு கணக்கு. இணைய இரு வழிகள்.'),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 14),
                              Chip(
                                  label: Text(app.text('Test earnings only',
                                      'சோதனை வருமானம் மட்டுமே'))),
                            ])),
                          ],
                          const SizedBox(height: 12),
                          if (status == 'submitted') ...[
                            Text(
                                app.text(
                                    'A person reviews each private application. A review time or approval is not guaranteed.',
                                    'ஒவ்வொரு தனிப்பட்ட விண்ணப்பத்தையும் ஒருவர் ஆய்வு செய்வார். ஆய்வு நேரம் அல்லது அங்கீகாரம் உறுதியில்லை.'),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                                onPressed: state.busy ? null : state.load,
                                icon: const Icon(Icons.refresh),
                                label: Text(app.text(
                                    'Check saved application status',
                                    'சேமித்த விண்ணப்ப நிலையை சரிபார்'))),
                            const SizedBox(height: 20),
                          ] else ...[
                            Text(app.text(
                                'Applying is free for adults aged 18+. A person reviews your private application. Approval, earnings and a review date are not guaranteed. This build uses test credits only.',
                                '18 வயது நிரம்பிய பெரியவர்கள் இலவசமாக விண்ணப்பிக்கலாம். உங்கள் தனிப்பட்ட விண்ணப்பத்தை ஒருவர் ஆய்வு செய்வார். அங்கீகாரம், வருமானம் அல்லது ஆய்வுத் தேதி உறுதியில்லை. இந்தப் பதிப்பில் சோதனை நாணயங்கள் மட்டுமே பயன்படுத்தப்படும்.')),
                            const SizedBox(height: 20),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final entry in [
                                (
                                  19,
                                  app.text('Listener orientation',
                                      'கேட்பவர் அறிமுகம்'),
                                  Icons.school_outlined
                                ),
                                (
                                  26,
                                  app.text('Community guidelines',
                                      'சமூக வழிகாட்டுதல்கள்'),
                                  Icons.favorite_outline
                                ),
                                (
                                  28,
                                  app.text('Voice sample guide',
                                      'குரல் மாதிரி வழிகாட்டி'),
                                  Icons.graphic_eq
                                ),
                              ])
                                OutlinedButton.icon(
                                    key: Key('entry-guide-${entry.$1}'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) => EntryDesignScreen(
                                                designId: entry.$1,
                                                preview: false))),
                                    icon: Icon(entry.$3),
                                    label: Text(entry.$2)),
                            ]),
                            const SizedBox(height: 20),
                          ],
                          NightshiftSurface(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Icon(
                                    status == 'submitted'
                                        ? Icons.hourglass_top_rounded
                                        : status == 'approved'
                                            ? Icons.task_alt_rounded
                                            : Icons.edit_note_rounded,
                                    color: NsColors.cyan,
                                    size: 28),
                                const SizedBox(height: 12),
                                Text(_status(status, app.locale),
                                    key: const Key('application-status'),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  Chip(
                                      label: Text(app.text('Private profile',
                                          'தனிப்பட்ட சுயவிவரம்'))),
                                  Chip(
                                      label: Text(app.text(
                                          'Voice sample', 'குரல் மாதிரி'))),
                                  Chip(
                                      label: Text(app.text(
                                          'Human review', 'மனித ஆய்வு'))),
                                ]),
                              ])),
                          const SizedBox(height: 16),
                          if (status == 'submitted')
                            Text(app.text(
                                'Your application is waiting for review. Check status here. Submission does not enable Listener mode.',
                                'உங்கள் விண்ணப்பம் ஆய்வுக்காக காத்திருக்கிறது. இங்கே நிலையை சரிபார்க்கவும். சமர்ப்பித்ததால் கேட்பவர் முறை செயல்படாது.')),
                          if (status == 'needs_information')
                            Text(app.text(
                                'More information is needed. Update your draft and submit it for another review.',
                                'கூடுதல் தகவல் தேவை. உங்கள் வரைவை புதுப்பித்து மீண்டும் ஆய்வுக்கு சமர்ப்பிக்கவும்.')),
                          if (status == 'rejected')
                            Text(app.text(
                                'This application was not approved. This decision does not change your Customer account.',
                                'இந்த விண்ணப்பம் அங்கீகரிக்கப்படவில்லை. இந்த முடிவு உங்கள் வாடிக்கையாளர் கணக்கை மாற்றாது.')),
                          if (review != null) ...[
                            const SizedBox(height: 16),
                            Text(app.text('Review update', 'ஆய்வு முடிவு'),
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                review['message']
                                        [app.locale == 'ta' ? 'ta' : 'en']
                                    as String,
                                key: const Key('application-review-message')),
                            for (final check in review['missingChecks'] as List)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(check['label']
                                          [app.locale == 'ta' ? 'ta' : 'en']
                                      as String)),
                            if (review['outcome'] == 'approved')
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                      switch (review['entitlement']) {
                                        'active' => app.text(
                                            'Listener access is active. Refresh your profile to switch modes when you are ready.',
                                            'கேட்பவர் அணுகல் செயல்பாட்டில் உள்ளது. நீங்கள் தயாரானதும் முறையை மாற்ற உங்கள் சுயவிவரத்தை புதுப்பிக்கவும்.'),
                                        'withheld' => app.text(
                                            'Listener access is currently unavailable. Your review decision is recorded.',
                                            'கேட்பவர் அணுகல் தற்போது கிடைக்கவில்லை. உங்கள் ஆய்வு முடிவு பதிவு செய்யப்பட்டுள்ளது.'),
                                        _ => app.text(
                                            'Approval recorded. Listener access is still being processed; check again shortly.',
                                            'ஒப்புதல் பதிவு செய்யப்பட்டது. கேட்பவர் அணுகல் இன்னும் செயலாக்கப்படுகிறது; சிறிது நேரத்தில் மீண்டும் சரிபார்க்கவும்.'),
                                      },
                                      key: const Key(
                                          'application-review-entitlement'))),
                          ],
                          if (state.reviewErrorCode != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                    app.text(
                                        'The review update could not be loaded. Check your saved application status again.',
                                        'ஆய்வு முடிவை ஏற்ற முடியவில்லை. சேமித்த விண்ணப்ப நிலையை மீண்டும் சரிபார்க்கவும்.'),
                                    key:
                                        const Key('application-review-error'))),
                          if (state.busy)
                            const Padding(
                                padding: EdgeInsets.all(12),
                                child: LinearProgressIndicator()),
                          if (state.errorCode != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    errorMessage(state.errorCode, app.locale),
                                    key: const Key('application-error'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (status != 'submitted')
                            OutlinedButton.icon(
                                onPressed: state.busy ? null : state.load,
                                icon: const Icon(Icons.refresh),
                                label: Text(app.text(
                                    state.dirty
                                        ? 'Reload saved draft (discards edits)'
                                        : 'Check saved application status',
                                    state.dirty
                                        ? 'சேமித்த வரைவை ஏற்று (மாற்றங்கள் நீங்கும்)'
                                        : 'சேமித்த விண்ணப்ப நிலையை சரிபார்'))),
                          if (state.loaded) ...[
                            const SizedBox(height: 20),
                            Text(
                                app.text('A little about you',
                                    'உங்களை பற்றி சிறிது'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            TextField(
                                key: const Key('application-bio'),
                                controller: _bio,
                                enabled: editing,
                                minLines: 3,
                                maxLines: 7,
                                maxLength: 1000,
                                decoration: InputDecoration(
                                    labelText:
                                        app.text('About you', 'உங்களைப் பற்றி'),
                                    helperText: app.text(
                                        'Do not include phone numbers or contact details.',
                                        'தொலைபேசி எண் அல்லது தொடர்பு விவரங்களை சேர்க்க வேண்டாம்.'),
                                    helperMaxLines: 3),
                                onChanged: (value) =>
                                    state.edit(newBio: value)),
                            const SizedBox(height: 16),
                            Text(
                                app.text('Conversation topics',
                                    'உரையாடல் தலைப்புகள்'),
                                style: Theme.of(context).textTheme.titleMedium),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              for (final topic in const [
                                'everyday',
                                'work',
                                'study',
                                'hobbies',
                                'language-practice'
                              ])
                                FilterChip(
                                    label: Text(_topic(topic, app.locale)),
                                    selected: state.topics.contains(topic),
                                    onSelected: !editing
                                        ? null
                                        : (selected) {
                                            final next = {...state.topics};
                                            selected
                                                ? next.add(topic)
                                                : next.remove(topic);
                                            state.edit(newTopics: next);
                                          })
                            ]),
                            const SizedBox(height: 16),
                            Text(
                                app.text('Languages you can speak',
                                    'நீங்கள் பேசக்கூடிய மொழிகள்'),
                                style: Theme.of(context).textTheme.titleMedium),
                            Wrap(spacing: 8, children: [
                              for (final language in const ['ta', 'en'])
                                FilterChip(
                                    label: Text(
                                        language == 'ta' ? 'தமிழ்' : 'English'),
                                    selected:
                                        state.languages.contains(language),
                                    onSelected: !editing
                                        ? null
                                        : (selected) {
                                            final next = {...state.languages};
                                            selected
                                                ? next.add(language)
                                                : next.remove(language);
                                            if (next.isNotEmpty) {
                                              state.edit(newLanguages: next);
                                            }
                                          })
                            ]),
                            const SizedBox(height: 20),
                            Text(
                                app.text('Private voice review sample',
                                    'தனிப்பட்ட குரல் ஆய்வு மாதிரி'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            NightshiftVoiceSampleVisual(
                                key: const Key('live-voice-sample'),
                                title: app.text(
                                    'Your introduction, in your own words.',
                                    'உங்கள் அறிமுகம், உங்கள் சொற்களில்.'),
                                caption: app.text(
                                    '2–60 seconds · private WAV sample',
                                    '2–60 விநாடிகள் · தனிப்பட்ட WAV மாதிரி')),
                            const SizedBox(height: 16),
                            Text(app.text(
                                'Choose an existing WAV file. Nothing is recorded automatically. The sample is for human review; it is not proof of age, gender or identity. Age is self-declared and any further verification is a separate process.',
                                'ஏற்கனவே உள்ள WAV கோப்பை தேர்ந்தெடுக்கவும். தானாக எதுவும் பதிவு செய்யப்படாது. இது மனித ஆய்வுக்கான மாதிரி; வயது, பாலினம் அல்லது அடையாளத்திற்கான சான்று அல்ல. வயது சுயமாக அறிவிக்கப்படுகிறது; கூடுதல் சரிபார்ப்பு தனி நடைமுறையாகும்.')),
                            CheckboxListTile(
                                key: const Key('application-consent'),
                                contentPadding: EdgeInsets.zero,
                                value: state.consent,
                                onChanged: !editing
                                    ? null
                                    : (value) =>
                                        state.edit(newConsent: value ?? false),
                                title: Text(app.text(
                                    'I consent to private storage and human review of my voice sample for this application.',
                                    'இந்த விண்ணப்பத்திற்காக எனது குரல் மாதிரியை தனிப்பட்ட முறையில் சேமித்து ஒருவர் ஆய்வு செய்வதற்கு ஒப்புக்கொள்கிறேன்.'))),
                            if (state.editable) ...[
                              FilledButton(
                                  onPressed: state.busy || state.uncertain
                                      ? null
                                      : state.save,
                                  child: Text(
                                      app.text('Save draft', 'வரைவை சேமி'))),
                              const SizedBox(height: 12),
                              Text(app.text(
                                  'Save your consent before selecting a file. WAV: 2–60 seconds, up to 2 MiB, PCM 16-bit, mono or stereo, 8–48 kHz, without metadata. The server checks the file before accepting it.',
                                  'கோப்பை தேர்ந்தெடுக்கும் முன் ஒப்புதலை சேமிக்கவும். WAV: 2–60 விநாடிகள், அதிகபட்சம் 2 MiB, PCM 16-bit, மோனோ அல்லது ஸ்டீரியோ, 8–48 kHz, மெட்டாடேட்டா இல்லாமல். சேவையகம் கோப்பை சரிபார்த்து ஏற்கும்.')),
                              OutlinedButton.icon(
                                  onPressed: state.busy ||
                                          !state.consent ||
                                          state.dirty ||
                                          state.uncertain ||
                                          state.application == null
                                      ? null
                                      : state.chooseSample,
                                  icon: const Icon(Icons.audio_file_outlined),
                                  label: Text(app.text(
                                      'Choose private WAV sample',
                                      'தனிப்பட்ட WAV மாதிரியை தேர்ந்தெடு'))),
                              if (state.sample != null) ...[
                                Text(app.text(
                                    'Selected sample: ${state.sample!.seconds.toStringAsFixed(1)} seconds. Not uploaded yet.',
                                    'தேர்ந்தெடுத்த மாதிரி: ${state.sample!.seconds.toStringAsFixed(1)} விநாடிகள். இன்னும் பதிவேற்றப்படவில்லை.')),
                                OutlinedButton(
                                    onPressed: state.busy || state.uncertain
                                        ? null
                                        : state.upload,
                                    child: Text(app.text(
                                        'Upload selected sample',
                                        'தேர்ந்தெடுத்த மாதிரியை பதிவேற்று'))),
                              ],
                              Text(state.application?['voiceSampleUploadId'] ==
                                      null
                                  ? app.text('No accepted sample yet.',
                                      'ஏற்கப்பட்ட மாதிரி இன்னும் இல்லை.')
                                  : app.text(
                                      'A private sample has been accepted for this application.',
                                      'இந்த விண்ணப்பத்திற்கான தனிப்பட்ட மாதிரி ஏற்கப்பட்டுள்ளது.')),
                              const SizedBox(height: 20),
                              FilledButton(
                                  key: const Key('application-submit'),
                                  onPressed:
                                      state.canSubmit ? state.submit : null,
                                  child: Text(app.text('Submit for review',
                                      'ஆய்வுக்கு சமர்ப்பி'))),
                            ],
                            if (state.canWithdraw)
                              TextButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                                title: Text(app.text(
                                                    'Withdraw voice consent?',
                                                    'குரல் ஒப்புதலை திரும்பப் பெறவா?')),
                                                content: SingleChildScrollView(
                                                    child: Text(app.text(
                                                        'This removes your voice sample and stops any pending application review. An existing approval or rejection remains on record.',
                                                        'இது உங்கள் குரல் மாதிரியை நீக்கி நிலுவையில் உள்ள விண்ணப்ப ஆய்வை நிறுத்தும். ஏற்கனவே வழங்கப்பட்ட அங்கீகாரம் அல்லது நிராகரிப்பு பதிவில் இருக்கும்.'))),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child: Text(app.text(
                                                          'Keep application',
                                                          'விண்ணப்பத்தை வைத்திரு'))),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child: Text(app.text(
                                                          'Withdraw consent',
                                                          'ஒப்புதலை திரும்பப் பெறு')))
                                                ]));
                                    if (confirmed == true && mounted) {
                                      await state.withdraw(confirmed: true);
                                    }
                                  },
                                  child: Text(app.text(
                                      'Remove sample and withdraw consent',
                                      'மாதிரியை நீக்கி ஒப்புதலை திரும்பப் பெறு'))),
                          ],
                        ])))));
  }
}

String _status(String value, String locale) {
  final labels = {
    'new': ('Start an application', 'விண்ணப்பத்தை தொடங்கு'),
    'draft': ('Draft', 'வரைவு'),
    'submitted': ('Submitted for review', 'ஆய்வுக்கு சமர்ப்பிக்கப்பட்டது'),
    'needs_information': ('More information needed', 'கூடுதல் தகவல் தேவை'),
    'approved': ('Approved', 'அங்கீகரிக்கப்பட்டது'),
    'rejected': ('Not approved', 'அங்கீகரிக்கப்படவில்லை'),
    'withdrawn': ('Withdrawn', 'திரும்பப் பெறப்பட்டது'),
  };
  final text = labels[value] ?? labels['new']!;
  return locale == 'ta' ? text.$2 : text.$1;
}

String _topic(String value, String locale) {
  final text = switch (value) {
    'work' => ('Work', 'வேலை'),
    'study' => ('Study', 'படிப்பு'),
    'hobbies' => ('Hobbies', 'பொழுதுபோக்கு'),
    'language-practice' => ('Language practice', 'மொழிப் பயிற்சி'),
    _ => ('Everyday life', 'அன்றாட வாழ்க்கை')
  };
  return locale == 'ta' ? text.$2 : text.$1;
}
