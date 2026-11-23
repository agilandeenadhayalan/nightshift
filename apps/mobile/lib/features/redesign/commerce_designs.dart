import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/controller.dart';
import '../../core/models.dart';
import 'design_system.dart';

/// Draft presentation choices only. No card details, payment result, balance,
/// payout, or support submission is stored in this feature state.
@immutable
class CommerceDesignState {
  const CommerceDesignState({
    this.bankQuery = '',
    this.bank,
    this.pack = 4,
    this.method = 'Any UPI app',
    this.supportCategory,
  });

  final String bankQuery;
  final String? bank;
  final int pack;
  final String method;
  final String? supportCategory;

  CommerceDesignState copyWith({
    String? bankQuery,
    String? bank,
    int? pack,
    String? method,
    String? supportCategory,
  }) =>
      CommerceDesignState(
        bankQuery: bankQuery ?? this.bankQuery,
        bank: bank ?? this.bank,
        pack: pack ?? this.pack,
        method: method ?? this.method,
        supportCategory: supportCategory ?? this.supportCategory,
      );
}

class CommerceDesignController extends StateNotifier<CommerceDesignState> {
  CommerceDesignController() : super(const CommerceDesignState());
  void searchBanks(String value) => state = state.copyWith(bankQuery: value);
  void selectBank(String value) => state = state.copyWith(bank: value);
  void selectPack(int value) {
    if (value >= 0 && value < _packs.length) {
      state = state.copyWith(pack: value);
    }
  }

  void selectMethod(String value) => state = state.copyWith(method: value);
  void selectSupport(String value) =>
      state = state.copyWith(supportCategory: value);
}

/// The caller keys this by (accountIdentity, preview). Session changes therefore
/// cannot retain another account's choices; preview never shares live drafts.
final commerceDesignProvider = StateNotifierProvider.autoDispose
    .family<CommerceDesignController, CommerceDesignState, Object>(
  (ref, owner) => CommerceDesignController(),
);

const _packs = <({int coins, int price, int? previous, String? badge})>[
  (coins: 80, price: 62, previous: null, badge: null),
  (coins: 300, price: 149, previous: null, badge: null),
  (coins: 450, price: 251, previous: null, badge: null),
  (coins: 1100, price: 550, previous: null, badge: 'Hot'),
  (coins: 1800, price: 1055, previous: null, badge: null),
  (coins: 3500, price: 1049, previous: 1549, badge: '₹500 off'),
  (coins: 5000, price: 1999, previous: null, badge: 'Hot'),
  (coins: 9000, price: 2651, previous: 3251, badge: '₹600 off'),
  (coins: 20000, price: 4500, previous: 8000, badge: 'Value pack'),
  (coins: 26000, price: 9999, previous: null, badge: null),
  (coins: 55000, price: 17999, previous: null, badge: null),
  (coins: 90000, price: 28999, previous: null, badge: null),
];

const _banks = <({String name, String mark, Color color})>[
  (name: 'AU Small Finance Bank', mark: 'AU', color: Color(0xff663399)),
  (name: 'Bandhan Bank', mark: 'B', color: Color(0xffb62036)),
  (name: 'Bank of India', mark: 'BOI', color: Color(0xff1374ad)),
  (name: 'Bank of Maharashtra', mark: 'M', color: Color(0xff1274b5)),
  (name: 'Canara Bank', mark: 'C', color: Color(0xff0594c6)),
  (name: 'Central Bank Of India', mark: 'CB', color: Color(0xff2276ad)),
  (name: 'State Bank of India', mark: 'SBI', color: Color(0xff16a5dc)),
  (name: 'HDFC Bank', mark: 'HDFC', color: Color(0xff173e81)),
  (name: 'ICICI Bank', mark: 'i', color: Color(0xffba431d)),
  (name: 'Axis Bank', mark: 'A', color: Color(0xff91244e)),
  (name: 'Kotak Mahindra Bank', mark: 'K', color: Color(0xffdf2639)),
  (name: 'Punjab National Bank', mark: 'PNB', color: Color(0xffa22137)),
];

String _group(int value) => '$value'.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

class CommerceDesignScreen extends ConsumerWidget {
  const CommerceDesignScreen({
    super.key,
    required this.designId,
    this.preview = false,
  });

