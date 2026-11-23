import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/controller.dart';
import '../core/matching.dart';
import 'screens.dart' show PageBody, ErrorNotice, StatusCard;
import 'video_preflight.dart' show testRateLabel, testTariffDescription;
import 'redesign/design_system.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});
  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

/// Unknown candidates remain neutral. A portrait is shown only after the
/// matching request identifies an actual call with a selected avatar code.
class _MatchingPortraitRail extends StatelessWidget {
  const _MatchingPortraitRail({this.avatarCode});
  final String? avatarCode;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: SizedBox(
          height: 266,
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
                left: 4,
                top: 34,
                child: Transform.rotate(
                    angle: -.12,
                    child: Opacity(
                        opacity: .36,
                        child: _candidate(width: 122, height: 196)))),
            Positioned(
                right: 4,
                top: 34,
                child: Transform.rotate(
                    angle: .12,
                    child: Opacity(
                        opacity: .36,
                        child: _candidate(width: 122, height: 196)))),
            Container(
                width: 186,
                height: 252,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: NsColors.cyan, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: NsColors.cyan.withValues(alpha: .13),
                          blurRadius: 36)
                    ]),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(fit: StackFit.expand, children: [
                      if (avatarAssetPath(avatarCode) case final asset?)
                        AvatarPortrait(
                            assetPath: asset, borderRadius: BorderRadius.zero)
                      else
                        _candidate(width: 180, height: 246),
                      Align(
                          alignment: const Alignment(0, .35),
                          child: Container(
                              height: 2,
                              decoration: const BoxDecoration(
                                  color: NsColors.cyan,
                                  boxShadow: [
                                    BoxShadow(
                                        color: NsColors.cyan,
                                        blurRadius: 14,
                                        spreadRadius: 2)
                                  ]))),
                    ]))),
          ])));

  Widget _candidate({required double width, required double height}) =>
      Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white12),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF394565), Color(0xFF151B32)])),
          child: const Center(child: NightshiftAvatar(name: '', size: 76)));
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  bool consent = false, reviewNewSearch = false;
  String? selectedLanguage, seenRequestId;
  Object? owner;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider), matching = state.matching;
    if (owner != state.accountIdentity) {
      owner = state.accountIdentity;
      consent = false;
      selectedLanguage = state.user?.languages.contains(state.language) == true
          ? state.language
          : state.user?.languages.firstOrNull;
    }
    final request = matching.request;
    if (seenRequestId != request?.id) {
      seenRequestId = request?.id;
      reviewNewSearch = false;
      consent = false;
    }
    if (selectedLanguage != null &&
        state.user?.languages.contains(selectedLanguage) != true) {
      selectedLanguage = state.user?.languages.firstOrNull;
      consent = false;
    }
    final busy = matching.busy || state.busy;
    final pending = matching.uncertain;
    final showConsent =
        !matching.blocked && (request?.state != 'matched' || reviewNewSearch);
    return PopScope(
        canPop: !matching.blocked,
        child: Scaffold(
            appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                title: Text(state.text('Find a Listener', 'கேட்பவரைத் தேடு')),
                actions: [
                  if (!matching.blocked)
                    IconButton(
                        tooltip: state.text('Close search', 'தேடலை மூடு'),
                        onPressed: matching.dismiss,
                        icon: const Icon(Icons.close))
                ]),
            bottomNavigationBar: request?.active == true
                ? SafeArea(
                    minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton.tonal(
                        onPressed:
                            busy || pending != null ? null : matching.cancel,
                        child: Text(
                            state.text('Cancel search', 'தேடலை ரத்து செய்'))))
                : null,
            body: PageBody(children: [
              const ErrorNotice(),
              if (matching.loading || busy)
                LinearProgressIndicator(
                    semanticsLabel: state.text('Updating search status',
                        'தேடல் நிலையை புதுப்பிக்கிறது')),
              if (request != null) ...[
                if (request.active)
                  _MatchingPortraitRail(
                      avatarCode: request.callId != null &&
                              state.activeCall?.id == request.callId
                          ? state.activeCall?.listenerAvatarCode
                          : null),
                Text(_title(state, request),
                    textAlign: request.active ? TextAlign.center : null,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(state.text(
                    'Audio · ${request.language == 'ta' ? 'Tamil' : 'English'} · Attempt ${request.attemptCount} of 3',
                    'ஆடியோ · ${request.language == 'ta' ? 'தமிழ்' : 'ஆங்கிலம்'} · முயற்சி ${request.attemptCount} / 3')),
                if (request.active) ...[
                  const SizedBox(height: 12),
                  Text(matching.remainingSeconds > 0
                      ? state.text(
                          'Up to ${matching.remainingSeconds}s remaining',
                          'அதிகபட்சம் ${matching.remainingSeconds} வினாடிகள் மீதம்')
                      : state.text(
                          'The wait budget has elapsed. Checking the final status…',
                          'காத்திருப்பு நேரம் முடிந்தது. இறுதி நிலையை சரிபார்க்கிறது…')),
                  Text(state.text(
                      'Searching and ringing use no test credits. Keep the app open for the call.',
                      'தேடலுக்கும் அழைப்பு மணிக்கும் சோதனை நாணயங்கள் செலவாகாது. அழைப்புக்காக செயலியை திறந்து வைக்கவும்.')),
                  if (request.callId != null &&
                      state.activeCall?.id == request.callId)
                    Text(state.text(
                        'Inviting ${state.activeCall!.listenerName}',
                        '${state.activeCall!.listenerName} அழைக்கப்படுகிறார்')),
                  if (request.reasons.isNotEmpty)
                    Text(state.text(
                        'Selected for language, current availability and fair rotation.',
                        'மொழி, தற்போதைய கிடைக்கும் நிலை மற்றும் சமமான வாய்ப்பு அடிப்படையில் தேர்வு.')),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(_outcome(state, request)),
                  if (request.state == 'matched') ...[
                    Text(state.text(
                        'This search will not invite another Listener. Call status is checked separately.',
                        'இந்த தேடல் மற்றொரு கேட்பவரை அழைக்காது. அழைப்பு நிலை தனியாக சரிபார்க்கப்படும்.')),
                    OutlinedButton(
                        onPressed: state.refresh,
                        child: Text(state.text(
                            'Refresh call status', 'அழைப்பு நிலையை புதுப்பி'))),
                    if (!state.hasCall && !reviewNewSearch)
                      OutlinedButton(
                          onPressed: busy
                              ? null
                              : () {
                                  setState(() {
                                    reviewNewSearch = true;
                                    consent = false;
                                  });
                                  unawaited(matching.loadRate());
                                },
                          child: Text(state.text('Review a new audio search',
                              'புதிய ஆடியோ தேடலை பரிசீலி'))),
                  ],
                ],
              ],
              if (pending != null)
                StatusCard(
                    title: state.text('Request outcome not yet confirmed',
                        'கோரிக்கையின் முடிவு இன்னும் உறுதியாகவில்லை'),
                    message: state.text(
                        'Check status before retrying. No new search or cancellation is sent automatically.',
                        'மீண்டும் முயற்சிக்கும் முன் நிலையை சரிபார்க்கவும். புதிய தேடலோ ரத்துசெய்தலோ தானாக அனுப்பப்படாது.'),
                    action: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton(
                              onPressed: busy || matching.loading
                                  ? null
                                  : matching.recover,
                              child: Text(state.text('Check search status',
                                  'தேடல் நிலையை சரிபார்'))),
                          if (matching.retryAllowed)
                            FilledButton(
                                onPressed: busy ? null : matching.retry,
                                child: Text(state.text('Retry the same request',
                                    'அதே கோரிக்கையை மீண்டும் முயற்சி'))),
                        ])),
              if (matching.error != null)
                StatusCard(
                    title: state.text('Search status needs attention',
                        'தேடல் நிலையை சரிபார்க்கவும்'),
                    message: _error(state, matching.error!.code),
                    action: OutlinedButton(
                        onPressed: busy || matching.loading
                            ? null
                            : () async {
                                await matching.recover();
                                if (!matching.blocked) {
                                  await matching.loadRate();
                                }
                              },
                        child: Text(state.text('Refresh search status',
                            'தேடல் நிலையை புதுப்பி')))),
              if (showConsent) ...[
                const SizedBox(height: 20),
                Text(
                    state.text('A bounded audio search',
                        'வரையறுக்கப்பட்ட ஆடியோ தேடல்'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(state.text(
                    'Try up to 3 Listeners, one at a time, within 90 seconds total. Each invitation lasts at most 30 seconds. Availability is not guaranteed. Searching, ringing and declined invitations cost no test credits.',
                    'மொத்தம் 90 வினாடிகளுக்குள், ஒருவருக்குப் பின் ஒருவராக அதிகபட்சம் 3 கேட்பவர்களை முயற்சிக்கலாம். ஒவ்வொரு அழைப்புக்கும் அதிகபட்சம் 30 வினாடிகள். கிடைப்பது உறுதியல்ல. தேடல், அழைப்பு மணி, மறுக்கப்பட்ட அழைப்புகளுக்கு சோதனை நாணயங்கள் செலவாகாது.')),
                const SizedBox(height: 12),
                if (matching.rate != null) ...[
                  Text(testRateLabel(state, matching.rate!)),
                  Text(testTariffDescription(state, matching.rate!)),
                ] else
                  Text(state.text('Loading the server test-credit rate…',
                      'சேவையக சோதனை நாணய விகிதம் ஏற்றப்படுகிறது…')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: state.text(
                            'Conversation language', 'உரையாடல் மொழி')),
                    items: [
                      for (final language
                          in state.user?.languages ?? <String>[])
                        DropdownMenuItem(
                            value: language,
                            child: Text(
                                language == 'ta' ? 'தமிழ் · Tamil' : 'English'))
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                              selectedLanguage = value;
                              consent = false;
                            })),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => consent = value == true),
                    title: Text(state.text(
                        'I agree to this audio search and the displayed test-credit rate.',
                        'இந்த ஆடியோ தேடலுக்கும் காட்டப்பட்ட சோதனை நாணய விகிதத்திற்கும் ஒப்புக்கொள்கிறேன்.'))),
                FilledButton(
                    onPressed: busy ||
                            matching.loading ||
                            !matching.restored ||
                            matching.rate == null ||
                            !consent ||
                            selectedLanguage == null
                        ? null
                        : () async {
                            final expectedOwner = owner,
                                language = selectedLanguage!;
                            if (expectedOwner != state.accountIdentity) return;
                            await state.startMatching(
                                language: language, consent: consent);
                            if (mounted) setState(() => consent = false);
                          },
                    child: Text(state.text(
                        'Start audio search', 'ஆடியோ தேடலைத் தொடங்கு'))),
              ],
              if (!matching.blocked)
                TextButton(
                    onPressed: matching.dismiss,
                    child: Text(state.text(
                        'Back to Discover', 'கண்டறி பக்கத்திற்கு திரும்பு'))),
            ])));
  }

  String _title(AppController state, MatchRequest request) =>
      switch (request.state) {
        'searching' => state.text('Finding an available Listener…',
            'கிடைக்கும் கேட்பவரைத் தேடுகிறது…'),
        'ringing' => state.text(
            'Waiting for a Listener…', 'கேட்பவருக்காக காத்திருக்கிறது…'),
        'matched' =>
          state.text('Listener accepted', 'கேட்பவர் ஏற்றுக்கொண்டார்'),
        'cancelled' =>
          state.text('Search cancelled', 'தேடல் ரத்துசெய்யப்பட்டது'),
        _ => state.text('Search finished', 'தேடல் முடிந்தது'),
      };

  String _outcome(AppController state, MatchRequest request) =>
      switch (request.reason) {
        'insufficient_balance' => state.text(
            'This search stopped because available test credits were insufficient.',
            'சோதனை நாணயங்கள் போதாததால் தேடல் நிறுத்தப்பட்டது.'),
        'quote_unavailable' => state.text(
            'The quoted rate is no longer available. Review a fresh rate before starting again.',
            'காட்டப்பட்ட விகிதம் கிடைக்கவில்லை. புதிய தேடலுக்கு முன் புதிய விகிதத்தை பார்க்கவும்.'),
        'safety_blocked' ||
        'account_restricted' ||
        'source_session_ended' =>
          state.text(
              'This search stopped. Check your account and session before starting another.',
              'இந்த தேடல் நிறுத்தப்பட்டது. புதிய தேடலுக்கு முன் கணக்கையும் அமர்வையும் சரிபார்க்கவும்.'),
        'customer_cancelled' => state.text(
            'The search was cancelled. Unconnected invitations use no test credits.',
            'தேடல் ரத்துசெய்யப்பட்டது. இணைக்காத அழைப்புகளுக்கு சோதனை நாணயங்கள் செலவாகாது.'),
        _ => request.state == 'matched'
            ? state.text(
                'An invitation was accepted.', 'அழைப்பு ஏற்றுக்கொள்ளப்பட்டது.')
            : state.text(
                'No Listener connected in this bounded search. Unconnected invitations use no test credits.',
                'இந்த வரையறுக்கப்பட்ட தேடலில் கேட்பவர் இணைக்கப்படவில்லை. இணைக்காத அழைப்புகளுக்கு சோதனை நாணயங்கள் செலவாகாது.'),
      };

  String _error(AppController state, String code) => switch (code) {
        'MATCH_STALE_VERSION' || 'MATCH_ACTIVE' || 'CALL_ACTIVE' => state.text(
            'The current request changed. Refresh its status before another action.',
            'தற்போதைய கோரிக்கை மாறிவிட்டது. அடுத்த செயலுக்கு முன் நிலையை புதுப்பிக்கவும்.'),
        'INSUFFICIENT_BALANCE' => state.text(
            'Not enough available test credits for a call.',
            'அழைப்புக்கு போதுமான சோதனை நாணயங்கள் இல்லை.'),
        'QUOTE_EXPIRED' => state.text(
            'Review a fresh test-credit rate before starting again.',
            'மீண்டும் தொடங்கும் முன் புதிய சோதனை நாணய விகிதத்தை பார்க்கவும்.'),
        'UNAUTHENTICATED' || 'PRIVATE_SESSION_CHANGED' => state.text(
            'Sign in again to recover the current search.',
            'தற்போதைய தேடலை மீட்க மீண்டும் உள்நுழைக.'),
        _ => state.text(
            'Check your connection and refresh. A failed response does not confirm a cancelled search.',
            'இணைப்பை சரிபார்த்து புதுப்பிக்கவும். பதில் தோல்வியடைந்தால் தேடல் ரத்தானதாக அர்த்தமல்ல.'),
      };
}
