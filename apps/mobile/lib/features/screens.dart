import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'message_copy.dart';
import 'state_widgets.dart';
import 'video_preflight.dart';
import 'video_view.dart';
import 'discovery_view.dart';
import '../core/discovery.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: children),
      ));
}

class StatusCard extends StatelessWidget {
  const StatusCard(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.info_outline,
      this.action});
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message),
              if (action != null) ...[const SizedBox(height: 16), action!]
            ],
          )));
}

class ErrorNotice extends ConsumerWidget {
  const ErrorNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (state.error == null) return const SizedBox.shrink();
    return FailureNotice(
      offline: state.offline,
      title: state.offline
          ? state.text('Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
          : state.text('Please try again', 'மீண்டும் முயற்சிக்கவும்'),
      message: state.user == null
          ? '${errorMessage(state.errorCode, state.locale)} ${state.text('When ready, press Continue to NightShift.', 'தயாரானதும் NightShift தொடரவும் பொத்தானை அழுத்தவும்.')}'
          : errorMessage(state.errorCode, state.locale),
      reference: state.diagnosticId == null
          ? null
          : state.text('Reference: ${state.diagnosticId}',
              'குறிப்பு: ${state.diagnosticId}'),
      retryLabel: state.text('Refresh status', 'நிலையை புதுப்பி'),
      // Refresh never replays a side effect. Sign-in has its own submit button.
      onRetry: state.user == null || state.busy
          ? null
          : () {
              state.clearError();
              unawaited(state.refresh());
            },
      dismissLabel: state.text('Dismiss', 'மூடு'),
      onDismiss: state.clearError,
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _address = TextEditingController(), _key = TextEditingController();
  String _account = 'customer';
  bool _adult = false;
  @override
  void initState() {
    super.initState();
    _address.text = ref.read(appControllerProvider).api.baseUrl;
  }

  @override
  void dispose() {
    _address.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('NightShift'), actions: [
          TextButton(
              onPressed: () =>
                  state.setLocale(state.locale == 'en' ? 'ta' : 'en'),
              child: Text(state.locale == 'en' ? 'தமிழ்' : 'English')),
        ]),
        body: PageBody(children: [
          const SizedBox(height: 24),
          const Icon(Icons.nights_stay_outlined, size: 52),
          const SizedBox(height: 24),
          Text(state.text('A little time to talk.', 'பேசுவதற்கு சிறிது நேரம்.'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(state.text(
              'One app. Customer and Listener. Private, one-to-one adult conversation.',
              'ஒரே செயலி. வாடிக்கையாளர் மற்றும் கேட்பவர். பெரியவர்களுக்கான தனிப்பட்ட உரையாடல்.')),
          const SizedBox(height: 24),
          StatusCard(
              title: state.text(
                  'Development test build', 'மேம்பாட்டு சோதனை செயலி'),
              message: state.text(
                  'Fictional accounts and test credits only. No purchases or cash payouts. Keep both phones open during a call.',
                  'சோதனை கணக்குகள் மற்றும் சோதனை நாணயங்கள் மட்டுமே. வாங்குதல் அல்லது பணம் பெறுதல் இல்லை. அழைப்பின்போது இரு செயலிகளையும் திறந்து வைத்திருங்கள்.')),
          OutlinedButton.icon(
              onPressed: () => context.go('/phone-login'),
              icon: const Icon(Icons.phone_outlined),
              label: Text(state.text(
                  'Sign in with your phone', 'தொலைபேசி மூலம் உள்நுழைக'))),
          if (state.privacy.hasSavedReceipt)
            TextButton(
                onPressed: () => context.go('/deletion-status'),
                child: Text(state.text('View saved deletion receipt',
                    'சேமிக்கப்பட்ட நீக்க ரசீதைப் பார்'))),
          const ErrorNotice(),
          const SizedBox(height: 16),
          TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                  labelText: state.text('Backend address', 'சேவையக முகவரி'),
                  helperText: 'http://192.168.x.x:3000')),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _account,
            isExpanded: true,
            decoration: InputDecoration(
                labelText:
                    state.text('Fictional test account', 'சோதனை கணக்கு')),
            items: [
              DropdownMenuItem(
                  value: 'customer',
                  child: Text(state.text(
                      'Customer · test A', 'வாடிக்கையாளர் · சோதனை A'))),
              DropdownMenuItem(
                  value: 'listener',
                  child: Text(state.text(
                      'Listener · approved test B', 'கேட்பவர் · சோதனை B'))),
              DropdownMenuItem(
                  value: 'customer2',
                  child: Text(state.text(
                      'Customer · test C', 'வாடிக்கையாளர் · சோதனை C')))
            ],
            onChanged: state.busy
                ? null
                : (value) => setState(() => _account = value!),
          ),
          const SizedBox(height: 20),
          TextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                  labelText: state.text(
                      'Development access key', 'மேம்பாட்டு அணுகல் விசை'),
                  helperText: state.text(
                      'From your local backend configuration',
                      'உங்கள் உள்ளூர் சேவையக அமைப்பிலிருந்து'))),
          const SizedBox(height: 12),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _adult,
              onChanged: (value) => setState(() => _adult = value!),
              title: Text(state.text(
                  'I am 18 or older and consent to this test conversation.',
                  'எனக்கு 18 வயது அல்லது அதற்கு மேல். இந்த சோதனை உரையாடலுக்கு ஒப்புக்கொள்கிறேன்.'))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: !_adult || state.busy
                  ? null
                  : () async {
                      await state.login(_address.text, _account, _key.text);
                      if (state.user != null) _key.clear();
                    },
              child: state.busy
                  ? Text(state.text('Signing in…', 'உள்நுழைகிறது…'))
                  : Text(state.text(
                      'Continue to NightShift', 'NightShift தொடரவும்'))),
          const SizedBox(height: 20),
          Text(state.text(
              'The adult checkbox is a development consent gate; production age assurance and phone sign-in are pending.',
              'இது சோதனை ஒப்புதல் மட்டுமே. வயது சரிபார்ப்பும் தொலைபேசி உள்நுழைவும் இன்னும் முடிக்கப்படவில்லை.')),
        ]));
  }
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final index = switch (path) { '/history' => 1, '/profile' => 2, _ => 0 };
    return Scaffold(
        appBar: AppBar(title: const Text('NightShift')),
        body: Column(children: [
          Material(
              color: const Color(0xFFE5EBDD),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            state.isListener
                                ? state.text('Listener', 'கேட்பவர்')
                                : state.text('Customer', 'வாடிக்கையாளர்'),
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.science_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  state.text(
                                      'TEST CREDITS · Keep the app open for calls',
                                      'சோதனை நாணயங்கள் · அழைப்புக்கு செயலியை திறந்து வைத்திருங்கள்'),
                                  style:
                                      Theme.of(context).textTheme.labelMedium))
                        ]),
                      ]))),
          if (state.busy)
            LinearProgressIndicator(
                minHeight: 2,
                semanticsLabel: state.text('Updating…', 'புதுப்பிக்கிறது…')),
          Expanded(child: child),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (next) {
            final location = ['/home', '/history', '/profile'][next];
            unawaited(state.navigate(location));
            context.go(location);
          },
          destinations: [
            NavigationDestination(
                icon: Icon(state.isListener
                    ? Icons.headset_mic_outlined
                    : Icons.explore_outlined),
                label: state.isListener
                    ? state.text('Availability', 'கிடைப்பது')
                    : state.text('Discover', 'கண்டறி')),
            NavigationDestination(
                icon: Icon(state.isListener
                    ? Icons.receipt_long_outlined
                    : Icons.history),
                label: state.isListener
                    ? state.text('Earnings', 'வருமானம்')
                    : state.text('Recents', 'சமீபத்தில்')),
            NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: state.text('Profile', 'சுயவிவரம்')),
          ],
        ));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (!state.isListener && state.snapshotLoaded) {
      return DirectoryScreen(state: state);
    }
    return RefreshIndicator(
        onRefresh: state.refresh,
        child: PageBody(children: [
          const ErrorNotice(),
          Text(
              state.isListener
                  ? state.text('Make room for a conversation.',
                      'உரையாடலுக்கு நேரம் ஒதுக்குங்கள்.')
                  : state.text('Who would you like to talk to?',
                      'யாருடன் பேச விரும்புகிறீர்கள்?'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          if (!state.snapshotLoaded) ...[
            if (state.snapshotLoading)
              LoadingNotice(
                  label: state.text('Loading availability…',
                      'கிடைக்கும் நிலை ஏற்றப்படுகிறது…'))
            else if (state.error == null)
              StatusCard(
                  title: state.text('Connect to see availability',
                      'கிடைக்கும் நிலையை பார்க்க இணைக்கவும்'),
                  message: state.text('Refresh to retrieve the latest status.',
                      'சமீபத்திய நிலையை பெற புதுப்பிக்கவும்.'),
                  action: OutlinedButton.icon(
                      onPressed: state.refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(state.text('Refresh', 'புதுப்பி')))),
          ] else if (state.isListener) ...[
            StatusCard(
                icon: state.user?.online == true
                    ? Icons.radio_button_checked
                    : Icons.pause_circle_outline,
                title: state.offline
                    ? state.text(
                        'Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
                    : state.user?.online == true
                        ? state.text(
                            'You are online', 'நீங்கள் ஆன்லைனில் உள்ளீர்கள்')
                        : state.text(
                            'You are offline', 'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள்'),
                message: state.text(
                    'Only foreground reachability makes you available. Calls pause earnings during reconnects.',
                    'செயலி திறந்திருக்கும் போது மட்டுமே அழைப்புகள் வரும். மீண்டும் இணையும் நேரத்தில் வருமானம் கணக்கிடப்படாது.'),
                action: FilledButton.icon(
                    onPressed: state.busy || state.offline
                        ? null
                        : () => state.setOnline(!(state.user?.online ?? false)),
                    icon: Icon(state.user?.online == true
                        ? Icons.pause
                        : Icons.headset_mic),
                    label:
                        Text(state.user?.online == true ? state.text('Go offline', 'ஆஃப்லைன் செல்லவும்') : state.text('Go online', 'ஆன்லைன் செல்லவும்')))),
            StatusCard(
                title: state.text('Proposed listener rate',
                    'முன்மொழியப்பட்ட கேட்பவர் விகிதம்'),
                message: state.text(
                    '₹500 per 3,600 paid connected seconds. Six paid minutes = ₹50. These are test estimates, not cash earnings. Ringing, waiting and reconnect gaps earn nothing.',
                    '3,600 கட்டண இணைப்பு விநாடிகளுக்கு ₹500. ஆறு கட்டண நிமிடங்கள் = ₹50. இது சோதனை மதிப்பீடு; உண்மையான பணம் அல்ல. காத்திருப்பு மற்றும் இணைப்பு இடைவெளிக்கு வருமானம் இல்லை.')),
            Text(state.text('Tamil · English • Manually approved test listener',
                'தமிழ் · English • சோதனைக்காக அங்கீகரிக்கப்பட்ட கேட்பவர்')),
          ],
        ]));
  }
}

Future<void> showAudioCallConfirmation(
    BuildContext context, AppController state, ListenerProfile listener) async {
  final owner = state.accountIdentity;
  final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final available = owner == state.accountIdentity &&
                state.canCallListener(listener) &&
                !state.busy;
            return AlertDialog(
                title: Text(state.text(
                    'Call ${listener.name}', '${listener.name} அழைக்கவும்')),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${testRateLabel(state, listener.rate)}\n\n${testTariffDescription(state, listener.rate)}\n\n${state.text('Both phones must keep the app open.', 'இரு செயலிகளும் திறந்திருப்பது அவசியம்.')}'),
                      if (!available)
                        Text(state.text(
                            'Listener is no longer available. Refresh before calling.',
                            'கேட்பவர் தற்போது கிடைக்கவில்லை. அழைப்பதற்கு முன் புதுப்பிக்கவும்.')),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(state.text('Cancel', 'ரத்து'))),
                  FilledButton(
                      onPressed:
                          available ? () => Navigator.pop(context, true) : null,
                      child: Text(state.text(
                          'Start audio call', 'ஆடியோ அழைப்பைத் தொடங்கு'))),
                ]);
          }));
  if (agreed == true &&
      context.mounted &&
      owner == state.accountIdentity &&
      state.canCallListener(listener)) {
    await state.startCall(listener);
  }
}