  final int designId;
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final owner = (app.accountIdentity, preview);
    final draft = ref.watch(commerceDesignProvider(owner));
    final actions = ref.read(commerceDesignProvider(owner).notifier);
    final light = [2, 4, 12, 25].contains(designId);
    return _CommerceLocale(
      tamil: !preview && app.locale == 'ta',
      child: Theme(
        data: nightshiftTheme(light: light),
        child: KeyedSubtree(
          key: ValueKey(owner),
          child: Builder(builder: (context) {
            return switch (designId) {
              2 => _banksScreen(context, draft, actions),
              4 || 12 => _cardScreen(context),
              10 => _earningsScreen(context, app),
              15 => _walletScreen(context, app, draft, actions),
              16 || 21 => _statusScreen(context),
              25 => _methodsScreen(context, draft, actions),
              35 => _supportScreen(context, draft, actions),
              _ => throw ArgumentError.value(designId, 'designId'),
            };
          }),
        ),
      ),
    );
  }

  void _open(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommerceDesignScreen(designId: id, preview: preview),
    ));
  }

  Widget _frame(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
    Widget? bottom,
    bool light = false,
  }) =>
      Scaffold(
        backgroundColor: light ? const Color(0xfff8f9fb) : NsColors.background,
        appBar: AppBar(
          toolbarHeight:
              MediaQuery.textScalerOf(context).scale(21) > 30 ? 112 : 56,
          title: _CommerceText(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          centerTitle: false,
          backgroundColor: light ? Colors.white : NsColors.background,
          actions: [if (trailing != null) trailing, const SizedBox(width: 16)],
        ),
        body: SafeArea(
          top: false,
          bottom: bottom == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(children: [
                if (preview) _previewNotice(light: light),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: BoxDecoration(
                    color: light ? Colors.white : NsColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: light ? const Color(0xffeceef2) : Colors.white12,
                      ),
                    ),
                  ),
                  child: bottom,
                ),
              ),
      );

  Widget _previewNotice({bool light = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        color: light ? const Color(0xffeee8ff) : const Color(0xff271d43),
        child: _CommerceText(
          'DESIGN PREVIEW · Sample amounts · No transactions',
          style: TextStyle(
            color: light ? const Color(0xff5c24b8) : const Color(0xffddd0ff),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _unavailable(String message, {bool light = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: light ? const Color(0xfff1edfa) : NsColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: light ? const Color(0xffe8dff6) : Colors.white10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: light ? const Color(0xff7947ea) : NsColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: _CommerceText(message,
                style: TextStyle(
                    height: 1.45,
                    fontSize: 12,
                    color: light ? const Color(0xff5d5372) : NsColors.muted)),
          ),
        ]),
      );

  Widget _disabledPayment({String label = 'Payments not configured'}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('commerce-disabled-payment'),
          onPressed: null,
          icon: const Icon(Icons.lock_outline_rounded, size: 18),
          label: _CommerceText(label),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            disabledBackgroundColor: NsColors.violet.withValues(alpha: .18),
            disabledForegroundColor: NsColors.violet,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _walletScreen(BuildContext context, AppController app,
      CommerceDesignState draft, CommerceDesignController actions) {
    final balance = preview ? '133' : creditAmount(app.balance);
    final selected = _packs[draft.pack];
    return _frame(
      context,
      title: 'Wallet',
      trailing: _coinBadge(preview || app.snapshotLoaded ? balance : '—'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          if (!preview) ...[
            _balanceCard(app),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff0e372c), Color(0xff174438)],
              ),
              border: Border.all(color: const Color(0xff365f3e)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommerceText(
                        preview ? 'Flat ₹3000 off' : 'More conversations',
                        style: const TextStyle(
                            color: NsColors.gold,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _CommerceText(
                        preview ? '12,500 coins' : 'Your night, your pace.',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (preview)
                      const Wrap(spacing: 10, children: [
                        _CommerceText('₹6,000',
                            style: TextStyle(
                                color: Colors.white54,
                                decoration: TextDecoration.lineThrough)),
                        _CommerceText('₹3,000',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ])
                    else
                      const _CommerceText('Recharge will be available here.',
                          style: TextStyle(
                              color: Color(0xffa7c9b8), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _CoinArt(size: 62),
            ]),
          ),
          const SizedBox(height: 22),
          _CommerceText(
              preview ? 'Choose your coin pack' : 'Coin pack previews',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (!preview) ...[
            const SizedBox(height: 8),
            const _CommerceText(
              'Sample pack sizes. Prices and purchases are unavailable.',
              style: TextStyle(color: NsColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
            final count = constraints.maxWidth < 340 || largeText ? 2 : 3;
            // Let the tallest pack determine each row's height. Fixed grid
            // extents clip discounted prices and accessibility-sized text.
            return Column(children: [
              for (var start = 0; start < _packs.length; start += count)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var offset = 0; offset < count; offset++) ...[
                          if (offset > 0) const SizedBox(width: 10),
                          Expanded(
                            child: start + offset < _packs.length
                                ? _packCard(
                                    context,
                                    start + offset,
                                    selected: draft.pack == start + offset,
                                    onTap: () =>
                                        actions.selectPack(start + offset),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 22),
          _unavailable(preview
              ? 'Sample offers are for visual review. No money is collected.'
              : 'Test coins are not money and cannot be redeemed or transferred. Recharge is not configured.'),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => _open(context, 25),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const _CommerceText('View payment methods'),
          ),
        ],
      ),
      bottom: LayoutBuilder(builder: (context, constraints) {
        final summary = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CommerceText('Selected pack',
                  style: TextStyle(color: NsColors.muted, fontSize: 11)),
              const SizedBox(height: 4),
              if (preview)
                _CommerceText('₹${_group(selected.price)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              _CommerceText(
                  '${_group(selected.coins)} ${preview ? 'coins' : 'sample coins'}',
                  style: const TextStyle(color: NsColors.muted, fontSize: 11)),
            ]);
        final action = _disabledPayment(label: 'Recharge unavailable');
        if (MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 12), action],
          );
        }
        return Row(children: [
          Expanded(child: summary),
          const SizedBox(width: 12),
          Flexible(child: action),
        ]);
      }),
    );
  }

  Widget _balanceCard(AppController app) => NightshiftSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CommerceText('TEST WALLET',
              style: TextStyle(
                  color: NsColors.muted,
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const _CoinArt(size: 36),
            const SizedBox(width: 12),
            _CommerceText(app.snapshotLoaded ? creditAmount(app.balance) : '—',
                key: const Key('commerce-wallet-balance'),
                style:
                    const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const _CommerceText('test coins',
                style: TextStyle(color: NsColors.muted)),
          ]),
          const SizedBox(height: 14),
          _CommerceText(
            app.snapshotLoaded
                ? '${creditAmount(app.held)} held for a call'
                : 'Balance has not loaded yet.',
            key: const Key('commerce-wallet-held'),
            style: const TextStyle(color: NsColors.muted, fontSize: 12),
          ),
          if (app.offline)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _CommerceText(
                  'Offline · showing the last available balance',
                  style: TextStyle(color: NsColors.gold, fontSize: 12)),
            ),
          if (!app.snapshotLoaded && app.user != null)
            TextButton(
              onPressed: app.busy || app.snapshotLoading ? null : app.refresh,
              child: const _CommerceText('Refresh balance'),
            ),
        ]),
      );

  Widget _packCard(BuildContext context, int index,
      {required bool selected, required VoidCallback onTap}) {
    final pack = _packs[index];
    return Material(
      color: selected ? const Color(0xff332b1c) : NsColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('commerce-pack-$index'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Semantics(
          selected: selected,
          label: _commerceCopy(
              context, '${pack.coins} ${preview ? 'coins' : 'sample coins'}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 10, 7, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? NsColors.gold : Colors.white10,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(selected ? Icons.check_circle : Icons.auto_awesome,
                    size: 13,
                    color: selected ? NsColors.gold : const Color(0xff6c5940)),
              ]),
              const _CoinArt(size: 26),
              const SizedBox(height: 5),
              _CommerceText(_group(pack.coins),
                  style: const TextStyle(
                      color: NsColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              if (preview)
                _CommerceText('₹${_group(pack.price)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700))
              else
                const _CommerceText('Not for sale',
                    style: TextStyle(color: NsColors.muted, fontSize: 11)),
              if (preview && pack.previous != null)
                _CommerceText('₹${_group(pack.previous!)}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: NsColors.muted,
                        decoration: TextDecoration.lineThrough)),
              if (preview && pack.badge != null)
                _CommerceText(pack.badge!,
                    style: const TextStyle(
                        color: NsColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _coinBadge(String amount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: NsColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.monetization_on_rounded,
              size: 18, color: NsColors.gold),
          const SizedBox(width: 7),
          _CommerceText(amount,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      );

  Widget _banksScreen(BuildContext context, CommerceDesignState draft,
      CommerceDesignController actions) {
    final banks = _banks.where((bank) =>
        bank.name.toLowerCase().contains(draft.bankQuery.trim().toLowerCase()));
    return _frame(
      context,
      title: 'NetBanking',
      light: true,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            key: const Key('commerce-bank-search'),
            initialValue: draft.bankQuery,
            onChanged: actions.searchBanks,
            decoration: InputDecoration(
              hintText: _commerceCopy(context, 'Search your bank'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xffe2e8f0)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffeceef2)),
            ),
            child: Column(children: [
              for (final bank in banks)
                _choiceRow(
                  key: Key('commerce-bank-${bank.name}'),
                  mark: bank.mark,
                  markColor: bank.color,
                  title: bank.name,
                  selected: bank.name == draft.bank,
                  onTap: () => actions.selectBank(bank.name),
                ),
              if (banks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: _CommerceText('No matching banks. Try another name.'),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          _unavailable(
              'Bank selection is a preview. Bank payments are not configured.',
              light: true),
        ],
      ),
      bottom: _disabledPayment(),
    );
  }

  Widget _choiceRow({
    Key? key,
    required String mark,
    required Color markColor,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      ListTile(
        key: key,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: markColor.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _CommerceText(mark,
              style: TextStyle(
                  color: markColor,
                  fontSize: mark.length > 2 ? 11 : 20,
                  fontWeight: FontWeight.w800)),
        ),
        title: _CommerceText(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : _CommerceText(subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xff8c8998))),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xff7947ea) : const Color(0xffbcb4ca),
          size: 22,
        ),
        selected: selected,
        selectedTileColor: const Color(0xfff6f2ff),
        onTap: onTap,
      );

  Widget _methodsScreen(BuildContext context, CommerceDesignState draft,
          CommerceDesignController actions) =>
      _frame(
        context,
        title: 'Payment Methods',
        light: true,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
                color: const Color(0xfff0eafb),
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: Color(0xff7947ea), size: 24),
              const SizedBox(width: 12),
              const Expanded(child: _CommerceText('To Pay')),
              _CommerceText(preview ? '₹62' : '—',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('UPI Apps', light: true),
          const SizedBox(height: 10),
          _whiteCard(Column(children: [
            for (final method in const [
              ('Any UPI app', 'UPI', Color(0xff266454)),
              ('GPay', 'G', Color(0xff4285f4)),
              ('Paytm', 'pay', Color(0xff009cce)),
              ('iMobile', 'i', Color(0xffe46c19)),
            ])
              _choiceRow(
                key: Key('commerce-method-${method.$1}'),
                title: method.$1 == 'Any UPI app'
                    ? 'Pay by Any UPI app'
                    : method.$1,
                subtitle: method.$1 == 'Any UPI app'
                    ? 'Use any UPI app on your phone to pay'
                    : null,
                mark: method.$2,
                markColor: method.$3,
                selected: draft.method == method.$1,
                onTap: () => actions.selectMethod(method.$1),
              ),
          ])),
          const SizedBox(height: 22),
          const _SectionLabel('Cards', light: true),
          const SizedBox(height: 10),
          _whiteCard(ListTile(
            leading: const Icon(Icons.credit_card_outlined,
                color: Color(0xff7947ea)),
            title: const _CommerceText('Debit / Credit Card'),
            subtitle: const _CommerceText('View card payment layout',
                style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _open(context, 4),
          )),
          const SizedBox(height: 22),
          const _SectionLabel('Net Banking', light: true),
          const SizedBox(height: 10),
          _whiteCard(Column(children: [
            ListTile(
              leading: const Icon(Icons.account_balance_outlined,
                  color: Color(0xff7947ea)),
              title: const _CommerceText('Net Banking'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(context, 2),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CommerceText('Popular Banks',
                        style:
                            TextStyle(color: Color(0xff8c8998), fontSize: 12)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final name in [
                        'HDFC Bank',
                        'ICICI Bank',
                        'SBI',
                        'Axis Bank'
                      ])
                        ActionChip(
                          label: _CommerceText(name,
                              style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            actions.selectBank(
                                name == 'SBI' ? 'State Bank of India' : name);
                            _open(context, 2);
                          },
                        ),
                    ]),
                  ]),
            ),
          ])),
          const SizedBox(height: 20),
          _unavailable(
              'Payments are not configured. No bank or UPI app will be opened.',
              light: true),
        ]),
        bottom: _disabledPayment(),
      );

  Widget _whiteCard(Widget child) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffeceef2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );

  Widget _cardScreen(BuildContext context) => _frame(
        context,
        title: 'Add Card',
        light: true,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          _whiteCard(Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionLabel('Card Number', light: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _cardPlaceholder(context, 'Enter Card Number',
                        focused: true)),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 54,
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffd1d0d8)),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.contactless_outlined,
                      color: Color(0xff9995a3)),
                ),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const _SectionLabel('Expiry', light: true),
                      const SizedBox(height: 10),
                      _cardPlaceholder(context, 'MM/YY'),
                    ])),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const _SectionLabel('CVV', light: true),
                      const SizedBox(height: 10),
                      _cardPlaceholder(context, 'CVV', help: true),
                    ])),
              ]),
              const SizedBox(height: 20),
              const Row(children: [
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: Color(0xff8c8998)),
                SizedBox(width: 6),
                Expanded(
                    child: _CommerceText('Card entry is disabled',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xff8c8998)))),
              ]),
            ]),
          )),
          const SizedBox(height: 18),
          _unavailable(
            'Card payments are not configured. Do not enter card details; this screen does not collect or save card numbers or CVV.',
            light: true,
          ),
          const SizedBox(height: 32),
          if (preview) _previewKeypad(),
        ]),
        bottom: _disabledPayment(),
      );

  // Deliberately plain display widgets, not editable fields or a card form.
  Widget _cardPlaceholder(BuildContext context, String text,
          {bool focused = false, bool help = false}) =>
      Semantics(
        enabled: false,
        label:
            '${_commerceCopy(context, text)}, ${_commerceCopy(context, 'Unavailable')}',
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    focused ? const Color(0xff7c3aed) : const Color(0xffd1d0d8),
                width: focused ? 1.5 : 1),
          ),
          child: Row(children: [
            Expanded(
                child: _CommerceText(text,
                    style: const TextStyle(
                        color: Color(0xffa09ba9), fontSize: 13))),
            if (help)
              const Icon(Icons.help_outline,
                  size: 18, color: Color(0xffaaa6af)),
          ]),
        ),
      );

  Widget _previewKeypad() => ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: designId == 4
                ? const Color(0xfff0de42)
                : const Color(0xfff4e04d),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            for (final row in const [
              ['1', '2  ABC', '3  DEF'],
              ['4  GHI', '5  JKL', '6  MNO'],
              ['7  PQRS', '8  TUV', '9  WXYZ'],
              ['*+#', '0  +', '⌫'],
            ])
              Row(children: [
                for (final value in row)
                  Expanded(
                      child: Container(
                    height: 47,
                    margin: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(8)),
                    child: _CommerceText(value,
                        style: const TextStyle(
                            color: Color(0xff272322), fontSize: 18)),
                  )),
              ]),
          ]),
        ),
      );

  Widget _earningsScreen(BuildContext context, AppController app) {
    final calls = app.history
        .where((call) => call.listenerId == app.user?.id && call.ended);
    final earnings = calls.fold<int>(0, (sum, call) => sum + call.earningPaise);
    return _frame(
      context,
      title: 'Earnings',
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xff35205b), Color(0xff211a3c)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: NsColors.violet.withValues(alpha: .3)),
          ),
          child: Column(children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 30, color: Color(0xffc9aaff)),
            const SizedBox(height: 14),
            _CommerceText(
                preview
                    ? 'Current balance · sample'
                    : 'Test earnings in loaded history',
                style: const TextStyle(color: Color(0xffbfb0d7), fontSize: 13)),
            const SizedBox(height: 10),
            _CommerceText(
                preview
                    ? '₹20.35'
                    : app.historyLoaded
                        ? '₹${(earnings / 100).toStringAsFixed(2)}'
                        : '—',
                key: const Key('commerce-test-earnings'),
                style:
                    const TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const _CommerceText('Cash withdrawals are not available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffbfb0d7), fontSize: 12)),
            const SizedBox(height: 20),
            _disabledPayment(label: 'Withdrawals not configured'),
          ]),
        ),
        const SizedBox(height: 28),
        const _SectionLabel('Withdrawal History'),
        const SizedBox(height: 14),
        if (preview)
          for (final entry in const [
            ('19 May 2025 at 12:39pm', '63.00'),
            ('11 May 2025 at 2:28am', '103.00'),
            ('01 May 2025 at 5:53pm', '71.00'),
            ('24 Apr 2025 at 3:12pm', '55.93'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NightshiftSurface(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        _CommerceText(entry.$1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 7),
                        const _CommerceText('Sample withdrawal',
                            style:
                                TextStyle(color: NsColors.muted, fontSize: 11)),
                      ])),
                  _CommerceText('₹${entry.$2}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
              ),
            )
        else ...[
          _unavailable(
              'There are no cash withdrawals in this test app. Test earnings are not redeemable.'),
          const SizedBox(height: 24),
          const _SectionLabel('Test call earnings'),
          const SizedBox(height: 12),
          if (app.historyLoading)
            const LinearProgressIndicator()
          else if (!app.historyLoaded || app.historyError != null)
            OutlinedButton.icon(
              onPressed: app.user == null ? null : app.loadHistory,
              icon: const Icon(Icons.refresh),
              label: _CommerceText(app.historyError != null
                  ? 'Retry call history'
                  : 'Load call history'),
            )
          else if (calls.isEmpty)
            const _CommerceText('No completed Listener calls yet.',
                style: TextStyle(color: NsColors.muted)),
          for (final call in calls)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.call_outlined, color: NsColors.cyan),
              title: _CommerceText(call.customerName),
              subtitle: _CommerceText(
                  'Test settlement · ${durationLabel(call.connectedMs)}'),
              trailing: _CommerceText(
                  '₹${(call.earningPaise / 100).toStringAsFixed(2)}'),
            ),
        ],
      ]),
    );
  }

  Widget _statusScreen(BuildContext context) {
    final processing = designId == 21;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff7228e2), Color(0xff44197e), Color(0xff200845)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Align(
                alignment: Alignment.centerLeft,
                child:
                    BackButton(onPressed: () => Navigator.maybePop(context))),
            if (preview) _previewNotice(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .07),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.purpleAccent
                                      .withValues(alpha: .15),
                                  blurRadius: 46)
                            ],
                          ),
                          child: processing && preview
                              ? const CircularProgressIndicator(
                                  value: .76,
                                  strokeWidth: 8,
                                  color: Color(0xffd5a8ff))
                              : Icon(
                                  preview
                                      ? Icons.close_rounded
                                      : Icons.lock_outline_rounded,
                                  color: const Color(0xffe7cfff),
                                  size: 64),
                        ),
                        const SizedBox(height: 34),
                        _CommerceText(
                            preview
                                ? processing
                                    ? 'Payment Processing…'
                                    : 'Payment Failed'
                                : processing
                                    ? 'No payment in progress'
                                    : 'Payments unavailable',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        _CommerceText(
                            preview
                                ? 'Sample payment status. No transaction was attempted.'
                                : 'Payments are not configured. No charge has been made by this screen.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xffd7c0f8),
                                fontSize: 14,
                                height: 1.6)),
                        const SizedBox(height: 36),
                        TextButton(
                          onPressed: () => _open(context, 35),
                          child: const _CommerceText(
                              'Need help? Visit Help & Support',
                              style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.underline)),
                        ),
                      ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _open(context, 15),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(52)),
                    child: const _CommerceText('Back to wallet'),
                  )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _supportScreen(BuildContext context, CommerceDesignState draft,
          CommerceDesignController actions) =>
      _frame(
        context,
        title: 'Help & Support',
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const SizedBox(height: 18),
          const Icon(Icons.nightlight_round, size: 44, color: NsColors.violet),
          const SizedBox(height: 24),
          const _CommerceText('How can we help?',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const _CommerceText('Please select a category',
              style: TextStyle(color: NsColors.muted, fontSize: 14)),
          const SizedBox(height: 26),
          for (final category in const [
            (
              'Session Support',
              'Regarding Audio and Video Calls',
              Icons.headset_mic_outlined
            ),
            (
              'Payment Support',
              'Regarding Wallet and Payments',
              Icons.account_balance_wallet_outlined
            ),
            (
              'Other',
              'Any other queries or issues',
              Icons.chat_bubble_outline_rounded
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Material(
                color: draft.supportCategory == category.$1
                    ? const Color(0xff29213e)
                    : NsColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                      color: draft.supportCategory == category.$1
                          ? NsColors.violet
                          : Colors.white10),
                ),
                child: ListTile(
                  key: Key('commerce-support-${category.$1}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: NsColors.violet.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(category.$3, color: const Color(0xffbca1ff)),
                  ),
                  title: _CommerceText(category.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _CommerceText(category.$2,
                        style: const TextStyle(
                            fontSize: 11, color: NsColors.muted)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: NsColors.muted),
                  onTap: () => actions.selectSupport(category.$1),
                ),
              ),
            ),
          if (draft.supportCategory != null) ...[
            const SizedBox(height: 12),
            _unavailable(
                '${draft.supportCategory} selected. Support ticket submission is not configured. No request has been sent.'),
            const SizedBox(height: 16),
            _disabledPayment(label: 'Support submission unavailable'),
          ],
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.light = false});
  final String text;
  final bool light;
  @override
  Widget build(BuildContext context) => _CommerceText(text,
      style: TextStyle(
          color: light ? const Color(0xff252232) : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16));
}

