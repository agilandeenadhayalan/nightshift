part of '../screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return PageBody(children: [
      const ErrorNotice(),
      const SizedBox(height: 20),
      Center(
          child: NightshiftAvatar(
              name: state.user?.name ?? '',
              size: 112,
              listener: state.isListener)),
      const SizedBox(height: 16),
      Text(state.user?.name ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
          state.text('One account • Customer and Listener permissions',
              'ஒரு கணக்கு • வாடிக்கையாளர் மற்றும் கேட்பவர் அனுமதிகள்'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: NsColors.muted)),
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
        NightshiftSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.headset_mic_rounded, color: NsColors.cyan, size: 32),
          const SizedBox(height: 12),
          Text(
              state.text('Listener approval required',
                  'கேட்பவருக்கான அங்கீகாரம் தேவை'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(state.text(
              'Only approved Listeners can go online. Apply privately below; staff review is separate.',
              'அங்கீகரிக்கப்பட்ட கேட்பவர்கள் மட்டுமே ஆன்லைன் செல்லலாம். கீழே தனிப்பட்ட முறையில் விண்ணப்பிக்கலாம்; ஊழியர் ஆய்வு தனியானது.')),
        ])),
      const SizedBox(height: 18),
      NightshiftSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.toll_rounded, color: NsColors.gold, size: 36),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(state.text('Test wallet', 'சோதனை பணப்பை'),
                    style: const TextStyle(color: NsColors.muted)),
                Text(
                    '${creditAmount(state.balance)} ${state.text('test coins', 'சோதனை நாணயங்கள்')}',
                    style: Theme.of(context).textTheme.titleLarge),
              ]))
        ]),
        const SizedBox(height: 12),
        Text(
            state.text(
                '${creditAmount(state.held)} held for a call. Not redeemable or transferable.',
                'அழைப்பிற்கு ${creditAmount(state.held)} ஒதுக்கப்பட்டது. பணமாக மாற்றவோ பரிமாற்றவோ முடியாது.'),
            style: const TextStyle(color: NsColors.muted, fontSize: 12)),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
            onPressed: () => context.push('/wallet'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: Text(state.text('Open wallet', 'பணப்பையைத் திற'))),
      ])),
      const SizedBox(height: 18),
      const SizedBox(height: 18),
      NightshiftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            _ProfileMenuRow(
                icon: Icons.assignment_outlined,
                title: state.text(
                    'Apply to be a Listener', 'கேட்பவராக விண்ணப்பிக்கவும்'),
                onTap: () => context.go('/listener-application')),
            if (state.isListener) ...[
              const Divider(height: 1),
              _ProfileMenuRow(
                  icon: Icons.diamond_outlined,
                  title: state.text('Earnings & withdrawal history',
                      'வருமானம் மற்றும் பணம் பெறும் வரலாறு'),
                  onTap: () => context.push('/earnings')),
            ],
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
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
          value: state.locale,
          isExpanded: true,
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.translate),
              labelText: state.text('App language', 'செயலி மொழி')),
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ta', child: Text('தமிழ்'))
          ],
          onChanged: (value) {
            if (value != null) state.setLocale(value);
          }),
      if (state.isListener && state.user?.listenerApproved == true) ...[
        const SizedBox(height: 20),
        InvitationSettings(controller: state),
      ],
      const SizedBox(height: 24),
      Text(state.text('Privacy in this build', 'இந்த பதிப்பின் தனியுரிமை'),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
          state.text(
              'Calls are not recorded. Your phone number and date of birth stay private. Review your consent history and the account deletion notice below. Production support and retention approvals remain release requirements.',
              'அழைப்புகள் பதிவு செய்யப்படாது. உங்கள் தொலைபேசி எண் மற்றும் பிறந்த தேதி தனிப்பட்டதாக இருக்கும். ஒப்புதல் வரலாறு மற்றும் கணக்கு நீக்க அறிவிப்பை கீழே படிக்கவும். ஆதரவு மற்றும் தரவு தக்கவைப்பு அனுமதிகள் வெளியீட்டிற்கு தேவை.'),
          style: const TextStyle(color: NsColors.muted, fontSize: 12)),
      const SizedBox(height: 20),
      OutlinedButton.icon(
          onPressed: state.busy ? null : state.logout,
          icon: const Icon(Icons.logout),
          label: Text(state.text('Sign out', 'வெளியேறு'))),
      const SizedBox(height: 16),
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
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: NsColors.violet.withAlpha(24)),
            child: Icon(icon, color: NsColors.violet)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, size: 20),
        enabled: onTap != null,
        onTap: onTap,
      );
}
