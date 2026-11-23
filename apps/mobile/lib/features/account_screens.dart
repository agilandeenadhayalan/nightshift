import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/phone_sign_in.dart';
import 'message_copy.dart';
import 'redesign/design_system.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen(
      {super.key, this.preview = false, this.previewCode = false});
  final bool preview, previewCode;
  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController(), _code = TextEditingController();
  Timer? _timer;
  late final PhoneSignIn _flow;
  @override
  void initState() {
    super.initState();
    _flow = ref.read(appControllerProvider).phoneSignIn;
    if (!widget.preview) {
      _timer = Timer.periodic(const Duration(seconds: 1),
          (_) => ref.read(appControllerProvider).phoneSignIn.tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!widget.preview) _flow.reset(notify: false);
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider), state = app.phoneSignIn;
    final enteringCode =
        widget.preview ? widget.previewCode : state.challengeId != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(app.text('Phone sign-in', 'தொலைபேசி உள்நுழைவு')),
          leading: IconButton(
              tooltip: app.text('Back', 'பின்செல்'),
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.preview
                  ? null
                  : () {
                      state.reset();
                      context.go('/login');
                    })),
      body: NightshiftBackdrop(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AccountHeader(
                                icon: enteringCode
                                    ? Icons.sms_outlined
                                    : Icons.phone_iphone_rounded,
                                title:
                                    enteringCode
                                        ? app.text('Enter your code',
                                            'உங்கள் குறியீட்டை உள்ளிடவும்')
                                        : app.text('Login to get started',
                                            'தொடங்க உள்நுழையவும்'),
                                subtitle: enteringCode
                                    ? app.text(
                                        'Your private sign-in, one step away.',
                                        'உங்கள் தனிப்பட்ட உள்நுழைவிற்கு இன்னும் ஒரு படி.')
                                    : app.text(
                                        'A conversation starts with you.',
                                        'உரையாடல் உங்களிடமிருந்து தொடங்குகிறது.')),
                            const SizedBox(height: 24),
                            if (widget.preview)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                      app.text(
                                          'Design preview · no SMS is sent',
                                          'வடிவமைப்பு முன்னோட்டம் · SMS அனுப்பப்படாது'),
                                      style: const TextStyle(
                                          color: NsColors.cyan))),
                            Text(app.text(
                                'Your phone number is private. Other people see your public nickname only.',
                                'உங்கள் தொலைபேசி எண் தனிப்பட்டது. மற்றவர்களுக்கு உங்கள் பொதுப் பெயர் மட்டுமே தெரியும்.')),
                            const SizedBox(height: 20),
                            if (!state.configured && !widget.preview) ...[
                              Text(app.text(
                                  'Phone sign-in is unavailable in this build.',
                                  'இந்த செயலியில் தொலைபேசி உள்நுழைவு தற்போது கிடைக்கவில்லை.')),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                                controller: _phone,
                                key: const Key('phone-number'),
                                keyboardType: TextInputType.phone,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                decoration: InputDecoration(
                                    labelText: app.text('Indian mobile number',
                                        'இந்திய மொபைல் எண்'),
                                    prefixText: '+91 ',
                                    prefixIcon:
                                        const Icon(Icons.phone_outlined)),
                                onChanged: (value) {
                                  if (widget.preview) return;
                                  state.editPhone(value);
                                  _code.clear();
                                }),
                            CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: !widget.preview && state.consent,
                                onChanged: widget.preview
                                    ? null
                                    : (value) =>
                                        state.setConsent(value ?? false),
                                title: Text(app.text(
                                    'I agree to receive an SMS sign-in code. Google receives and stores my phone number for sign-in and spam and abuse prevention across Google services. Standard SMS rates may apply.',
                                    'SMS உள்நுழைவுக் குறியீட்டைப் பெற ஒப்புக்கொள்கிறேன். உள்நுழைவு மற்றும் Google சேவைகளில் தேவையற்ற செய்திகள், முறைகேடுகளைத் தடுக்க Google என் எண்ணைப் பெற்று சேமிக்கும். வழக்கமான SMS கட்டணங்கள் பொருந்தலாம்.'))),
                            if (state.retrySeconds > 0 && !widget.preview)
                              Text(app.text(
                                  'Request another code in ${state.retrySeconds}s.',
                                  '${state.retrySeconds} வினாடிகளுக்குப் பிறகு மற்றொரு குறியீட்டைக் கோரலாம்.')),
                            FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: NsColors.cyan,
                                    foregroundColor: NsColors.background),
                                onPressed: !widget.preview && state.canRequest
                                    ? () => state.requestCode()
                                    : null,
                                child: Text(app.text(
                                    state.challengeId == null
                                        ? 'Send code'
                                        : 'Send a new code',
                                    state.challengeId == null
                                        ? 'குறியீட்டை அனுப்பு'
                                        : 'புதிய குறியீட்டை அனுப்பு'))),
                            const SizedBox(height: 20),
                            if (enteringCode) ...[
                              TextField(
                                  controller: _code,
                                  key: const Key('phone-code'),
                                  keyboardType: TextInputType.number,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  obscureText: true,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 26,
                                      letterSpacing: 10,
                                      fontWeight: FontWeight.w700),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode
                                  ],
                                  decoration: InputDecoration(
                                      labelText: app.text('Six-digit code',
                                          'ஆறு இலக்கக் குறியீடு'))),
                              if (state.expired && !widget.preview)
                                Text(errorMessage(
                                    state.nativePhone
                                        ? 'PHONE_ADMISSION_EXPIRED'
                                        : 'OTP_EXPIRED',
                                    app.locale)),
                              if (state.autoRetrievalEnded &&
                                  !state.expired &&
                                  !widget.preview)
                                Text(app.text(
                                    'Automatic code reading ended. You can still enter the code manually.',
                                    'தானாக குறியீடு படிப்பது முடிந்தது. குறியீட்டை நீங்களே இன்னும் உள்ளிடலாம்.')),
                              FilledButton(
                                  onPressed: !widget.preview && state.canVerify
                                      ? () async {
                                          await state.verifyCode(_code.text);
                                          if (mounted) _code.clear();
                                        }
                                      : null,
                                  child: Text(app.text('Verify and continue',
                                      'சரிபார்த்து தொடரவும்'))),
                            ],
                            if (state.busy && !widget.preview)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator())),
                            if (state.errorCode != null && !widget.preview)
                              Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Text(errorMessage(
                                          state.errorCode, app.locale)))),
                            if (app.canRestorePhoneSession && !widget.preview)
                              TextButton(
                                  onPressed:
                                      app.busy ? null : app.restorePhoneSession,
                                  child: Text(app.text(
                                      'Restore previous sign-in',
                                      'முந்தைய உள்நுழைவை மீட்டமை'))),
                            if (app.errorCode != null && !widget.preview)
                              Text(errorMessage(app.errorCode, app.locale)),
                            const SizedBox(height: 24),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lock_outline,
                                      size: 18, color: NsColors.cyan),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(
                                          app.text(
                                              'Your phone number is never shown on your public profile.',
                                              'உங்கள் பொதுச் சுயவிவரத்தில் தொலைபேசி எண் காட்டப்படாது.'),
                                          style: const TextStyle(
                                              color: NsColors.muted))),
                                ]),
                          ]))))),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController(), _dob = TextEditingController();
  String _avatar = 'moon', _interfaceLanguage = 'en';
  final Set<String> _languages = {'ta'};
  bool _consent = false, _loaded = false;
  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.onboardingProfile;
    if (!_loaded && profile != null) {
      _loaded = true;
      _name.text = profile['displayName'] as String? ?? '';
      _dob.text = profile['dateOfBirth'] as String? ?? '';
      _avatar = profile['avatarCode'] as String? ?? 'moon';
      _interfaceLanguage =
          profile['interfaceLanguage'] as String? ?? app.locale;
      _languages
        ..clear()
        ..addAll(List<String>.from(profile['languages'] ?? ['ta']));
    }
    if (profile?['dateOfBirth'] is String) {
      _dob.text = profile!['dateOfBirth'] as String;
    }
    return Scaffold(
        appBar: AppBar(
            title: Text(app.text('Your profile', 'உங்கள் சுயவிவரம்')),
            actions: [
              IconButton(
                  onPressed: () => context.go('/privacy'),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  tooltip: app.text('Privacy and account deletion',
                      'தனியுரிமை மற்றும் கணக்கு நீக்கம்')),
              TextButton(
                  onPressed: app.busy ? null : app.logout,
                  child: Text(app.text('Sign out', 'வெளியேறு'))),
            ]),
        body: NightshiftBackdrop(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                        children: [
                          _AccountHeader(
                              icon: Icons.person_outline_rounded,
                              title: app.text('Make yourself at home',
                                  'உங்களை அறிமுகப்படுத்துங்கள்'),
                              subtitle: app.text(
                                  'A private introduction. A public alias.',
                                  'தனிப்பட்ட அறிமுகம். பொதுவில் ஒரு புனைப்பெயர்.')),
                          const SizedBox(height: 24),
                          Text(
                              app.text(
                                  'NightShift is for adults aged 18 and over.',
                                  'NightShift 18 வயது மற்றும் அதற்கு மேற்பட்ட பெரியவர்களுக்கானது.'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Text(app.text(
                              'Your date of birth stays private. Age is self-declared, not verified identity. Once saved, your date of birth cannot be changed here.',
                              'உங்கள் பிறந்த தேதி தனிப்பட்டதாக இருக்கும். வயது நீங்கள் அறிவிப்பது; சரிபார்க்கப்பட்ட அடையாளம் அல்ல. சேமித்த பிறகு பிறந்த தேதியை இங்கு மாற்ற முடியாது.')),
                          const SizedBox(height: 20),
                          TextField(
                              controller: _dob,
                              key: const Key('onboarding-dob'),
                              enabled:
                                  !app.busy && profile?['dateOfBirth'] == null,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                  labelText: app.text(
                                      'Date of birth (YYYY-MM-DD)',
                                      'பிறந்த தேதி (YYYY-MM-DD)'),
                                  hintText: '2000-01-31')),
                          const SizedBox(height: 16),
                          TextField(
                              controller: _name,
                              key: const Key('onboarding-nickname'),
                              enabled: !app.busy,
                              maxLength: 40,
                              decoration: InputDecoration(
                                  labelText: app.text('Preferred nickname',
                                      'விருப்பப் பெயர்'))),
                          Text(app.text(
                              'Your nickname needs review before it appears publicly. Until then, others see your assigned alias.',
                              'உங்கள் பெயர் பொதுவில் தோன்றுவதற்கு முன் மதிப்பாய்வு தேவை. அதுவரை ஒதுக்கப்பட்ட பெயர் தெரியும்.')),
                          const SizedBox(height: 16),
                          Center(
                              child: NightshiftAvatar(
                                  name:
                                      app.text('Your avatar', 'உங்கள் அவதாரம்'),
                                  size: 88)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              value: _avatar,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: app.text('Avatar', 'அவதாரம்')),
                              items: [
                                for (final entry in <String, String>{
                                  'moon': app.text('Moon', 'நிலா'),
                                  'star': app.text('Star', 'நட்சத்திரம்'),
                                  'leaf': app.text('Leaf', 'இலை'),
                                  'wave': app.text('Wave', 'அலை')
                                }.entries)
                                  DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value))
                              ],
                              onChanged: app.busy
                                  ? null
                                  : (value) =>
                                      setState(() => _avatar = value!)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              value: _interfaceLanguage,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: app.text(
                                      'Interface language', 'செயலி மொழி')),
                              items: const [
                                DropdownMenuItem(
                                    value: 'en', child: Text('English')),
                                DropdownMenuItem(
                                    value: 'ta', child: Text('தமிழ்'))
                              ],
                              onChanged: app.busy
                                  ? null
                                  : (value) => setState(
                                      () => _interfaceLanguage = value!)),
                          const SizedBox(height: 16),
                          Text(app.text(
                              'Languages you speak', 'நீங்கள் பேசும் மொழிகள்')),
                          Wrap(spacing: 12, children: [
                            for (final language in ['ta', 'en'])
                              FilterChip(
                                  label: Text(
                                      language == 'ta' ? 'தமிழ்' : 'English'),
                                  selected: _languages.contains(language),
                                  onSelected: app.busy
                                      ? null
                                      : (selected) => setState(() {
                                            if (selected) {
                                              _languages.add(language);
                                            } else {
                                              _languages.remove(language);
                                            }
                                          }))
                          ]),
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _consent,
                              onChanged: app.busy
                                  ? null
                                  : (value) =>
                                      setState(() => _consent = value ?? false),
                              title: Text(app.text(
                                  'I confirm my date of birth is correct and agree to this private test profile and adult-service notice.',
                                  'என் பிறந்த தேதி சரியானது என உறுதிசெய்து, இந்த தனிப்பட்ட சோதனை சுயவிவரம் மற்றும் பெரியவர்களுக்கான சேவை அறிவிப்பை ஏற்கிறேன்.'))),
                          if (app.errorCode != null)
                            Semantics(
                                liveRegion: true,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(errorMessage(
                                        app.errorCode, app.locale)))),
                          FilledButton(
                              onPressed: !app.busy &&
                                      _consent &&
                                      _languages.isNotEmpty
                                  ? () =>
                                      app.completeOnboarding(<String, dynamic>{
                                        'dateOfBirth': _dob.text.trim(),
                                        'displayName': _name.text.trim(),
                                        'avatarCode': _avatar,
                                        'interfaceLanguage': _interfaceLanguage,
                                        'languages': _languages.toList(),
                                      })
                                  : null,
                              child: Text(app.text(
                                  'Save and continue', 'சேமித்து தொடரவும்'))),
                        ])))));
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Center(child: NightshiftBrand(size: 28)),
        const SizedBox(height: 28),
        Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                    colors: [Color(0xFF382263), Color(0xFF123047)]),
                border: Border.all(color: NsColors.cyan.withAlpha(80))),
            child: Icon(icon, color: NsColors.cyan, size: 38)),
        const SizedBox(height: 24),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.muted)),
      ]);
}
