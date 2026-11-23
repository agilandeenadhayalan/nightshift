import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/controller.dart';
import '../account_screens.dart';
import 'design_system.dart';

/// Only an explicit tap reaches the OS. Previews never invoke this provider.
final entryPermissionRequestProvider =
    Provider<Future<PermissionStatus> Function(Permission)>(
        (ref) => (permission) => permission.request());

class EntryPermissionState {
  const EntryPermissionState({this.busy = false, this.result});
  final bool busy;
  final String? result;
}

class EntryPermissionController extends StateNotifier<EntryPermissionState> {
  EntryPermissionController(this.requestPermission, this.owner)
      : super(const EntryPermissionState());
  final Future<PermissionStatus> Function(Permission) requestPermission;
  final Object Function() owner;
  Future<void> request(List<Permission> permissions) async {
    if (state.busy) return;
    final expectedOwner = owner();
    state = const EntryPermissionState(busy: true);
    try {
      var granted = true;
      var restricted = false;
      for (final permission in permissions) {
        if (!mounted || owner() != expectedOwner) return;
        final result = await requestPermission(permission);
        if (!mounted || owner() != expectedOwner) return;
        granted = granted && result.isGranted;
        restricted =
            restricted || result.isPermanentlyDenied || result.isRestricted;
      }
      state = EntryPermissionState(
          result: granted
              ? 'granted'
              : restricted
                  ? 'restricted'
                  : 'denied');
    } catch (_) {
      if (mounted && owner() == expectedOwner) {
        state = const EntryPermissionState(result: 'unavailable');
      }
    } finally {
      if (mounted && owner() != expectedOwner) {
        state = const EntryPermissionState();
      }
    }
  }
}

final entryPermissionProvider = StateNotifierProvider.autoDispose
    .family<EntryPermissionController, EntryPermissionState, int>((ref, id) =>
        EntryPermissionController(ref.watch(entryPermissionRequestProvider),
            () => ref.read(appControllerProvider).accountIdentity));
final _introPageProvider = StateProvider.autoDispose<int>((ref) => 0);
final _guidelinesProvider = StateProvider.autoDispose<bool>((ref) => false);
final _sampleLanguageProvider =
    StateProvider.autoDispose<String>((ref) => 'ta');

class NightshiftSplashScreen extends ConsumerWidget {
  const NightshiftSplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    return Scaffold(
        body: NightshiftBackdrop(
            child: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                              width: 190,
                              height: 190,
                              child: CustomPaint(
                                  painter: NightshiftMascotPainter())),
                          const SizedBox(height: 28),
                          const NightshiftBrand(size: 38),
                          const SizedBox(height: 16),
                          Text(
                              app.text('A little time to talk.',
                                  'பேசுவதற்கு சிறிது நேரம்.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: NsColors.muted)),
                          const SizedBox(height: 48),
                          SizedBox(
                              width: 160,
                              child: LinearProgressIndicator(
                                  color: NsColors.cyan,
                                  backgroundColor:
                                      NsColors.violet.withAlpha(50),
                                  semanticsLabel: app.text(
                                      'Loading NightShift…',
                                      'NightShift ஏற்றப்படுகிறது…'))),
                        ]))))));
  }
}