class _CoinArt extends StatelessWidget {
  const _CoinArt({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffffe49a), Color(0xfff8b825), Color(0xffad650a)],
          ),
          border: Border.all(color: const Color(0xffffd96c), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33f8b825), blurRadius: 12)
          ],
        ),
        child: Icon(Icons.star_rounded,
            size: size * .65, color: const Color(0xffaa650b)),
      );
}

/// Live copy follows the account locale; the source design review intentionally
/// keeps its original English labels. Draft values remain language independent.
class _CommerceLocale extends InheritedWidget {
  const _CommerceLocale({required this.tamil, required super.child});
  final bool tamil;
  @override
  bool updateShouldNotify(_CommerceLocale oldWidget) =>
      tamil != oldWidget.tamil;
}

String _commerceCopy(BuildContext context, String value) {
  if (context.dependOnInheritedWidgetOfExactType<_CommerceLocale>()?.tamil !=
      true) {
    return value;
  }
  final direct = _commerceTamil[value];
  if (direct != null) return direct;
  if (value.endsWith(' held for a call')) {
    return '${value.replaceFirst(' held for a call', '')} அழைப்பிற்காக ஒதுக்கப்பட்டது';
  }
  if (value.endsWith(' sample coins')) {
    return '${value.replaceFirst(' sample coins', '')} மாதிரி நாணயங்கள்';
  }
  if (value.startsWith('Test settlement · ')) {
    return value.replaceFirst('Test settlement · ', 'சோதனைத் தீர்வு · ');
  }
  const supportSuffix =
      ' selected. Support ticket submission is not configured. No request has been sent.';
  if (value.endsWith(supportSuffix)) {
    final category = value.substring(0, value.length - supportSuffix.length);
    return '${_commerceTamil[category] ?? category} தேர்ந்தெடுக்கப்பட்டது. உதவி கோரிக்கை அனுப்பும் வசதி அமைக்கப்படவில்லை. எந்தக் கோரிக்கையும் அனுப்பப்படவில்லை.';
  }
  return value;
}