class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider),
        call = ref.watch(appControllerProvider).activeCall;
    if (call == null) {
      return Scaffold(
          body: Center(
              child: LoadingNotice(
                  label:
                      state.text('Loading call…', 'அழைப்பு ஏற்றப்படுகிறது…'))));
    }
    final incoming = call.listenerId == state.user?.id;
    final listenerHourlyRate = (call.rate.listenerPaisePerHour / 100)
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.00$'), '');
    final title = state.endingLocally
        ? call.isVideo
            ? state.text('Camera and audio stopped · waiting for server',
                'கேமராவும் ஆடியோவும் நிறுத்தப்பட்டன · சேவையகத்திற்காக காத்திருக்கிறது')
            : state.text('Audio stopped · waiting for server',
                'ஆடியோ நிறுத்தப்பட்டது · சேவையகத்திற்காக காத்திருக்கிறது')
        : switch (call.state) {
            'ringing' => incoming
                ? call.isVideo
                    ? state.text('Incoming video call', 'வரும் வீடியோ அழைப்பு')
                    : state.text('Incoming audio call', 'வரும் ஆடியோ அழைப்பு')
                : state.text('Calling…', 'அழைக்கிறது…'),
            'connected' => state.text('Connected', 'இணைக்கப்பட்டது'),
            'reconnecting' => state.text('Reconnecting · not charging',
                'மீண்டும் இணைகிறது · கட்டணம் இல்லை'),
            _ => call.isVideo
                ? state.text('Connecting video · not charging',
                    'வீடியோ இணைகிறது · கட்டணம் இல்லை')
                : state.text('Connecting audio · not charging',
                    'ஆடியோ இணைகிறது · கட்டணம் இல்லை'),
          };
    return PopScope(
        canPop: false,
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(call.isVideo
                    ? state.text('Video call', 'வீடியோ அழைப்பு')
                    : state.text('Audio call', 'ஆடியோ அழைப்பு'))),
            bottomNavigationBar: call.isVideo && !call.ringing
                ? SafeArea(
                    minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                          width: double.infinity,
                          child: _endCallButton(context, state)),
                      TextButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => showSafetyDialog(context, state, call),
                          icon: const Icon(Icons.shield_outlined),
                          label: Text(state.text(
                              'Report or block', 'புகாரளி அல்லது தடு'))),
                    ]))
                : null,
            body: PageBody(children: [
              const ErrorNotice(),
              if (call.isVideo &&
                  !call.ringing &&
                  !state.needsVideoConsent &&
                  state.video != null)
                VideoCallView(
                    video: state.video!,
                    remoteLabel: call.otherName(state.user!.id),
                    localLabel: state.text('You', 'நீங்கள்'),
                    waitingLabel: state.text(
                        'Waiting for video', 'வீடியோவிற்காக காத்திருக்கிறது'),
                    cameraOffLabel:
                        state.text('Camera off', 'கேமரா நிறுத்தப்பட்டுள்ளது'))
              else ...[
                const SizedBox(height: 24),
                const CircleAvatar(
                    radius: 48, child: Icon(Icons.person_outline, size: 48)),
              ],
              const SizedBox(height: 24),
              Text(
                  !state.isListener && state.discovery.removed(call.listenerId)
                      ? state.text('Unavailable listener', 'கிடைக்காத கேட்பவர்')
                      : call.otherName(state.user!.id),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Semantics(
                  liveRegion: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 24),
              if (call.isVideo) ...[
                Text(
                    state.text('Video · ${testRateLabel(state, call.rate)}',
                        'வீடியோ · ${testRateLabel(state, call.rate)}'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              if (call.ringing) ...[
                Text(
                    state.text(
                        'Ringing and waiting are free. The invitation expires automatically.',
                        'காத்திருப்பு இலவசம். அழைப்பு தானாக காலாவதியாகும்.'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (incoming) ...[
                  Text(state.text(
                      'Proposed rate: ₹$listenerHourlyRate / paid connected hour. Test estimate only.',
                      'முன்மொழியப்பட்ட விகிதம்: கட்டண இணைப்பு மணிநேரத்திற்கு ₹$listenerHourlyRate. சோதனை மதிப்பீடு மட்டுமே.')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: state.busy
                          ? null
                          : call.isVideo
                              ? () => _reviewVideoCall(context, state, call,
                                  accepting: true)
                              : () => state.transition('accept'),
                      icon: Icon(
                          call.isVideo ? Icons.videocam_outlined : Icons.call),
                      label: Text(call.isVideo
                          ? state.text('Review video invitation',
                              'வீடியோ அழைப்பை சரிபார்')
                          : state.text('Accept', 'ஏற்கவும்'))),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                    onPressed: state.endingLocally
                        ? null
                        : () =>
                            state.transition(incoming ? 'decline' : 'cancel'),
                    child: Text(incoming
                        ? state.text('Decline', 'நிராகரி')
                        : state.text('Cancel call', 'அழைப்பை ரத்து செய்'))),
              ] else ...[
                if (call.isVideo && state.needsVideoConsent)
                  StatusCard(
                      icon: Icons.videocam_off_outlined,
                      title: state.text('Your camera is off',
                          'உங்கள் கேமரா நிறுத்தப்பட்டுள்ளது'),
                      message: state.text(
                          'Review your camera and consent before joining this restored video call.',
                          'மீட்டெடுக்கப்பட்ட வீடியோ அழைப்பில் சேருவதற்கு முன் கேமராவை சரிபார்த்து ஒப்புதல் அளிக்கவும்.'),
                      action: FilledButton.icon(
                          onPressed: state.busy || state.endingLocally
                              ? null
                              : () => _reviewVideoCall(context, state, call),
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(
                              state.text('Review camera', 'கேமராவை சரிபார்')))),
                if (call.isVideo && state.video?.lowBandwidth == true)
                  StatusCard(
                      icon: Icons.network_check,
                      title: state.text('Reduced video quality',
                          'வீடியோ தரம் குறைக்கப்பட்டுள்ளது'),
                      message: state.text(
                          'Video quality is reduced for this connection. The video rate stays ${call.rate.coinsPerMinute} test coins / minute. You can end video and choose a new audio call.',
                          'இந்த இணைப்பிற்கு வீடியோ தரம் குறைக்கப்பட்டுள்ளது. வீடியோ விகிதம் நிமிடத்திற்கு ${call.rate.coinsPerMinute} சோதனை நாணயங்களாகவே இருக்கும். வீடியோவை முடித்து புதிய ஆடியோ அழைப்பை தேர்வு செய்யலாம்.')),
                Text(durationLabel(call.connectedMs),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall),
                Text(
                    state.text('Server-confirmed connected time',
                        'சேவையகம் உறுதிப்படுத்திய இணைப்பு நேரம்'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                    incoming
                        ? state.text(
                            'Test earnings: ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
                            'சோதனை வருமானம்: ₹${(call.earningPaise / 100).toStringAsFixed(2)}')
                        : state.text(
                            'Test coins charged: ${creditAmount(call.chargeMicrocredits)}',
                            'சோதனை நாணயக் கட்டணம்: ${creditAmount(call.chargeMicrocredits)}'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                          onPressed: state.endingLocally ||
                                  state.busy ||
                                  state.needsVideoConsent
                              ? null
                              : () => state.perform(state.audio.toggleMute),
                          icon: Icon(
                              state.audio.muted ? Icons.mic_off : Icons.mic),
                          label: Text(state.audio.muted
                              ? state.text('Unmute', 'ஒலியை இயக்கு')
                              : state.text('Mute', 'ஒலியை நிறுத்து'))),
                      OutlinedButton.icon(
                          onPressed: state.endingLocally ||
                                  state.busy ||
                                  state.needsVideoConsent
                              ? null
                              : () => state.perform(state.audio.toggleSpeaker),
                          icon: Icon(state.audio.speaker
                              ? Icons.volume_up
                              : Icons.hearing),
                          label: Text(state.audio.speaker
                              ? state.text(
                                  'Speaker on', 'ஒலிபெருக்கி இயங்குகிறது')
                              : state.text('Earpiece', 'காதொலி'))),
                    ]),
                if (call.isVideo &&
                    !state.needsVideoConsent &&
                    state.video != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                            onPressed: state.busy || state.endingLocally
                                ? null
                                : () => state.setCameraEnabled(
                                    !state.video!.cameraEnabled),
                            icon: Icon(state.video!.cameraEnabled
                                ? Icons.videocam_off_outlined
                                : Icons.videocam_outlined),
                            label: Text(state.video!.cameraEnabled
                                ? state.text(
                                    'Turn camera off', 'கேமராவை நிறுத்து')
                                : state.text(
                                    'Turn camera on', 'கேமராவை இயக்கு'))),
                        OutlinedButton.icon(
                            onPressed: state.busy ||
                                    state.endingLocally ||
                                    !state.video!.cameraEnabled
                                ? null
                                : state.switchCamera,
                            icon: const Icon(Icons.cameraswitch_outlined),
                            label: Text(
                                state.text('Switch camera', 'கேமராவை மாற்று'))),
                      ]),
                  if (!state.video!.cameraEnabled)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                            state.text(
                                'Camera off. Healthy video time and test charging are paused.',
                                'கேமரா நிறுத்தப்பட்டுள்ளது. வீடியோ இணைப்பு நேரமும் சோதனை கட்டணமும் நிறுத்தப்பட்டுள்ளன.'),
                            textAlign: TextAlign.center)),
                ],
                if (call.isVideo) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: state.busy || state.endingLocally
                          ? null
                          : () => _confirmAudioFallback(context, state, call),
                      icon: const Icon(Icons.call_outlined),
                      label: Text(state.text('End video and use audio',
                          'வீடியோவை முடித்து ஆடியோவை பயன்படுத்து'))),
                ],
                const SizedBox(height: 24),
                if (!call.isVideo) _endCallButton(context, state),
                const SizedBox(height: 16),
                Text(
                    call.isVideo
                        ? state.text(
                            'Leaving or locking the app ends this test call. No audio or video is recorded.',
                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோவும் வீடியோவும் பதிவு செய்யப்படாது.')
                        : state.text(
                            'Leaving or locking the app ends this test call. No audio is recorded.',
                            'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோ பதிவு செய்யப்படுவதில்லை.'),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              if (!call.isVideo || call.ringing)
                TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => showSafetyDialog(context, state, call),
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                        state.text('Report or block', 'புகாரளி அல்லது தடு'))),
              const SizedBox(height: 24),
              SelectableText(
                  state.text('Call ID: ${call.id}', 'அழைப்பு எண்: ${call.id}'),
                  style: Theme.of(context).textTheme.bodySmall),
            ])));
  }
}