/// Native counterparts of the supplied entry designs. No HTML/JavaScript runs.
class EntryDesignScreen extends ConsumerWidget {
  const EntryDesignScreen(
      {super.key, required this.designId, this.preview = true});
  final int designId;
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    if (designId == 1) return const NightshiftSplashScreen();
    if ([5, 7, 8, 9, 13, 42, 47, 53].contains(designId)) {
      return _PermissionDesign(id: designId, preview: preview);
    }
    if (designId == 30 || designId == 27) {
      return PhoneLoginScreen(preview: preview, previewCode: designId == 27);
    }
    if (designId == 3) return _Introduction(preview: preview);
    if (designId == 26) return _Guidelines(preview: preview);
    final pending = designId == 14,
        training = designId == 19,
        voice = designId == 28;
    final title = pending
        ? app.text('Almost done…', 'கிட்டத்தட்ட முடிந்துவிட்டது…')
        : training
            ? app.text('Getting started', 'தொடங்குவோம்')
            : voice
                ? app.text('Your voice, your introduction',
                    'உங்கள் குரல், உங்கள் அறிமுகம்')
                : app.text('Your voice is your superpower.',
                    'உங்கள் குரலே உங்கள் பலம்.');
    return _EntryPage(title: title, children: [
      if (pending) ...[
        const _EntryEmblem(icon: Icons.hourglass_top_rounded),
        Text(app.text('Application received', 'விண்ணப்பம் பெறப்பட்டது'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        Text(
            app.text(
                'A person reviews each private application. A review time or approval is not guaranteed. Check your saved status in the app.',
                'ஒவ்வொரு தனிப்பட்ட விண்ணப்பத்தையும் ஒருவர் ஆய்வு செய்வார். ஆய்வு நேரம் அல்லது அங்கீகாரம் உறுதியில்லை. செயலியில் சேமித்த நிலையை சரிபார்க்கவும்.'),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _EntryButton(
            label:
                app.text('Check application status', 'விண்ணப்ப நிலையை சரிபார்'),
            onPressed:
                preview ? null : () => context.go('/listener-application')),
      ] else if (training) ...[
        NightshiftSurface(
            child: Column(children: [
          const _EntryEmblem(
              icon: Icons.play_circle_outline_rounded, size: 108),
          Text(app.text('Listener orientation', 'கேட்பவர் அறிமுகம்'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
              app.text('Training video is not available yet.',
                  'பயிற்சி வீடியோ இன்னும் கிடைக்கவில்லை.'),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.play_arrow),
              label: Text(app.text('Watch training', 'பயிற்சியை பார்'))),
        ])),
        const SizedBox(height: 28),
        _Benefit(
            icon: Icons.headphones_rounded,
            title: app.text('Listen with care', 'கவனமாக கேளுங்கள்'),
            body: app.text(
                'Let the other person set the pace. You can end a conversation at any time.',
                'மற்றவரின் வேகத்திற்கு ஏற்ப உரையாடுங்கள். எப்போது வேண்டுமானாலும் அழைப்பை முடிக்கலாம்.')),
        _Benefit(
            icon: Icons.shield_outlined,
            title: app.text('Keep boundaries', 'எல்லைகளை காப்போம்'),
            body: app.text(
                'Keep contact details private. Report or block unwanted behaviour.',
                'தொடர்பு விவரங்களை தனிப்பட்டதாக வைத்திருங்கள். விரும்பத்தகாத நடத்தையை புகாரளிக்கலாம் அல்லது தடுக்கலாம்.')),
        _EntryButton(
            label: app.text(
                'Continue to application', 'விண்ணப்பத்திற்கு தொடரவும்'),
            onPressed:
                preview ? null : () => context.go('/listener-application')),
      ] else if (voice) ...[
        _VoiceDesign(preview: preview),
      ] else ...[
        const _EntryEmblem(icon: Icons.headset_mic_rounded, size: 132),
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
          Text(app.text('Customer + Listener', 'வாடிக்கையாளர் + கேட்பவர்'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              app.text('One account. Two ways to connect.',
                  'ஒரு கணக்கு. இணைய இரு வழிகள்.'),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Chip(
              label: Text(
                  app.text('Test earnings only', 'சோதனை வருமானம் மட்டுமே'))),
        ])),
        const SizedBox(height: 20),
        _Benefit(
            icon: Icons.person_outline,
            title: app.text('A private profile', 'தனிப்பட்ட சுயவிவரம்'),
            body: app.text(
                'Other people see your public alias, not your phone number.',
                'மற்றவர்களுக்கு உங்கள் பொதுப் பெயர் தெரியும்; தொலைபேசி எண் தெரியாது.')),
        _Benefit(
            icon: Icons.schedule,
            title: app.text(
                'Choose your availability', 'உங்கள் நேரத்தை தேர்ந்தெடுக்கவும்'),
            body: app.text('Approved Listeners choose when to receive calls.',
                'அங்கீகரிக்கப்பட்ட கேட்பவர்கள் அழைப்புகளை பெறும் நேரத்தை தேர்ந்தெடுக்கலாம்.')),
        _Benefit(
            icon: Icons.shield_outlined,
            title: app.text('Stay in control', 'கட்டுப்பாடு உங்களிடம்'),
            body: app.text('End, report or block from every call.',
                'ஒவ்வொரு அழைப்பிலும் முடிக்கவும், புகாரளிக்கவும் அல்லது தடுக்கவும் முடியும்.')),
        _EntryButton(
            label: app.text(
                'Apply to be a Listener', 'கேட்பவராக விண்ணப்பிக்கவும்'),
            onPressed:
                preview ? null : () => context.go('/listener-application')),
        const SizedBox(height: 12),
        Text(
            app.text(
                'For adults 18+. Human review is required. No earnings or approval are promised.',
                '18 வயதுக்கு மேற்பட்டவர்களுக்கு. மனித ஆய்வு தேவை. வருமானம் அல்லது அங்கீகாரம் உறுதியில்லை.'),
            textAlign: TextAlign.center),
      ],
    ]);
  }
}

class _EntryPage extends StatelessWidget {
  const _EntryPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(leading: const BackButton())
          : null,
      body: NightshiftBackdrop(
          child: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                          children: [
                            const Center(child: NightshiftBrand()),
                            const SizedBox(height: 32),
                            Text(title,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 24),
                            ...children,
                          ]))))));
}

