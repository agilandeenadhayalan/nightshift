import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/api.dart' show ApiFailure;
import '../core/phone_sign_in.dart';
import 'message_copy.dart';
import 'state_widgets.dart';
import 'redesign/design_system.dart';
import 'redesign/avatar_picker.dart';
import 'redesign/entry_components.dart';
import 'redesign/home_components.dart';

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
    final phoneField = TextField(
      controller: _phone,
      key: const Key('phone-number'),
      keyboardType: TextInputType.phone,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.telephoneNumber],
      decoration: InputDecoration(
          labelText: app.text('Indian mobile number', 'இந்திய மொபைல் எண்'),
          prefixText: '+91 ',
          prefixIcon: const Icon(Icons.phone_outlined)),
      onChanged: (value) {
        if (widget.preview) return;
        state.editPhone(value);
        _code.clear();
      },
    );
    return NightshiftAuthLayout(
      title: app.text('Login to get started', 'தொடங்க உள்நுழையவும்'),
      subtitle: app.text(
          'A familiar voice. A better night.', 'பழகிய குரல். இனிய இரவு.'),
      sheetTitle: enteringCode
          ? app.text('Enter your code', 'உங்கள் குறியீட்டை உள்ளிடவும்')
          : app.text('Sign in with your phone', 'தொலைபேசி மூலம் உள்நுழைக'),
      badge: widget.preview
          ? Chip(label: Text(app.text('Preview', 'முன்னோட்டம்')))
          : null,
      backLabel: app.text('Back', 'பின்செல்'),
      onBack: widget.preview
          ? null
          : () {
              state.reset();
              context.go('/login');
            },
      children: [
        if (widget.preview)
          Text(
              app.text('Design preview · no SMS is sent',
                  'வடிவமைப்பு முன்னோட்டம் · SMS அனுப்பப்படாது'),
              style: const TextStyle(color: NsColors.cyan)),
        if (enteringCode) ...[
          const Center(
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: NightshiftIllustration(
                      icon: Icons.sms_outlined, size: 72))),
          const SizedBox(height: 12),
          Text(
              app.text('Use the six-digit code from your SMS.',
                  'SMS இல் வந்த ஆறு இலக்கக் குறியீட்டைப் பயன்படுத்தவும்.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: NsColors.muted)),
          const SizedBox(height: 22),
          NightshiftOtpField(
              controller: _code,
              label: app.text('Six-digit code', 'ஆறு இலக்கக் குறியீடு'),
              enabled: !state.busy && !widget.preview),
          const SizedBox(height: 20),
          if (state.expired && !widget.preview)
            Text(errorMessage(
                state.nativePhone ? 'PHONE_ADMISSION_EXPIRED' : 'OTP_EXPIRED',
                app.locale)),
          if (state.autoRetrievalEnded && !state.expired && !widget.preview)
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
              child: Text(
                  app.text('Verify and continue', 'சரிபார்த்து தொடரவும்'))),
          const SizedBox(height: 24),
          Text(app.text('Your sign-in number', 'உங்கள் உள்நுழைவு எண்'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
        ] else ...[
          Text(
              app.text(
                  'Your phone number is private. Other people see your public nickname only.',
                  'உங்கள் தொலைபேசி எண் தனிப்பட்டது. மற்றவர்களுக்கு உங்கள் பொதுப் பெயர் மட்டுமே தெரியும்.'),
              style: const TextStyle(color: NsColors.muted)),
          const SizedBox(height: 24),
        ],
        phoneField,
        const SizedBox(height: 12),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: !widget.preview && state.consent,
            onChanged: widget.preview
                ? null
                : (value) => state.setConsent(value ?? false),
            title: Text(app.text(
                'I agree to receive an SMS sign-in code. Google receives and stores my phone number for sign-in and spam and abuse prevention across Google services. Standard SMS rates may apply.',
                'SMS உள்நுழைவுக் குறியீட்டைப் பெற ஒப்புக்கொள்கிறேன். உள்நுழைவு மற்றும் Google சேவைகளில் தேவையற்ற செய்திகள், முறைகேடுகளைத் தடுக்க Google என் எண்ணைப் பெற்று சேமிக்கும். வழக்கமான SMS கட்டணங்கள் பொருந்தலாம்.'))),
        const SizedBox(height: 12),
        if (!state.configured && !widget.preview)
          Text(app.text('Phone sign-in is unavailable in this build.',
              'இந்த செயலியில் தொலைபேசி உள்நுழைவு தற்போது கிடைக்கவில்லை.')),
        if (state.retrySeconds > 0 && !widget.preview)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(app.text(
                  'Request another code in ${state.retrySeconds}s.',
                  '${state.retrySeconds} வினாடிகளுக்குப் பிறகு மற்றொரு குறியீட்டைக் கோரலாம்.'))),
        FilledButton(
            onPressed:
                !widget.preview && state.canRequest ? state.requestCode : null,
            child: Text(app.text(
                enteringCode ? 'Send a new code' : 'Send code',
                enteringCode
                    ? 'புதிய குறியீட்டை அனுப்பு'
                    : 'குறியீட்டை அனுப்பு'))),
        if (state.busy && !widget.preview)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
        if (state.errorCode != null && !widget.preview)
          Semantics(
              liveRegion: true,
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: NightshiftMessagePanel(
                      title: app.text(
                          'Sign-in needs attention', 'உள்நுழைவில் கவனம் தேவை'),
                      message: errorMessage(state.errorCode, app.locale),
                      icon: Icons.info_outline_rounded,
                      accent: Theme.of(context).colorScheme.error))),
        if (app.canRestorePhoneSession && !widget.preview)
          TextButton(
              onPressed: app.busy ? null : app.restorePhoneSession,
              child: Text(app.text(
                  'Restore previous sign-in', 'முந்தைய உள்நுழைவை மீட்டமை'))),
        if (app.errorCode != null && !widget.preview)
          NightshiftMessagePanel(
              title:
                  app.text('Sign-in needs attention', 'உள்நுழைவில் கவனம் தேவை'),
              message: errorMessage(app.errorCode, app.locale),
              accent: Theme.of(context).colorScheme.error),
        const SizedBox(height: 24),
        Text(
            app.text('Your phone number is never shown on your public profile.',
                'உங்கள் பொதுச் சுயவிவரத்தில் தொலைபேசி எண் காட்டப்படாது.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: NsColors.muted, fontSize: 12)),
      ],
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController(), _dob = TextEditingController();
  String _avatar = 'moon', _interfaceLanguage = 'en';
  final Set<String> _languages = {'ta'};
  bool _consent = false, _loaded = false;
  Object? _formOwner;
  bool _editReady = false, _editLoading = false;
  String? _editError;
  int _editRequest = 0;

  Future<void> _loadEditProfile() async {
    if (!mounted || _editLoading) return;
    final app = ref.read(appControllerProvider), owner = _formOwner;
    final request = ++_editRequest;
    bool current() =>
        mounted && owner == app.accountIdentity && request == _editRequest;
    setState(() {
      _editLoading = true;
      _editError = null;
      _editReady = false;
    });
    try {
      await app.loadOnboarding();
      if (!current()) return;
      setState(() {
        _editReady = true;
        _loaded = false;
      });
    } on ApiFailure catch (error) {
      if (current()) setState(() => _editError = error.code);
    } catch (_) {
      if (current()) setState(() => _editError = 'UNKNOWN');
    } finally {
      if (current()) setState(() => _editLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    if (_formOwner != app.accountIdentity) {
      _formOwner = app.accountIdentity;
      _loaded = false;
      _consent = false;
      _avatar = 'moon';
      _name.clear();
      _dob.clear();
      _interfaceLanguage = app.locale;
      _languages
        ..clear()
        ..add('ta');
      _editReady = !widget.editing;
      _editLoading = false;
      _editError = null;
      _editRequest++;
      if (widget.editing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadEditProfile());
        });
      }
    }
    if (widget.editing && !_editReady) {
      return Scaffold(
          appBar: AppBar(
              title: Text(app.text('Edit profile', 'சுயவிவரத்தை திருத்து'))),
          body: NightshiftBackdrop(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _editLoading || _editError == null
                              ? LoadingNotice(
                                  label: app.text('Loading your profile…',
                                      'உங்கள் சுயவிவரம் ஏற்றப்படுகிறது…'))
                              : FailureNotice(
                                  title: app.text('Could not load your profile',
                                      'உங்கள் சுயவிவரத்தை ஏற்ற முடியவில்லை'),
                                  message: errorMessage(_editError, app.locale),
                                  retryLabel:
                                      app.text('Retry', 'மீண்டும் முயற்சி'),
                                  onRetry: _loadEditProfile))))));
    }
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
            title: Text(widget.editing
                ? app.text('Edit profile', 'சுயவிவரத்தை திருத்து')
                : app.text('Your profile', 'உங்கள் சுயவிவரம்')),
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
                          NightshiftProfileHero(
                              name: app.user?.name ??
                                  app.text('Your profile', 'உங்கள் சுயவிவரம்'),
                              avatarCode: _avatar,
                              roleLabel: app.isListener
                                  ? app.text('Listener', 'கேட்பவர்')
                                  : app.text('Customer', 'வாடிக்கையாளர்'),
                              subtitle: app.text(
                                  'Your public alias · avatar selection is a draft until saved',
                                  'உங்கள் பொதுப் பெயர் · சேமிக்கும் வரை அவதாரத் தேர்வு வரைவு'),
                              roleIcon: app.isListener
                                  ? Icons.headphones
                                  : Icons.person_outline),
                          const SizedBox(height: 24),
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
                          Text(
                              app.text('Choose an avatar',
                                  'அவதாரத்தை தேர்ந்தெடுக்கவும்'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 14),
                          Wrap(spacing: 14, runSpacing: 14, children: [
                            for (final code in const [
                              'female_01',
                              'male_01',
                              'female_03',
                              'male_04',
                              'female_05',
                              'male_07',
                              'female_08',
                              'male_09'
                            ])
                              Semantics(
                                  button: true,
                                  selected: _avatar == code,
                                  label: app.text('Choose avatar $code',
                                      '$code அவதாரத்தை தேர்ந்தெடு'),
                                  child: InkWell(
                                      key: ValueKey(
                                          'profile-quick-avatar-$code'),
                                      borderRadius: BorderRadius.circular(34),
                                      onTap: app.busy
                                          ? null
                                          : () =>
                                              setState(() => _avatar = code),
                                      child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: _avatar == code
                                                      ? NsColors.cyan
                                                      : Colors.transparent,
                                                  width: 2)),
                                          child: NightshiftAvatar(
                                              name: code,
                                              avatarCode: code,
                                              size: 54)))),
                          ]),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            key: const Key('onboarding-avatar-picker'),
                            onPressed: app.busy
                                ? null
                                : () async {
                                    final owner = app.accountIdentity;
                                    final code = await showAvatarPicker(context,
                                        selected: _avatar,
                                        tamil: app.locale == 'ta');
                                    if (mounted &&
                                        owner == app.accountIdentity &&
                                        code != null) {
                                      setState(() => _avatar = code);
                                    }
                                  },
                            icon: const Icon(Icons.face_retouching_natural),
                            label: Text(app.text('Choose your avatar',
                                'உங்கள் அவதாரத்தை தேர்ந்தெடுக்கவும்')),
                          ),
                          const SizedBox(height: 16),
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
                                  ? () async {
                                      final owner = app.accountIdentity;
                                      await app
                                          .completeOnboarding(<String, dynamic>{
                                        'dateOfBirth': _dob.text.trim(),
                                        'displayName': _name.text.trim(),
                                        'avatarCode': _avatar,
                                        'interfaceLanguage': _interfaceLanguage,
                                        'languages': _languages.toList(),
                                      });
                                      if (widget.editing &&
                                          context.mounted &&
                                          owner == app.accountIdentity &&
                                          app.errorCode == null &&
                                          !app.needsOnboarding) {
                                        context.go('/profile');
                                      }
                                    }
                                  : null,
                              child: Text(app.text(
                                  'Save and continue', 'சேமித்து தொடரவும்'))),
                        ])))));
  }
}
