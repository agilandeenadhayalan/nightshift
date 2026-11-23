part of '../screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final isListener = state.isListener;
    return PageBody(children: [
      const ErrorNotice(),
      NightshiftProfileHero(
          name: state.user?.name ?? '',
          avatarCode: state.user?.avatarCode,
          roleLabel: isListener
              ? state.text('Listener', 'கேட்பவர்')
              : state.text('Customer', 'வாடிக்கையாளர்'),
          roleIcon:
              isListener ? Icons.headset_mic_outlined : Icons.person_outline,
          editLabel: state.text('Edit profile', 'சுயவிவரத்தை திருத்து'),
          onEdit: state.busy || state.hasCall
              ? null
              : () => context.push('/edit-profile'),
          footer: isListener ? null : _ProfileWallet(state: state)),
      const SizedBox(height: 14),
      if (state.user?.listenerApproved == true)
        FilledButton.tonalIcon(
            onPressed: state.canSwitch
                ? () async {
                    await state.switchMode();
                    if (context.mounted) context.go('/home');
                  }
                : null,
            icon: const Icon(Icons.swap_horiz),
            label: Text(isListener
                ? state.text('Switch to Customer', 'வாடிக்கையாளராக மாறு')
                : state.text('Switch to Listener', 'கேட்பவராக மாறு')))
      else
        InkWell(
            onTap: () => context.go('/listener-application'),
            borderRadius: BorderRadius.circular(18),
            child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF311451), Color(0xFF17132E)]),
                    border: Border.all(color: NsColors.violet.withAlpha(55))),
                child: Row(children: [
                  const Icon(Icons.headset_mic_outlined,
                      color: Color(0xFFC4B5FD)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(state.text('Become a Listener', 'கேட்பவராகுங்கள்'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                            state.text('Listener approval required',
                                'கேட்பவருக்கான அங்கீகாரம் தேவை'),
                            style: const TextStyle(
                                color: NsColors.muted, fontSize: 11)),
                      ])),
                  const Icon(Icons.chevron_right, size: 19)
                ]))),
      const SizedBox(height: 14),
      NightshiftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Column(children: [
            if (!isListener)
              _ProfileMenuRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: state.text('Open wallet', 'பணப்பையைத் திற'),
                  onTap: () => context.push('/wallet')),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.receipt_long_outlined,
                title: state.text('Transactions & calls',
                    'பரிவர்த்தனைகள் மற்றும் அழைப்புகள்'),
                onTap: () => context.go('/history')),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.translate,
                title: state.text('Language settings', 'மொழி அமைப்புகள்'),
                value: state.locale == 'ta' ? 'தமிழ்' : 'English',
                onTap: () => showAppLanguageSettings(context, state)),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.edit_outlined,
                title: state.text('Edit profile', 'சுயவிவரத்தை திருத்து'),
                onTap: state.busy || state.hasCall
                    ? null
                    : () => context.push('/edit-profile')),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.assignment_outlined,
                title: state.user?.listenerApproved == true
                    ? state.text('Listener application', 'கேட்பவர் விண்ணப்பம்')
                    : state.text(
                        'Apply to be a Listener', 'கேட்பவராக விண்ணப்பிக்கவும்'),
                onTap: () => context.go('/listener-application')),
            if (isListener) ...[
              const Divider(height: 1),
              _ProfileMenuRow(
                  icon: Icons.diamond_outlined,
                  title: state.text('Earnings & withdrawal history',
                      'வருமானம் மற்றும் பணம் பெறும் வரலாறு'),
                  onTap: () => context.push('/earnings')),
            ],
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.perm_camera_mic_outlined,
                title: state.text('Call permissions', 'அழைப்பு அனுமதிகள்'),
                onTap: state.busy || state.hasCall
                    ? null
                    : () => showCallPermissions(context, state)),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.help_outline,
                title: state.text('Help & support', 'உதவி மற்றும் ஆதரவு'),
                onTap: () => context.push('/support')),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.privacy_tip_outlined,
                title: state.text('Privacy and account deletion',
                    'தனியுரிமை மற்றும் கணக்கு நீக்கம்'),
                onTap: () => context.go('/privacy')),
            const Divider(height: 1),
            _ProfileMenuRow(
                icon: Icons.admin_panel_settings_outlined,
                title: state.text('Staff workspace', 'ஊழியர் பணியிடம்'),
                onTap: state.busy || state.hasCall
                    ? null
                    : () => context.go('/staff')),
          ])),
      const SizedBox(height: 14),
      if (isListener && state.user?.listenerApproved == true) ...[
        const SizedBox(height: 16),
        InvitationSettings(controller: state),
      ],
      const SizedBox(height: 18),
      Text(
          state.text(
              'Calls are not recorded. Your phone number and date of birth stay private.',
              'அழைப்புகள் பதிவு செய்யப்படாது. உங்கள் தொலைபேசி எண் மற்றும் பிறந்த தேதி தனிப்பட்டதாக இருக்கும்.'),
          style: const TextStyle(color: NsColors.muted, fontSize: 11)),
      const SizedBox(height: 14),
      OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFB7185)),
          onPressed: state.busy ? null : state.logout,
          icon: const Icon(Icons.logout),
          label: Text(state.text('Sign out', 'வெளியேறு'))),
      const SizedBox(height: 10),
      TextButton.icon(
          onPressed: () => context.push('/designs'),
          icon: const Icon(Icons.palette_outlined),
          label: Text(state.text(
              'Design collection · 54 screens', 'வடிவமைப்புகள் · 54 திரைகள்'))),
    ]);
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.value});
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: NsColors.violet.withAlpha(24)),
            child: Icon(icon, color: NsColors.muted, size: 19)),
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: value == null
            ? const Icon(Icons.chevron_right, size: 20)
            : Text(value!,
                style: const TextStyle(color: NsColors.gold, fontSize: 10)),
        enabled: onTap != null,
        onTap: onTap,
      );
}