class _EntryEmblem extends StatelessWidget {
  const _EntryEmblem({required this.icon, this.size = 112});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
          child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF412074), Color(0xFF122B43)]),
                  border: Border.all(color: NsColors.cyan.withAlpha(95)),
                  boxShadow: [
                    BoxShadow(
                        color: NsColors.violet.withAlpha(45), blurRadius: 35)
                  ]),
              child: Icon(icon, size: size * .45, color: NsColors.cyan))));
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: NsColors.cyan,
              foregroundColor: NsColors.background),
          child: Text(label, textAlign: TextAlign.center)));
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: NsColors.violet.withAlpha(35),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: NsColors.cyan)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body),
        ])),
      ]));
}

class _Introduction extends ConsumerWidget {
  const _Introduction({required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider),
        index = ref.watch(_introPageProvider);
    final titles = [
      app.text('A little time to talk.', 'பேசுவதற்கு சிறிது நேரம்.'),
      app.text(
          'Your conversation. Your pace.', 'உங்கள் உரையாடல். உங்கள் வேகம்.'),
      app.text('Meet through a conversation.', 'உரையாடலில் சந்திப்போம்.')
    ];
    final details = [
      app.text('Find someone to talk with, in Tamil or English.',
          'தமிழ் அல்லது ஆங்கிலத்தில் பேச ஒருவரை கண்டறியுங்கள்.'),
      app.text('Choose audio or video, with clear consent and controls.',
          'தெளிவான ஒப்புதல் மற்றும் கட்டுப்பாடுகளுடன் ஆடியோ அல்லது வீடியோவை தேர்ந்தெடுக்கவும்.'),
      app.text('Customer and Listener. One account, two ways to connect.',
          'வாடிக்கையாளர் மற்றும் கேட்பவர். ஒரு கணக்கு, இணைய இரு வழிகள்.')
    ];
    return _EntryPage(title: titles[index], children: [
      GestureDetector(
          onHorizontalDragEnd: (event) {
            final delta = (event.primaryVelocity ?? 0) < 0 ? 1 : -1;
            ref.read(_introPageProvider.notifier).state =
                (index + delta).clamp(0, 2);
          },
          child: NightshiftSurface(
              child: Column(children: [
            _EntryEmblem(
                icon: [
                  Icons.headphones_rounded,
                  Icons.shield_outlined,
                  Icons.forum_outlined
                ][index],
                size: 164),
            Text(details[index],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Wrap(alignment: WrapAlignment.center, spacing: 12, children: const [
              NightshiftAvatar(name: 'Customer', size: 64),
              NightshiftAvatar(name: 'Listener', size: 64, listener: true),
            ]),
          ]))),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 3; i++)
          Semantics(
              selected: i == index,
              label: app.text('Slide ${i + 1}', 'பக்கம் ${i + 1}'),
              child: IconButton(
                  onPressed: () =>
                      ref.read(_introPageProvider.notifier).state = i,
                  icon: Icon(
                      i == index ? Icons.horizontal_rule_rounded : Icons.circle,
                      size: i == index ? 32 : 10,
                      color: i == index ? NsColors.cyan : NsColors.muted))),
      ]),
      _EntryButton(
          label: index < 2
              ? app.text('Next', 'அடுத்து')
              : app.text('Log in', 'உள்நுழைக'),
          onPressed: () {
            if (index < 2) {
              ref.read(_introPageProvider.notifier).state++;
            } else if (!preview) {
              context.go('/phone-login');
            }
          }),
    ]);
  }
}

