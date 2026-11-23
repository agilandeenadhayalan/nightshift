part of '../screens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final isListener = state.isListener;
    return PageBody(children: [
      const ErrorNotice(),
      Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: BoxDecoration(
              color: const Color(0xFF171722),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white10)),
          child: Column(children: [
            Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                    tooltip: state.text('Edit profile', 'சுயவிவரத்தை திருத்து'),
                    onPressed: state.busy || state.hasCall
                        ? null
                        : () => context.push('/edit-profile'),
                    icon: const Icon(Icons.edit_outlined,
                        color: NsColors.muted, size: 19))),
            NightshiftAvatar(
                name: state.user?.name ?? '',
                size: 88,
                avatarCode: state.user?.avatarCode),
            const SizedBox(height: 12),
            Text(state.user?.name ?? '',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: NsColors.violet.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NsColors.violet.withAlpha(65))),
                child: Text(
                    isListener
                        ? state.text('Listener', 'கேட்பவர்')
                        : state.text('Customer', 'வாடிக்கையாளர்'),
                    style: const TextStyle(
                        color: Color(0xFFC4B5FD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF22212A),
                    borderRadius: BorderRadius.circular(17)),
                child: Row(children: [
                  const Icon(Icons.toll_rounded,
                      color: NsColors.gold, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(state.text('TEST WALLET', 'சோதனை பணப்பை'),
                            style: const TextStyle(
                                color: NsColors.muted,
                                fontSize: 10,
                                letterSpacing: .7)),
                        Text(
                            '${creditAmount(state.balance)} ${state.text('test coins', 'சோதனை நாணயங்கள்')}',
                            style: const TextStyle(
                                color: NsColors.gold,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ])),
                  IconButton(
                      tooltip: state.text('Open wallet', 'பணப்பையைத் திற'),
                      onPressed: () => context.push('/wallet'),
                      icon: const Icon(Icons.chevron_right,
                          color: NsColors.gold)),
                ])),
            const SizedBox(height: 7),
            Text(
                state.text(
                    '${creditAmount(state.held)} held for a call · Not cash',
                    'அழைப்பிற்கு ${creditAmount(state.held)} ஒதுக்கப்பட்டது · பணம் அல்ல'),
                style: const TextStyle(color: NsColors.muted, fontSize: 10)),
          ])),
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
            _ProfileMenuRow(
                icon: Icons.account_balance_wallet_outlined,
                title: state.text('Open wallet', 'பணப்பையைத் திற'),
                onTap: () => context.push('/wallet')),
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
                title: state.text(
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
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
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
        trailing: const Icon(Icons.chevron_right, size: 20),
        enabled: onTap != null,
        onTap: onTap,
      );
}