const _commerceTamil = <String, String>{
  'Wallet': 'பணப்பை',
  'Earnings': 'வருமானம்',
  'Help & Support': 'உதவி மற்றும் ஆதரவு',
  'NetBanking': 'இணைய வங்கி',
  'Net Banking': 'இணைய வங்கி',
  'Payment Methods': 'பணம் செலுத்தும் முறைகள்',
  'Add Card': 'அட்டை சேர்க்கவும்',
  'Payments not configured': 'பணம் செலுத்தும் வசதி அமைக்கப்படவில்லை',
  'More conversations': 'மேலும் உரையாடல்கள்',
  'Your night, your pace.': 'உங்கள் இரவு. உங்கள் விருப்பம்.',
  'Recharge will be available here.': 'ரீசார்ஜ் வசதி இன்னும் கிடைக்கவில்லை.',
  'Coin pack previews': 'நாணயத் தொகுப்புகளின் மாதிரி',
  'Sample pack sizes. Prices and purchases are unavailable.':
      'மாதிரி தொகுப்புகள். விலையும் வாங்கும் வசதியும் இன்னும் இல்லை.',
  'Test coins are not money and cannot be redeemed or transferred. Recharge is not configured.':
      'சோதனை நாணயங்கள் பணம் அல்ல. அவற்றை பணமாக மாற்றவோ பரிமாறவோ முடியாது. ரீசார்ஜ் வசதி அமைக்கப்படவில்லை.',
  'View payment methods': 'பணம் செலுத்தும் முறைகளைப் பார்',
  'Selected pack': 'தேர்ந்தெடுத்த தொகுப்பு',
  'Unavailable': 'கிடைக்கவில்லை',
  'Recharge unavailable': 'ரீசார்ஜ் கிடைக்கவில்லை',
  'TEST WALLET': 'சோதனை பணப்பை',
  'test coins': 'சோதனை நாணயங்கள்',
  'Balance has not loaded yet.': 'இருப்பு இன்னும் ஏற்றப்படவில்லை.',
  'Offline · showing the last available balance':
      'இணைப்பு இல்லை · கடைசியாகக் கிடைத்த இருப்பு காட்டப்படுகிறது',
  'Refresh balance': 'இருப்பைப் புதுப்பி',
  'Not for sale': 'விற்பனைக்கு இல்லை',
  'Search your bank': 'உங்கள் வங்கியைத் தேடுங்கள்',
  'No matching banks. Try another name.':
      'பொருந்தும் வங்கிகள் இல்லை. வேறு பெயரை முயற்சிக்கவும்.',
  'Bank selection is a preview. Bank payments are not configured.':
      'வங்கித் தேர்வு ஒரு மாதிரி மட்டுமே. வங்கி மூலம் பணம் செலுத்தும் வசதி அமைக்கப்படவில்லை.',
  'To Pay': 'செலுத்த வேண்டியது',
  'UPI Apps': 'UPI செயலிகள்',
  'Pay by Any UPI app': 'எந்த UPI செயலியிலும் செலுத்தலாம்',
  'Use any UPI app on your phone to pay':
      'உங்கள் போனில் உள்ள UPI செயலியைப் பயன்படுத்தலாம்',
  'Cards': 'அட்டைகள்',
  'Debit / Credit Card': 'டெபிட் / கிரெடிட் அட்டை',
  'View card payment layout': 'அட்டை மூலம் செலுத்தும் மாதிரியைப் பார்',
  'Popular Banks': 'பிரபல வங்கிகள்',
  'Payments are not configured. No bank or UPI app will be opened.':
      'பணம் செலுத்தும் வசதி அமைக்கப்படவில்லை. வங்கி அல்லது UPI செயலி திறக்கப்படாது.',
  'Card Number': 'அட்டை எண்',
  'Enter Card Number': 'அட்டை எண்ணை உள்ளிடவும்',
  'Expiry': 'காலாவதி தேதி',
  'Card entry is disabled': 'அட்டை விவரங்களை உள்ளிட இயலாது',
  'Card payments are not configured. Do not enter card details; this screen does not collect or save card numbers or CVV.':
      'அட்டை மூலம் பணம் செலுத்தும் வசதி அமைக்கப்படவில்லை. அட்டை விவரங்களை உள்ளிட வேண்டாம்; இந்தத் திரை அட்டை எண்ணையோ CVV-யையோ சேகரிப்பதில்லை, சேமிப்பதில்லை.',
  'Test earnings in loaded history': 'ஏற்றப்பட்ட வரலாற்றின் சோதனை வருமானம்',
  'Cash withdrawals are not available': 'பணம் எடுக்கும் வசதி இல்லை',
  'Withdrawals not configured': 'பணம் எடுக்கும் வசதி அமைக்கப்படவில்லை',
  'Withdrawal History': 'பணம் எடுத்த வரலாறு',
  'There are no cash withdrawals in this test app. Test earnings are not redeemable.':
      'இந்தச் சோதனை செயலியில் பணம் எடுக்க இயலாது. சோதனை வருமானத்தைப் பணமாக மாற்ற முடியாது.',
  'Test call earnings': 'சோதனை அழைப்பு வருமானம்',
  'Retry call history': 'அழைப்பு வரலாற்றை மீண்டும் ஏற்று',
  'Load call history': 'அழைப்பு வரலாற்றை ஏற்று',
  'No completed Listener calls yet.':
      'முடிந்த கேட்பவர் அழைப்புகள் இன்னும் இல்லை.',
  'No payment in progress': 'பணம் செலுத்தும் செயல் எதுவும் நடைபெறவில்லை',
  'Payments unavailable': 'பணம் செலுத்த இயலாது',
  'Payments are not configured. No charge has been made by this screen.':
      'பணம் செலுத்தும் வசதி அமைக்கப்படவில்லை. இந்தத் திரை எந்தக் கட்டணத்தையும் வசூலிக்கவில்லை.',
  'Need help? Visit Help & Support':
      'உதவி தேவையா? உதவி மற்றும் ஆதரவைப் பாருங்கள்',
  'Back to wallet': 'பணப்பைக்குத் திரும்பு',
  'How can we help?': 'எப்படி உதவலாம்?',
  'Please select a category': 'ஒரு வகையைத் தேர்ந்தெடுக்கவும்',
  'Session Support': 'அழைப்பு உதவி',
  'Regarding Audio and Video Calls': 'ஆடியோ மற்றும் வீடியோ அழைப்புகள் தொடர்பாக',
  'Payment Support': 'பணப்பரிவர்த்தனை உதவி',
  'Regarding Wallet and Payments': 'பணப்பை மற்றும் பணம் செலுத்துதல் தொடர்பாக',
  'Other': 'மற்றவை',
  'Any other queries or issues': 'வேறு கேள்விகள் அல்லது சிக்கல்கள்',
  'Support submission unavailable': 'உதவி கோரிக்கை அனுப்ப இயலாது',
};

class _CommerceText extends StatelessWidget {
  const _CommerceText(this.data,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) => Text(_commerceCopy(context, data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow);
}