class _Guidelines extends ConsumerWidget {
  const _Guidelines({required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider),
        agreed = ref.watch(_guidelinesProvider);
    return _EntryPage(
        title:
            app.text('Welcome to Nightshift', 'Nightshift உங்களை வரவேற்கிறது'),
        children: [
          const _EntryEmblem(icon: Icons.nights_stay_outlined),
          _Benefit(
              icon: Icons.favorite_border,
              title: app.text('Stay respectful', 'மரியாதையுடன் இருங்கள்'),
              body: app.text(
                  'Treat the other person with kindness. Respect a request to stop.',
                  'மற்றவரிடம் கனிவாக இருங்கள். நிறுத்துமாறு கேட்டால் மதிக்கவும்.')),
          _Benefit(
              icon: Icons.lock_outline,
              title: app.text(
                  'Your safety comes first', 'உங்கள் பாதுகாப்பே முதன்மை'),
              body: app.text(
                  'Share only what you choose. Keep personal contact and payment details private.',
                  'நீங்கள் விரும்புவதை மட்டும் பகிருங்கள். தொடர்பு மற்றும் பண விவரங்களை தனிப்பட்டதாக வைத்திருங்கள்.')),
          _Benefit(
              icon: Icons.flag_outlined,
              title: app.text('Help keep this space safe',
                  'இந்த இடத்தை பாதுகாப்பாக வைத்திருப்போம்'),
              body: app.text(
                  'Use Report or block when a conversation feels unsafe.',
                  'உரையாடல் பாதுகாப்பற்றதாக இருந்தால் புகாரளிக்கவும் அல்லது தடுக்கவும்.')),
          CheckboxListTile(
              value: agreed,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) =>
                  ref.read(_guidelinesProvider.notifier).state = value ?? false,
              title: Text(app.text('I have read these conversation guidelines.',
                  'இந்த உரையாடல் வழிகாட்டுதல்களை படித்தேன்.'))),
          _EntryButton(
              label: app.text('Continue', 'தொடரவும்'),
              onPressed: !agreed || preview
                  ? null
                  : () => context
                      .go(app.needsOnboarding ? '/onboarding' : '/home')),
        ]);
  }
}

