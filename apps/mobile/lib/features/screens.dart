import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/controller.dart';
import '../core/models.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
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
    return Semantics(
        liveRegion: true,
        child: Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      state.offline
                          ? state.text(
                              'Connection unavailable', 'இணைப்பு கிடைக்கவில்லை')
                          : state.text(
                              'Please try again', 'மீண்டும் முயற்சிக்கவும்'),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(state.error!),
                  if (state.diagnosticId != null)
                    SelectableText('Reference: ${state.diagnosticId}'),
                  Wrap(spacing: 8, children: [
                    TextButton(
                        onPressed: () {
                          state.clearError();
                          unawaited(state.refresh());
                        },
                        child: Text(state.text('Retry', 'மீண்டும் முயற்சி'))),
                    TextButton(
                        onPressed: state.clearError,
                        child: Text(state.text('Dismiss', 'மூடு'))),
                  ]),
                ],
              )),
        ));
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
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
        appBar: AppBar(title: const Text('NightShift'), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: Text(
                      state.isListener
                          ? state.text('Listener', 'கேட்பவர்')
                          : state.text('Customer', 'வாடிக்கையாளர்'),
                      style: Theme.of(context).textTheme.labelLarge))),
        ]),
        body: Column(children: [
          Material(
              color: const Color(0xFFE5EBDD),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.science_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            state.text(
                                'TEST CREDITS · Keep the app open for calls',
                                'சோதனை நாணயங்கள் · அழைப்புக்கு செயலியை திறந்து வைத்திருங்கள்'),
                            style: Theme.of(context).textTheme.labelMedium))
                  ]))),
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
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
    final available = state.listeners
        .where((l) => l.languages.contains(state.language))
        .toList();
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
          if (state.isListener) ...[
            StatusCard(
                icon: state.user?.online == true
                    ? Icons.radio_button_checked
                    : Icons.pause_circle_outline,
                title: state.user?.online == true
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
          ] else ...[
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              state.text('Your test credits',
                                  'உங்கள் சோதனை நாணயங்கள்'),
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Text(creditAmount(state.balance - state.held),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          Text(state.text(
                              'Available coins • no purchase required',
                              'கிடைக்கும் நாணயங்கள் • வாங்க வேண்டியதில்லை')),
                        ]))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
                value: state.language,
                decoration: InputDecoration(
                    labelText:
                        state.text('Conversation language', 'உரையாடல் மொழி')),
                items: const [
                  DropdownMenuItem(value: 'ta', child: Text('தமிழ் · Tamil')),
                  DropdownMenuItem(value: 'en', child: Text('English'))
                ],
                onChanged: (value) => state.setLanguage(value!)),
            const SizedBox(height: 16),
            if (available.isEmpty)
              StatusCard(
                  title: state.text('No listeners available yet',
                      'கேட்பவர்கள் தற்போது இல்லை'),
                  message: state.text(
                      'Ask the test Listener to go online on the other phone, then refresh.',
                      'மற்ற தொலைபேசியில் கேட்பவரை ஆன்லைன் செல்லச் சொல்லி, புதுப்பிக்கவும்.'),
                  action: OutlinedButton.icon(
                      onPressed: state.refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(state.text('Refresh', 'புதுப்பி')))),
            for (final listener in available)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const CircleAvatar(
                                  child: Icon(Icons.person_outline)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(listener.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge))
                            ]),
                            const SizedBox(height: 12),
                            Text(listener.available
                                ? state.text('● Available for audio',
                                    '● ஆடியோவிற்கு கிடைக்கிறார்')
                                : state.text('Busy or offline',
                                    'பிஸியாக அல்லது ஆஃப்லைன்')),
                            Text(listener.languages
                                .map((l) => l == 'ta' ? 'தமிழ்' : 'English')
                                .join(' · ')),
                            const SizedBox(height: 8),
                            Text(state.text('60 test coins / minute',
                                'நிமிடத்திற்கு 60 சோதனை நாணயங்கள்')),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                onPressed: !listener.available ||
                                        state.busy ||
                                        state.offline
                                    ? null
                                    : () =>
                                        _confirmCall(context, state, listener),
                                icon: const Icon(Icons.call_outlined),
                                label: Text(state.text('Call', 'அழை'))),
                          ]))),
          ],
        ]));
  }

  Future<void> _confirmCall(BuildContext context, AppController state,
      ListenerProfile listener) async {
    final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(state.text(
                  'Call ${listener.name}', '${listener.name} அழைக்கவும்')),
              content: SingleChildScrollView(
                  child: Text(state.text(
                      'Test credits only. Ringing is free. Up to 40 connected seconds is free; crossing 40 seconds charges 60 coins covering the first minute, then 1 coin per additional second. Reconnect gaps are free. Maximum 10 minutes, limited by your balance. Both phones must keep the app open.',
                      'சோதனை நாணயங்கள் மட்டுமே. காத்திருப்பு இலவசம். 40 இணைப்பு விநாடிகள் வரை இலவசம்; அதைத் தாண்டினால் முதல் நிமிடத்திற்கு 60 நாணயங்கள், பின்னர் விநாடிக்கு 1 நாணயம். மீண்டும் இணைப்பு இடைவெளி இலவசம். இருப்புக்கு உட்பட்டு அதிகபட்சம் 10 நிமிடங்கள். இரு செயலிகளும் திறந்திருப்பது அவசியம்.'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(state.text('Cancel', 'ரத்து'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(state.text(
                        'Start audio call', 'ஆடியோ அழைப்பைத் தொடங்கு')))
              ],
            ));
    if (agreed == true) await state.startCall(listener);
  }
}