class _ProfileWallet extends StatelessWidget {
  const _ProfileWallet({required this.state});
  final AppController state;
  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
            color: const Color(0xFF22212A),
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: () => context.push('/wallet'),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.toll_rounded,
                          color: NsColors.gold, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                state.text('Available test coins',
                                    'கிடைக்கும் சோதனை நாணயங்கள்'),
                                style: const TextStyle(
                                    color: NsColors.muted, fontSize: 10)),
                            const SizedBox(height: 4),
                            Text(creditAmount(state.balance - state.held),
                                style: const TextStyle(
                                    color: NsColors.gold,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800)),
                          ])),
                      const Icon(Icons.chevron_right, color: NsColors.gold),
                    ])))),
        const SizedBox(height: 8),
        Text(
            state.text('${creditAmount(state.held)} held for a call · Not cash',
                'அழைப்பிற்கு ${creditAmount(state.held)} ஒதுக்கப்பட்டது · பணம் அல்ல'),
            style: const TextStyle(color: NsColors.muted, fontSize: 10)),
      ]);
}

Future<void> showAppLanguageSettings(
    BuildContext context, AppController state) async {
  final owner = state.accountIdentity;
  await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
          animation: state,
          builder: (context, _) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(state.text('App language', 'செயலி மொழி'),
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        for (final locale in ['en', 'ta'])
                          RadioListTile<String>(
                              value: locale,
                              groupValue: state.locale,
                              title: Text(locale == 'ta' ? 'தமிழ்' : 'English'),
                              onChanged: owner != state.accountIdentity
                                  ? null
                                  : (value) {
                                      if (value != null &&
                                          owner == state.accountIdentity) {
                                        state.setLocale(value);
                                      }
                                    }),
                      ])))));
}

Future<void> showCallPermissions(
    BuildContext context, AppController state) async {
  final owner = state.accountIdentity;
  final listener = state.isListener;
  await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(state.text('Call permissions', 'அழைப்பு அனுமதிகள்'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    for (final item in <(int, IconData, String)>[
                      (
                        13,
                        Icons.mic_none,
                        state.text('Microphone', 'மைக்ரோஃபோன்')
                      ),
                      (
                        listener ? 53 : 47,
                        Icons.videocam_outlined,
                        state.text('Camera & video', 'கேமரா மற்றும் வீடியோ')
                      ),
                      (
                        listener ? 7 : 9,
                        Icons.notifications_outlined,
                        state.text('Notifications', 'அறிவிப்புகள்')
                      ),
                      (
                        listener ? 8 : 42,
                        Icons.bluetooth,
                        state.text('Nearby devices', 'அருகிலுள்ள சாதனங்கள்')
                      ),
                    ])
                      _ProfileMenuRow(
                          icon: item.$2,
                          title: item.$3,
                          onTap: () {
                            if (owner != state.accountIdentity ||
                                state.hasCall) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => EntryDesignScreen(
                                    designId: item.$1, preview: false)));
                          }),
                  ]))));
}