class _VoiceDesign extends ConsumerWidget {
  const _VoiceDesign({required this.preview});
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider),
        language = ref.watch(_sampleLanguageProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          app.text(
              'Private voice review sample', 'தனிப்பட்ட குரல் ஆய்வு மாதிரி'),
          textAlign: TextAlign.center),
      const _EntryEmblem(icon: Icons.graphic_eq_rounded),
      SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ta', label: Text('தமிழ்')),
            ButtonSegment(value: 'en', label: Text('English'))
          ],
          selected: {
            language
          },
          onSelectionChanged: (value) =>
              ref.read(_sampleLanguageProvider.notifier).state = value.single),
      const SizedBox(height: 24),
      NightshiftSurface(
          child: Column(children: [
        Text(
            app.text('Introduce yourself in your own words',
                'உங்கள் சொற்களில் உங்களை அறிமுகப்படுத்துங்கள்'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(
            language == 'ta'
                ? '“வணக்கம். உங்களுடன் பேசுவதில் மகிழ்ச்சி.”'
                : '“Hello. It is good to talk with you.”',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const Icon(Icons.multitrack_audio_rounded,
            size: 80, color: NsColors.cyan),
        Text(app.text('2–60 seconds · WAV', '2–60 விநாடிகள் · WAV')),
      ])),
      const SizedBox(height: 24),
      Text(
          app.text(
              'A person reviews your sample. It is not proof of age, gender or identity. Nothing is recorded automatically.',
              'உங்கள் மாதிரியை ஒருவர் ஆய்வு செய்வார். இது வயது, பாலினம் அல்லது அடையாளத்திற்கான சான்று அல்ல. தானாக எதுவும் பதிவு செய்யப்படாது.'),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _EntryButton(
          label: app.text('Open private sample application',
              'தனிப்பட்ட மாதிரி விண்ணப்பத்தை திற'),
          onPressed:
              preview ? null : () => context.go('/listener-application')),
    ]);
  }
}