class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider),
        call = ref.watch(appControllerProvider).activeCall;
    if (call == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final incoming = call.listenerId == state.user?.id;
    final title = state.endingLocally
        ? state.text('Audio stopped · waiting for server',
            'ஆடியோ நிறுத்தப்பட்டது · சேவையகத்திற்காக காத்திருக்கிறது')
        : switch (call.state) {
            'ringing' => incoming
                ? state.text('Incoming audio call', 'வரும் ஆடியோ அழைப்பு')
                : state.text('Calling…', 'அழைக்கிறது…'),
            'connected' => state.text('Connected', 'இணைக்கப்பட்டது'),
            'reconnecting' => state.text('Reconnecting · not charging',
                'மீண்டும் இணைகிறது · கட்டணம் இல்லை'),
            _ => state.text('Connecting audio · not charging',
                'ஆடியோ இணைகிறது · கட்டணம் இல்லை'),
          };
    return PopScope(
        canPop: false,
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(state.text('Audio call', 'ஆடியோ அழைப்பு'))),
            body: PageBody(children: [
              const ErrorNotice(),
              const SizedBox(height: 24),
              const CircleAvatar(
                  radius: 48, child: Icon(Icons.person_outline, size: 48)),
              const SizedBox(height: 24),
              Text(call.otherName(state.user!.id),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Semantics(
                  liveRegion: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 24),
              if (call.ringing) ...[
                Text(
                    state.text(
                        'Ringing and waiting are free. The invitation expires automatically.',
                        'காத்திருப்பு இலவசம். அழைப்பு தானாக காலாவதியாகும்.'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (incoming) ...[
                  Text(state.text(
                      'Proposed rate: ₹500 / paid connected hour. Test estimate only.',
                      'முன்மொழியப்பட்ட விகிதம்: கட்டண இணைப்பு மணிநேரத்திற்கு ₹500. சோதனை மதிப்பீடு மட்டுமே.')),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed:
                          state.busy ? null : () => state.transition('accept'),
                      icon: const Icon(Icons.call),
                      label: Text(state.text('Accept', 'ஏற்கவும்'))),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () =>
                            state.transition(incoming ? 'decline' : 'cancel'),
                    child: Text(incoming
                        ? state.text('Decline', 'நிராகரி')
                        : state.text('Cancel call', 'அழைப்பை ரத்து செய்'))),
              ] else ...[
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
                          onPressed: state.endingLocally || state.busy
                              ? null
                              : () => state.perform(state.audio.toggleMute),
                          icon: Icon(
                              state.audio.muted ? Icons.mic_off : Icons.mic),
                          label: Text(state.audio.muted
                              ? state.text('Unmute', 'ஒலியை இயக்கு')
                              : state.text('Mute', 'ஒலியை நிறுத்து'))),
                      OutlinedButton.icon(
                          onPressed: state.endingLocally || state.busy
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
                const SizedBox(height: 24),
                FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed:
                        state.busy ? null : () => state.transition('end'),
                    icon: const Icon(Icons.call_end),
                    label: Text(state.text('End call', 'அழைப்பை முடி'))),
                const SizedBox(height: 16),
                Text(
                    state.text(
                        'Leaving or locking the app ends this test call. No audio is recorded.',
                        'செயலியிலிருந்து வெளியேறினால் அல்லது பூட்டினால் அழைப்பு முடியும். ஆடியோ பதிவு செய்யப்படுவதில்லை.'),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => showSafetyDialog(context, state, call),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(
                      state.text('Report or block', 'புகாரளி அல்லது தடு'))),
              const SizedBox(height: 24),
              SelectableText('Call ID: ${call.id}',
                  style: Theme.of(context).textTheme.bodySmall),
            ])));
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appControllerProvider).loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final earned = state.history
        .where((c) => c.listenerId == state.user?.id)
        .fold<int>(0, (sum, call) => sum + call.earningPaise);
    return RefreshIndicator(
        onRefresh: state.loadHistory,
        child: PageBody(children: [
          const ErrorNotice(),
          Text(
              state.isListener
                  ? state.text(
                      'Earnings & calls', 'வருமானம் மற்றும் அழைப்புகள்')
                  : state.text('Your conversations', 'உங்கள் உரையாடல்கள்'),
              style: Theme.of(context).textTheme.headlineSmall),
          if (state.isListener)
            StatusCard(
                title: '₹${(earned / 100).toStringAsFixed(2)}',
                message: state.text(
                    'Test earnings in the displayed history. No cash payouts. Rate and settlement are controlled by the backend.',
                    'காட்டப்பட்ட வரலாற்றின் சோதனை வருமானம். உண்மையான பணம் வழங்கப்படாது. விகிதமும் தீர்வும் சேவையகத்தால் கணக்கிடப்படும்.')),
          const SizedBox(height: 16),
          if (state.history.isEmpty)
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
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(call.otherName(state.user!.id),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                              '${_localDate(call.createdAt)} · ${durationLabel(call.connectedMs)}'),
                          Text(state.text(
                              'End reason: ${call.reason ?? 'ended'}',
                              'முடிவு காரணம்: ${call.reason ?? 'ended'}')),
                          Text(state.text(
                              '${creditAmount(call.chargeMicrocredits)} test coins',
                              '${creditAmount(call.chargeMicrocredits)} சோதனை நாணயங்கள்')),
                          if (call.listenerId == state.user!.id)
                            Text(state.text(
                                'Test earnings ₹${(call.earningPaise / 100).toStringAsFixed(2)}',
                                'சோதனை வருமானம் ₹${(call.earningPaise / 100).toStringAsFixed(2)}')),
                          const SizedBox(height: 8),
                          SelectableText('Call ID: ${call.id}',
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
          if (state.historyLoading)
            const Center(child: CircularProgressIndicator()),
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
  final result = await showDialog<(String, bool)>(
      context: context, builder: (context) => _SafetyDialog(controller: state));
  if (result != null) {
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
                'Only manually approved test listeners can go online. Review and application tooling is separate from this app.',
                'அங்கீகரிக்கப்பட்ட சோதனை கேட்பவர்கள் மட்டுமே ஆன்லைன் செல்லலாம். விண்ணப்ப ஆய்வு இந்த செயலியிலிருந்து தனியானது.')),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
          value: state.locale,
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
              'No call recording, phone numbers, bank details or provider secrets are required on this device. Use consenting adults and fictional test accounts. Production support, reports and account deletion remain release gates.',
              'அழைப்புப் பதிவு, தொலைபேசி எண்கள், வங்கி விவரங்கள் அல்லது சேவை ரகசியங்கள் இந்த சாதனத்தில் தேவையில்லை. ஒப்புக்கொண்ட பெரியவர்கள் மற்றும் சோதனை கணக்குகளைப் பயன்படுத்தவும். ஆதரவும் கணக்கு நீக்கமும் வெளியீட்டிற்கு முன் முடிக்கப்பட வேண்டும்.')),
      const SizedBox(height: 16),
      OutlinedButton.icon(
          onPressed: state.busy ? null : state.logout,
          icon: const Icon(Icons.logout),
          label: Text(state.text('Sign out', 'வெளியேறு'))),
    ]);
  }
}
