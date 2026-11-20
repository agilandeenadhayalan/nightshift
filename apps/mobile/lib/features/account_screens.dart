import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/phone_sign_in.dart';
import 'message_copy.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});
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
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) => ref.read(appControllerProvider).phoneSignIn.tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flow.reset(notify: false);
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider), state = app.phoneSignIn;
    return Scaffold(
      appBar: AppBar(
          title: Text(app.text('Phone sign-in', 'தொலைபேசி உள்நுழைவு')),
          leading: IconButton(
              tooltip: app.text('Back', 'பின்செல்'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                state.reset();
                context.go('/login');
              })),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text(app.text('Sign in privately', 'தனிப்பட்ட உள்நுழைவு'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(app.text(
                    'Your phone number is private. Other people see your public nickname only.',
                    'உங்கள் தொலைபேசி எண் தனிப்பட்டது. மற்றவர்களுக்கு உங்கள் பொதுப் பெயர் மட்டுமே தெரியும்.')),
                const SizedBox(height: 20),
                if (!state.configured) ...[
                  Text(app.text('Phone sign-in is unavailable in this build.',
                      'இந்த செயலியில் தொலைபேசி உள்நுழைவு தற்போது கிடைக்கவில்லை.')),
                  const SizedBox(height: 16),
                ],
                TextField(
                    controller: _phone,
                    key: const Key('phone-number'),
                    keyboardType: TextInputType.phone,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                        labelText: app.text(
                            'Indian mobile number', 'இந்திய மொபைல் எண்'),
                        prefixText: '+91 '),
                    onChanged: (value) {
                      state.editPhone(value);
                      _code.clear();
                    }),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.consent,
                    onChanged: state.busy
                        ? null
                        : (value) => state.setConsent(value ?? false),
                    title: Text(app.text(
                        'I agree to use my number for an SMS sign-in code and to use Firebase to securely verify my sign-in.',
                        'SMS உள்நுழைவுக் குறியீட்டிற்கு என் எண்ணைப் பயன்படுத்தவும், Firebase மூலம் என் உள்நுழைவை பாதுகாப்பாக சரிபார்க்கவும் ஒப்புக்கொள்கிறேன்.'))),
                if (state.retrySeconds > 0)
                  Text(app.text(
                      'Request another code in ${state.retrySeconds}s.',
                      '${state.retrySeconds} வினாடிகளுக்குப் பிறகு மற்றொரு குறியீட்டைக் கோரலாம்.')),
                FilledButton(
                    onPressed:
                        state.canRequest ? () => state.requestCode() : null,
                    child: Text(app.text(
                        state.challengeId == null
                            ? 'Send code'
                            : 'Send a new code',
                        state.challengeId == null
                            ? 'குறியீட்டை அனுப்பு'
                            : 'புதிய குறியீட்டை அனுப்பு'))),
                const SizedBox(height: 20),
                if (state.challengeId != null) ...[
                  TextField(
                      controller: _code,
                      key: const Key('phone-code'),
                      keyboardType: TextInputType.number,
                      autocorrect: false,
                      enableSuggestions: false,
                      obscureText: true,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: InputDecoration(
                          labelText: app.text(
                              'Six-digit code', 'ஆறு இலக்கக் குறியீடு'))),
                  if (state.expired)
                    Text(errorMessage('OTP_EXPIRED', app.locale)),
                  FilledButton(
                      onPressed: state.canVerify
                          ? () async {
                              await state.verifyCode(_code.text);
                              _code.clear();
                            }
                          : null,
                      child: Text(app.text(
                          'Verify and continue', 'சரிபார்த்து தொடரவும்'))),
                ],
                if (state.busy)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator())),
                if (state.errorCode != null)
                  Semantics(
                      liveRegion: true,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child:
                              Text(errorMessage(state.errorCode, app.locale)))),
                if (app.canRestorePhoneSession)
                  TextButton(
                      onPressed: app.busy ? null : app.restorePhoneSession,
                      child: Text(app.text('Restore previous sign-in',
                          'முந்தைய உள்நுழைவை மீட்டமை'))),
                if (app.errorCode != null)
                  Text(errorMessage(app.errorCode, app.locale)),
              ]))),
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
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text(
                      app.text('NightShift is for adults aged 18 and over.',
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
                      enabled: !app.busy && profile?['dateOfBirth'] == null,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                          labelText: app.text('Date of birth (YYYY-MM-DD)',
                              'பிறந்த தேதி (YYYY-MM-DD)'),
                          hintText: '2000-01-31')),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _name,
                      key: const Key('onboarding-nickname'),
                      enabled: !app.busy,
                      maxLength: 40,
                      decoration: InputDecoration(
                          labelText: app.text(
                              'Preferred nickname', 'விருப்பப் பெயர்'))),
                  Text(app.text(
                      'Your nickname needs review before it appears publicly. Until then, others see your assigned alias.',
                      'உங்கள் பெயர் பொதுவில் தோன்றுவதற்கு முன் மதிப்பாய்வு தேவை. அதுவரை ஒதுக்கப்பட்ட பெயர் தெரியும்.')),
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
                              value: entry.key, child: Text(entry.value))
                      ],
                      onChanged: app.busy
                          ? null
                          : (value) => setState(() => _avatar = value!)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      value: _interfaceLanguage,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText:
                              app.text('Interface language', 'செயலி மொழி')),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ta', child: Text('தமிழ்'))
                      ],
                      onChanged: app.busy
                          ? null
                          : (value) =>
                              setState(() => _interfaceLanguage = value!)),
                  const SizedBox(height: 16),
                  Text(app.text(
                      'Languages you speak', 'நீங்கள் பேசும் மொழிகள்')),
                  Wrap(spacing: 12, children: [
                    for (final language in ['ta', 'en'])
                      FilterChip(
                          label: Text(language == 'ta' ? 'தமிழ்' : 'English'),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child:
                                Text(errorMessage(app.errorCode, app.locale)))),
                  FilledButton(
                      onPressed: !app.busy && _consent && _languages.isNotEmpty
                          ? () => app.completeOnboarding(<String, dynamic>{
                                'dateOfBirth': _dob.text.trim(),
                                'displayName': _name.text.trim(),
                                'avatarCode': _avatar,
                                'interfaceLanguage': _interfaceLanguage,
                                'languages': _languages.toList(),
                              })
                          : null,
                      child: Text(
                          app.text('Save and continue', 'சேமித்து தொடரவும்'))),
                ]))));
  }
}
