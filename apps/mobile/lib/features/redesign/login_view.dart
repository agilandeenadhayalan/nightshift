part of '../screens.dart';

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
        appBar: AppBar(title: const NightshiftBrand(), actions: [
          TextButton(
              onPressed: () =>
                  state.setLocale(state.locale == 'en' ? 'ta' : 'en'),
              child: Text(state.locale == 'en' ? 'தமிழ்' : 'English')),
        ]),
        body: NightshiftBackdrop(
            child: PageBody(children: [
          const SizedBox(height: 16),
          Center(
              child: SizedBox(
                  width: 160,
                  height: 160,
                  child:
                      const CustomPaint(painter: NightshiftMascotPainter()))),
          const SizedBox(height: 20),
          Text(state.text('A little time to talk.', 'பேசுவதற்கு சிறிது நேரம்.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(
              state.text(
                  'One app. Customer and Listener. Private, one-to-one adult conversation.',
                  'ஒரே செயலி. வாடிக்கையாளர் மற்றும் கேட்பவர். பெரியவர்களுக்கான தனிப்பட்ட உரையாடல்.'),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: NsColors.cyan,
                  foregroundColor: NsColors.background),
              onPressed: () => context.go('/phone-login'),
              icon: const Icon(Icons.phone_outlined),
              label: Text(state.text(
                  'Sign in with your phone', 'தொலைபேசி மூலம் உள்நுழைக'))),
          const SizedBox(height: 12),
          TextButton.icon(
              key: const Key('entry-introduction'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const EntryDesignScreen(
                          designId: 3, preview: false))),
              icon: const Icon(Icons.auto_awesome_outlined),
              label:
                  Text(state.text('Meet NightShift', 'NightShift அறிமுகம்'))),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                    avatar: const Icon(Icons.headphones_rounded, size: 18),
                    label: Text(state.text('Audio', 'ஆடியோ'))),
                Chip(
                    avatar: const Icon(Icons.videocam_outlined, size: 18),
                    label: Text(state.text('Video', 'வீடியோ'))),
                Chip(
                    avatar: const Icon(Icons.lock_outline, size: 18),
                    label: Text(
                        state.text('Private profile', 'தனிப்பட்ட சுயவிவரம்'))),
              ]),
          if (state.privacy.hasSavedReceipt)
            TextButton(
                onPressed: () => context.go('/deletion-status'),
                child: Text(state.text('View saved deletion receipt',
                    'சேமிக்கப்பட்ட நீக்க ரசீதைப் பார்'))),
          const ErrorNotice(),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.science_outlined, color: NsColors.violet),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    state.text('Development test sign-in',
                        'மேம்பாட்டு சோதனை உள்நுழைவு'),
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 10),
          Text(
              state.text(
                  'Fictional accounts and test credits only. No purchases or cash payouts. Keep both phones open during a call.',
                  'சோதனை கணக்குகள் மற்றும் சோதனை நாணயங்கள் மட்டுமே. வாங்குதல் அல்லது பணம் பெறுதல் இல்லை. அழைப்பின்போது இரு செயலிகளையும் திறந்து வைத்திருங்கள்.'),
              style: const TextStyle(color: NsColors.muted)),
          const SizedBox(height: 20),
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
              'This checkbox is development consent. It does not verify age or identity.',
              'இது மேம்பாட்டு சோதனை ஒப்புதல். வயது அல்லது அடையாளத்தை சரிபார்ப்பதில்லை.')),
        ])));
  }
}