class _PermissionDesign extends ConsumerWidget {
  const _PermissionDesign({required this.id, required this.preview});
  final int id;
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final state = ref.watch(entryPermissionProvider(id));
    final notification = id == 7 || id == 9;
    final bluetooth = id == 8 || id == 42;
    final audio = id == 13;
    final both = id == 53;
    final listener = [5, 8, 13, 53].contains(id);
    final permissions = notification
        ? [Permission.notification]
        : bluetooth
            ? [Permission.bluetoothConnect]
            : audio
                ? [Permission.microphone]
                : both
                    ? [Permission.camera, Permission.microphone]
                    : [Permission.camera];
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final title = notification
        ? app.text('Stay in the conversation', 'உரையாடலுடன் இணைந்திருங்கள்')
        : bluetooth
            ? app.text('Connect your headphones', 'உங்கள் காதொலியை இணைக்கவும்')
            : audio
                ? app.text(
                    'Let your voice be heard', 'உங்கள் குரல் கேட்கட்டும்')
                : both
                    ? app.text('Your camera. Your microphone.',
                        'உங்கள் கேமரா. உங்கள் ஒலிவாங்கி.')
                    : app.text('Ready for video?', 'வீடியோவிற்கு தயாரா?');
    final icon = notification
        ? Icons.notifications_none_rounded
        : bluetooth
            ? Icons.headphones_rounded
            : audio
                ? Icons.mic_none_rounded
                : Icons.videocam_outlined;
    final explanation = notification
        ? app.text(
            'Allow Android notifications for call invitations. Listener invitation settings remain a separate choice.',
            'அழைப்பு அறிவிப்புகளுக்கு Android அனுமதியை வழங்கவும். கேட்பவர் அழைப்பு அமைப்புகள் தனியான தேர்வு.')
        : bluetooth
            ? app.text(
                'Connect an already paired Bluetooth audio device. This does not scan for people or request location access.',
                'ஏற்கனவே இணைக்கப்பட்ட Bluetooth ஒலி சாதனத்தை பயன்படுத்தவும். இது நபர்களை தேடவோ இட அனுமதியை கோரவோ செய்யாது.')
            : audio
                ? app.text(
                    'Your microphone is used when you join a call. This button does not record a voice sample.',
                    'அழைப்பில் சேரும்போது ஒலிவாங்கி பயன்படுத்தப்படும். இந்த பொத்தான் குரல் மாதிரியை பதிவு செய்யாது.')
                : app.text(
                    'Choose permission in the Android dialog. Video only starts after the separate call preview and consent.',
                    'Android உரையாடலில் அனுமதியை தேர்ந்தெடுக்கவும். தனியான அழைப்பு முன்னோட்டம் மற்றும் ஒப்புதலுக்குப் பிறகே வீடியோ தொடங்கும்.');
    return _EntryPage(title: title, children: [
      if (!notification) ...[
        Opacity(
            opacity: .7,
            child: NightshiftSurface(
                child: Column(children: [
              Row(children: [
                Icon(listener ? Icons.headset_mic : Icons.explore_outlined,
                    color: NsColors.violet),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        listener
                            ? app.text('Listener availability',
                                'கேட்பவர் கிடைக்கும் நிலை')
                            : app.text(
                                'Your conversations', 'உங்கள் உரையாடல்கள்'),
                        style: Theme.of(context).textTheme.titleMedium))
              ]),
              const SizedBox(height: 16),
              const NightshiftAvatar(name: 'Nightshift', size: 64),
              const SizedBox(height: 12),
              Text(
                  app.text('You control when to connect',
                      'எப்போது இணைவது உங்கள் கட்டுப்பாட்டில்'),
                  textAlign: TextAlign.center),
            ]))),
        const SizedBox(height: 24),
      ],
      NightshiftSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _EntryEmblem(icon: icon, size: 80),
        Text(
            notification
                ? app.text('Allow Nightshift notifications?',
                    'Nightshift அறிவிப்புகளை அனுமதிக்கவா?')
                : bluetooth
                    ? app.text('Allow nearby audio devices?',
                        'அருகிலுள்ள ஒலி சாதனங்களை அனுமதிக்கவா?')
                    : audio
                        ? app.text('Allow microphone access?',
                            'ஒலிவாங்கி அணுகலை அனுமதிக்கவா?')
                        : both
                            ? app.text('Allow camera and microphone access?',
                                'கேமரா மற்றும் ஒலிவாங்கி அணுகலை அனுமதிக்கவா?')
                            : app.text('Allow camera access?',
                                'கேமரா அணுகலை அனுமதிக்கவா?'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(explanation, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
            key: ValueKey('entry-permission-$id'),
            onPressed: preview || !supported || state.busy
                ? null
                : () => ref
                    .read(entryPermissionProvider(id).notifier)
                    .request(permissions),
            child: Text(
                state.busy
                    ? app.text('Waiting for Android…',
                        'Android பதிலுக்காக காத்திருக்கிறது…')
                    : app.text('Continue to Android permission',
                        'Android அனுமதிக்கு தொடரவும்'),
                textAlign: TextAlign.center)),
        if (preview)
          Text(
              app.text('Design preview · no permission requested',
                  'வடிவமைப்பு முன்னோட்டம் · அனுமதி கோரப்படவில்லை'),
              textAlign: TextAlign.center)
        else if (!supported)
          Text(
              app.text('This permission flow is available on Android.',
                  'இந்த அனுமதி Android இல் கிடைக்கும்.'),
              textAlign: TextAlign.center),
        if (state.result != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  switch (state.result) {
                    'granted' => app.text(
                        'Android permission granted. No call has started.',
                        'Android அனுமதி வழங்கப்பட்டது. எந்த அழைப்பும் தொடங்கவில்லை.'),
                    'restricted' => app.text(
                        'Permission is restricted. You can review it in Android settings.',
                        'அனுமதி கட்டுப்படுத்தப்பட்டுள்ளது. Android அமைப்பில் சரிபார்க்கலாம்.'),
                    'denied' => app.text('Permission was not granted.',
                        'அனுமதி வழங்கப்படவில்லை.'),
                    _ => app.text(
                        'Permission could not be requested on this device.',
                        'இந்த சாதனத்தில் அனுமதியை கோர முடியவில்லை.'),
                  },
                  key: ValueKey('entry-permission-result-$id'),
                  textAlign: TextAlign.center)),
      ])),
    ]);
  }
}