Widget _endCallButton(BuildContext context, AppController state) =>
    FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error),
        onPressed: state.endingLocally ? null : () => state.transition('end'),
        icon: const Icon(Icons.call_end),
        label: Text(state.text('End call', 'அழைப்பை முடி')));

Future<void> _reviewVideoCall(
    BuildContext context, AppController state, CallSession call,
    {bool accepting = false}) async {
  final consent = await showVideoPreflight(context, state,
      rate: call.rate,
      confirmLabel: accepting
          ? state.text('Accept video call', 'வீடியோ அழைப்பை ஏற்கவும்')
          : state.text('Join video call', 'வீடியோ அழைப்பில் சேர்'));
  if (!consent || !context.mounted || state.activeCall?.id != call.id) return;
  if (accepting) {
    await state.transition('accept', cameraConsent: true);
  } else {
    await state.joinConsentedVideo();
  }
}

Future<void> _confirmAudioFallback(
    BuildContext context, AppController state, CallSession call) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              scrollable: true,
              title: Text(state.text(
                  'End video first?', 'முதலில் வீடியோவை முடிக்கவா?')),
              content: Text(state.text(
                  'This ends and settles the video call at its existing video rate. An audio call is a new invitation with a separate audio-rate confirmation. Nothing is repriced or redialled automatically.',
                  'தற்போதைய வீடியோ விகிதத்தில் இந்த அழைப்பு முடிக்கப்பட்டு கணக்கிடப்படும். ஆடியோ அழைப்பு தனி விகித ஒப்புதலுடன் புதிய அழைப்பாகும். விகிதம் தானாக மாறாது; தானாக மீண்டும் அழைக்கப்படாது.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(state.text('Keep video', 'வீடியோ தொடரட்டும்'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(state.text('End video', 'வீடியோவை முடி'))),
              ]));
  if (agreed != true || state.activeCall?.id != call.id) return;
  final wasCustomer = call.customerId == state.user?.id;
  await state.endVideoForAudio();
  if (state.hasCall || state.error != null || !navigator.mounted) return;
  if (wasCustomer) {
    await state.refresh();
    if (!navigator.mounted || state.user == null || state.hasCall) return;
    final peers = state.listeners
        .where(
            (listener) => listener.id == call.listenerId && listener.available)
        .toList();
    if (peers.isNotEmpty && !state.offline && state.error == null) {
      // Let the call-to-history redirect install its page before adding a
      // dialog; otherwise the router can remove the new quote with CallScreen.
      await WidgetsBinding.instance.endOfFrame;
      if (!navigator.mounted || state.hasCall || state.user == null) return;
      await showAudioCallConfirmation(navigator.context, state, peers.first);
      return;
    }
  }
  if (messenger.mounted) {
    messenger.showSnackBar(SnackBar(
        content: Text(wasCustomer
            ? state.text(
                'Video ended. Find the Listener in Discover to start a new audio call.',
                'வீடியோ முடிந்தது. புதிய ஆடியோ அழைப்பிற்கு கண்டறியில் கேட்பவரை தேர்வு செய்யவும்.')
            : state.text(
                'Video ended. Ask the Customer to start a new audio call.',
                'வீடியோ முடிந்தது. புதிய ஆடியோ அழைப்பை தொடங்க வாடிக்கையாளரிடம் கூறவும்.'))));
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _favorites = false, _measurePending = false;
  late final Discovery _discovery;
  final Map<String, GlobalKey> _recentKeys = {};
  void _watchVisible() {
    if (_measurePending) return;
    _measurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurePending = false;
      if (!mounted || _favorites) return;
      final state = ref.read(appControllerProvider);
      if (state.isListener) return;
      final viewport = context.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = viewport.localToGlobal(Offset.zero).dy,
          bottom = top + viewport.size.height;
      final ids = <String>[];
      for (final call in state.history) {
        final box = _recentKeys[call.id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || !box.attached) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        if (y < bottom && y + box.size.height > top) ids.add(call.listenerId);
      }
      state.discovery.watchRecents(ids);
    });
  }

  @override
  void dispose() {
    _discovery.watchRecents([]);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _discovery = ref.read(appControllerProvider).discovery;
    Future.microtask(() {
      if (!mounted) return;
      final state = ref.read(appControllerProvider);
      if (!state.historyLoaded && state.historyError == null) {
        unawaited(state.loadHistory());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    _watchVisible();
    if (state.isListener) return _history(context, state);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: false,
                    label: Text(
                        state.text('Recent calls', 'சமீபத்திய அழைப்புகள்'))),
                ButtonSegment(
                    value: true,
                    label: Text(state.text('Favorites', 'விருப்பமானவர்கள்')))
              ],
              selected: {
                _favorites
              },
              onSelectionChanged: (value) {
                state.discovery.watchRecents([]);
                setState(() => _favorites = value.single);
              })),
      Expanded(
          child: _favorites
              ? DirectoryScreen(state: state, kind: DirectoryKind.favorites)
              : NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _watchVisible();
                    return false;
                  },
                  child: _history(context, state))),
    ]);
  }

  Widget _history(BuildContext context, AppController state) {
    final earned = state.history
        .where((c) => c.listenerId == state.user?.id)
        .fold<int>(0, (sum, call) => sum + call.earningPaise);
    return RefreshIndicator(
        onRefresh: () async {
          await state.loadHistory();
          await state.discovery.refreshRecents();
        },
        child: PageBody(children: [
          const ErrorNotice(),
          Text(
              state.isListener
                  ? state.text(
                      'Earnings & calls', 'வருமானம் மற்றும் அழைப்புகள்')
                  : state.text('Your conversations', 'உங்கள் உரையாடல்கள்'),
              style: Theme.of(context).textTheme.headlineSmall),
          if (state.isListener && state.historyLoaded)
            StatusCard(
                title: '₹${(earned / 100).toStringAsFixed(2)}',
                message: state.text(
                    'Test earnings in the displayed history. No cash payouts. Rate and settlement are controlled by the backend.',
                    'காட்டப்பட்ட வரலாற்றின் சோதனை வருமானம். உண்மையான பணம் வழங்கப்படாது. விகிதமும் தீர்வும் சேவையகத்தால் கணக்கிடப்படும்.')),
          const SizedBox(height: 16),
          if (state.historyError != null)
            FailureNotice(
              offline: state.historyError!.code == 'OFFLINE',
              title: state.historyError!.code == 'OFFLINE'
                  ? state.text(
                      'Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
                  : state.text(
                      'Could not load calls', 'அழைப்புகளை ஏற்ற முடியவில்லை'),
              message: errorMessage(state.historyError!.code, state.locale),
              reference: state.historyError!.requestId == null
                  ? null
                  : state.text('Reference: ${state.historyError!.requestId}',
                      'குறிப்பு: ${state.historyError!.requestId}'),
              retryLabel: state.text('Retry', 'மீண்டும் முயற்சி'),
              onRetry: state.historyLoading ? null : state.retryHistory,
            ),
          if (state.history.isEmpty &&
              state.historyLoaded &&
              !state.historyLoading &&
              state.historyError == null)
            StatusCard(
                title: state.text('No completed calls yet',
                    'முடிந்த அழைப்புகள் இன்னும் இல்லை'),
                message: state.text(
                    'Your completed, cancelled and declined calls will appear here.',
                    'முடிந்த, ரத்தான, நிராகரிக்கப்பட்ட அழைப்புகள் இங்கே தெரியும்.')),
          for (final (index, call) in state.history.indexed) ...[
            if (index == 0 ||
                historyDay(call.createdAt, DateTime.now()) !=
                    historyDay(
                        state.history[index - 1].createdAt, DateTime.now()))
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      switch (historyDay(call.createdAt, DateTime.now())) {
                        'today' => state.text('Today', 'இன்று'),
                        'yesterday' => state.text('Yesterday', 'நேற்று'),
                        _ => state.text('Earlier', 'முன்பு'),
                      },
                      style: Theme.of(context).textTheme.titleMedium)),
            Card(
                key: _recentKeys.putIfAbsent(call.id, GlobalKey.new),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(call.otherName(state.user!.id),
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(call.isVideo
                              ? state.text('Video call', 'வீடியோ அழைப்பு')
                              : state.text('Audio call', 'ஆடியோ அழைப்பு')),
                          const SizedBox(height: 8),
                          Text(
                              '${_localDate(call.createdAt)} · ${durationLabel(call.connectedMs)}'),
                          Text(state.text(
                              'End reason: ${endReasonLabel(call.reason, state.locale)}',
                              'முடிவு காரணம்: ${endReasonLabel(call.reason, state.locale)}')),
                          Text(state.text(
                              '${creditAmount(call.chargeMicrocredits)} test coins',
                              '${creditAmount(call.chargeMicrocredits)} சோதனை நாணயங்கள்')),
                          if (call.listenerId == state.user!.id)
                            Text(state.text(
                                'Test earnings ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
                                'சோதனை வருமானம் ₹${(call.earningPaise / 100).toStringAsFixed(2)}')),
                          if (!state.isListener)
                            RecentAvailability(
                                state: state, listenerId: call.listenerId),
                          const SizedBox(height: 8),
                          SelectableText(
                              state.text('Call ID: ${call.id}',
                                  'அழைப்பு எண்: ${call.id}'),
                              style: Theme.of(context).textTheme.bodySmall),
                          TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () =>
                                      showSafetyDialog(context, state, call),
                              icon: const Icon(Icons.shield_outlined),
                              label: Text(state.text(
                                  'Report or block', 'புகாரளி அல்லது தடு'))),
                        ]))),
          ],
          if (state.historyLoading ||
              (!state.historyLoaded && state.historyError == null))
            LoadingNotice(
                label: state.text(
                    'Loading calls…', 'அழைப்புகள் ஏற்றப்படுகின்றன…')),
          if (state.historyCursor != null)
            OutlinedButton(
                onPressed: state.historyLoading
                    ? null
                    : () => state.loadHistory(append: true),
                child: Text(state.text(
                    'Load earlier calls', 'முந்தைய அழைப்புகளை காட்டு'))),
        ]));
  }

  String _localDate(DateTime time) {
    final local = time.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.timeZoneName}';
  }
}

Future<void> showSafetyDialog(
    BuildContext context, AppController state, CallSession call) async {
  final owner = state.accountIdentity;
  final result = await showDialog<(String, bool)>(
      context: context, builder: (context) => _SafetyDialog(controller: state));
  if (result != null && owner == state.accountIdentity) {
    await state.submitSafety(call, result.$1, block: result.$2);
    if (context.mounted && state.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.text(
              'Your action was saved.', 'உங்கள் செயல் சேமிக்கப்பட்டது.'))));
    }
  }
}

class _SafetyDialog extends StatefulWidget {
  const _SafetyDialog({required this.controller});
  final AppController controller;
  @override
  State<_SafetyDialog> createState() => _SafetyDialogState();
}

class _SafetyDialogState extends State<_SafetyDialog> {
  final reason = TextEditingController();
  bool block = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    return AlertDialog(
      title: Text(state.text('Report or block', 'புகாரளி அல்லது தடு')),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(state.text(
            'Blocking stops this call and prevents further calls between you. Reports in this test build are stored for review; no staffed response time is promised.',
            'தடுப்பது இந்த அழைப்பை நிறுத்தி எதிர்கால அழைப்புகளைத் தடுக்கும். சோதனை புகார்கள் ஆய்விற்காக சேமிக்கப்படும்; பதிலளிக்கும் நேரம் உறுதி செய்யப்படவில்லை.')),
        const SizedBox(height: 16),
        TextField(
            controller: reason,
            maxLength: 1000,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: state.text('Reason (optional when blocking)',
                    'காரணம் (தடுக்கும்போது விருப்பம்)'))),
        CheckboxListTile(
            value: block,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => block = value!),
            title: Text(state.text('Block this person', 'இவரை தடு'))),
      ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(state.text('Cancel', 'ரத்து'))),
        FilledButton(
            onPressed: !block && reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (reason.text, block)),
            child: Text(state.text('Submit', 'சமர்ப்பி')))
      ],
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return PageBody(children: [
      const ErrorNotice(),
      Text(state.user?.name ?? '',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      Text(state.text('One account • Customer and Listener permissions',
          'ஒரு கணக்கு • வாடிக்கையாளர் மற்றும் கேட்பவர் அனுமதிகள்')),
      const SizedBox(height: 24),
      if (state.user?.listenerApproved == true)
        FilledButton.tonal(
            onPressed: state.canSwitch
                ? () async {
                    await state.switchMode();
                    if (context.mounted) context.go('/home');
                  }
                : null,
            child: Text(state.isListener
                ? state.text('Switch to Customer', 'வாடிக்கையாளராக மாறு')
                : state.text('Switch to Listener', 'கேட்பவராக மாறு')))
      else
        StatusCard(
            title: state.text(
                'Listener approval required', 'கேட்பவருக்கான அங்கீகாரம் தேவை'),
            message: state.text(
                'Only approved Listeners can go online. Apply privately below; staff review is separate.',
                'அங்கீகரிக்கப்பட்ட கேட்பவர்கள் மட்டுமே ஆன்லைன் செல்லலாம். கீழே தனிப்பட்ட முறையில் விண்ணப்பிக்கலாம்; ஊழியர் ஆய்வு தனியானது.')),
      OutlinedButton.icon(
          onPressed: () => context.go('/listener-application'),
          icon: const Icon(Icons.assignment_outlined),
          label: Text(state.text(
              'Apply to be a Listener', 'கேட்பவராக விண்ணப்பிக்கவும்'))),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
          value: state.locale,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: state.text('App language', 'செயலி மொழி')),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ta', child: Text('தமிழ்'))
          ],
          onChanged: (value) => state.setLocale(value!)),
      const SizedBox(height: 24),
      StatusCard(
          title: state.text('Test wallet', 'சோதனை பணப்பை'),
          message: state.text(
              '${creditAmount(state.balance)} test coins; ${creditAmount(state.held)} held for a call. Not redeemable or transferable.',
              '${creditAmount(state.balance)} சோதனை நாணயங்கள்; அழைப்பிற்கு ${creditAmount(state.held)} ஒதுக்கப்பட்டது. பணமாக மாற்றவோ பரிமாற்றவோ முடியாது.')),
      StatusCard(
          title:
              state.text('Privacy in this build', 'இந்த பதிப்பின் தனியுரிமை'),
          message: state.text(
              'Calls are not recorded. Your phone number and date of birth stay private. Review your consent history and the account deletion notice below. Production support and retention approvals remain release requirements.',
              'அழைப்புகள் பதிவு செய்யப்படாது. உங்கள் தொலைபேசி எண் மற்றும் பிறந்த தேதி தனிப்பட்டதாக இருக்கும். ஒப்புதல் வரலாறு மற்றும் கணக்கு நீக்க அறிவிப்பை கீழே படிக்கவும். ஆதரவு மற்றும் தரவு தக்கவைப்பு அனுமதிகள் வெளியீட்டிற்கு தேவை.')),
      OutlinedButton.icon(
          onPressed: () => context.go('/privacy'),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: Text(state.text('Privacy and account deletion',
              'தனியுரிமை மற்றும் கணக்கு நீக்கம்'))),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: state.busy ? null : state.logout,
          icon: const Icon(Icons.logout),
          label: Text(state.text('Sign out', 'வெளியேறு'))),
    ]);
  }
}
