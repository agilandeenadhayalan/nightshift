import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'design_system.dart';
import 'entry_designs.dart';
import 'commerce_designs.dart';
import 'call_designs.dart';
import 'home_designs.dart';

enum DesignFamily { entry, home, commerce, call }

class NativeDesign {
  const NativeDesign(this.id, this.title, this.family);
  final int id;
  final String title;
  final DesignFamily family;
}

const nativeDesigns = <NativeDesign>[
  NativeDesign(1, 'Splash Screen', DesignFamily.entry),
  NativeDesign(2, 'NetBanking Bank Selection', DesignFamily.commerce),
  NativeDesign(3, 'Pure Onboarding Carousel', DesignFamily.entry),
  NativeDesign(4, 'Add Card (Debit/Credit) — Version 1', DesignFamily.commerce),
  NativeDesign(5, 'Listener Camera Permission Prompt', DesignFamily.entry),
  NativeDesign(6, 'Home Feed (Queue & Instant Match)', DesignFamily.home),
  NativeDesign(
      7, 'Notification Permission Dialog — Version 1', DesignFamily.entry),
  NativeDesign(
      8, 'Listener Nearby Devices Permission Prompt', DesignFamily.entry),
  NativeDesign(
      9, 'Notification Permission Dialog — Version 2', DesignFamily.entry),
  NativeDesign(
      10, 'Listener Earnings & Withdrawal History', DesignFamily.commerce),
  NativeDesign(
      11, 'Feed Loading (Skeleton State) — Version 1', DesignFamily.home),
  NativeDesign(
      12, 'Add Card (Debit/Credit) — Version 2', DesignFamily.commerce),
  NativeDesign(13, 'Listener Audio Permission Prompt', DesignFamily.entry),
  NativeDesign(14, 'Almost Done & Verification Pending', DesignFamily.entry),
  NativeDesign(15, 'Scrollable Wallet & Coin Recharge', DesignFamily.commerce),
  NativeDesign(16, 'Payment Failed', DesignFamily.commerce),
  NativeDesign(17, 'Customer Profile', DesignFamily.home),
  NativeDesign(18, 'Call Rating & Feedback', DesignFamily.call),
  NativeDesign(19, 'Getting Started & Training Video', DesignFamily.entry),
  NativeDesign(20, 'Listener Profile', DesignFamily.home),
  NativeDesign(21, 'Payment Processing', DesignFamily.commerce),
  NativeDesign(22, 'Edit Profile (Listener)', DesignFamily.home),
  NativeDesign(
      23, 'Earn While You Listen (Listener Onboarding)', DesignFamily.entry),
  NativeDesign(
      24, 'Listener Call Logs & Earnings (Listener)', DesignFamily.home),
  NativeDesign(25, 'All Payment Methods (Scrollable)', DesignFamily.commerce),
  NativeDesign(26, 'Community Guidelines & Agreement', DesignFamily.entry),
  NativeDesign(27, 'OTP Verification (Animated Success)', DesignFamily.entry),
  NativeDesign(28, 'Voice Sample Verification', DesignFamily.entry),
  NativeDesign(
      29, 'Listener Audio & Video Dynamic Call Controls', DesignFamily.home),
  NativeDesign(
      30, 'Phone Login with Multi-Number Instant Selector', DesignFamily.entry),
  NativeDesign(31, 'Customer Recent Sessions', DesignFamily.home),
  NativeDesign(
      32, 'Feed Loading (Skeleton State) — Version 2', DesignFamily.home),
  NativeDesign(33, 'Active Ludo Game Board on Call', DesignFamily.call),
  NativeDesign(34, 'Home Feed (Multi-Offer Coin Carousel) — Version 1',
      DesignFamily.home),
  NativeDesign(35, 'Help & Support Category Selection', DesignFamily.commerce),
  NativeDesign(36, 'Live Video Call (Background Feed & Face Censor Box)',
      DesignFamily.call),
  NativeDesign(37, 'Call Conflict & End Call Alert', DesignFamily.call),
  NativeDesign(
      38, 'Listener Video Call (Customer Face Hidden)', DesignFamily.call),
  NativeDesign(39, 'Home Feed (Multi-Offer Coin Carousel) — Version 2',
      DesignFamily.home),
  NativeDesign(
      40, 'Listener Active Ludo Game (Diamond Earnings)', DesignFamily.call),
  NativeDesign(41, 'Home Feed (Instant Match Filter Sheet)', DesignFamily.home),
  NativeDesign(42, 'Nearby Devices Permission Dialog', DesignFamily.entry),
  NativeDesign(43, 'Home with Flat ₹800 Off Offer Sheet', DesignFamily.home),
  NativeDesign(44, 'Home Feed', DesignFamily.home),
  NativeDesign(45, 'Home with Flat ₹2000 Off Offer Sheet', DesignFamily.home),
  NativeDesign(46, 'Listener Video Call (Diamond Earnings)', DesignFamily.call),
  NativeDesign(47, 'Camera & Video Permission Dialog', DesignFamily.entry),
  NativeDesign(48, 'Listener Audio Call (Diamond Earnings)', DesignFamily.call),
  NativeDesign(
      49, 'Listener In-Call Ludo Invite (Listener View)', DesignFamily.call),
  NativeDesign(50, 'Active Audio Call (Centered Companion)', DesignFamily.call),
  NativeDesign(51, 'Live Video Call & Ludo Game Board', DesignFamily.call),
  NativeDesign(
      52, 'Active Two-Way Video Call (Both Faces Visible)', DesignFamily.call),
  NativeDesign(53, 'Camera & Audio Permission Dialog', DesignFamily.entry),
  NativeDesign(54, 'Connecting & Finding Companion', DesignFamily.call),
];
Widget buildNativeDesign(int id) {
  final design = nativeDesigns.firstWhere((d) => d.id == id);
  return switch (design.family) {
    DesignFamily.entry => EntryDesignScreen(designId: id, preview: true),
    DesignFamily.home => HomeDesignScreen(designId: id),
    DesignFamily.commerce => CommerceDesignScreen(designId: id, preview: true),
    DesignFamily.call => CallDesignScreen(designId: id, preview: true),
  };
}

final designSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class DesignCollectionScreen extends ConsumerWidget {
  const DesignCollectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(designSearchProvider).trim().toLowerCase();
    final items = nativeDesigns
        .where((d) =>
            d.title.toLowerCase().contains(search) || '${d.id}' == search)
        .toList();
    return Scaffold(
        appBar: AppBar(title: const Text('54 native Flutter screens')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find a screen'),
                  onChanged: (value) =>
                      ref.read(designSearchProvider.notifier).state = value)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                  'Design review · Sample content and local interactions. Live app flows use your account and server state.',
                  style: TextStyle(color: NsColors.muted, fontSize: 12))),
          const SizedBox(height: 12),
          Expanded(
              child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      mainAxisExtent: 210,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final design = items[index];
                    final icon = switch (design.family) {
                      DesignFamily.entry => Icons.auto_awesome,
                      DesignFamily.home => Icons.home_outlined,
                      DesignFamily.commerce =>
                        Icons.account_balance_wallet_outlined,
                      DesignFamily.call => Icons.call_outlined
                    };
                    return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            onTap: () => context.push('/designs/${design.id}'),
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(design.id.toString().padLeft(2, '0'),
                                          style: const TextStyle(
                                              color: NsColors.cyan)),
                                      const Spacer(),
                                      Icon(icon,
                                          size: 32, color: NsColors.violet),
                                      const Spacer(),
                                      Text(design.title,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ]))));
                  })),
        ]));
  }
}

class DesignReviewScreen extends StatelessWidget {
  const DesignReviewScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) {
    if (id < 1 || id > nativeDesigns.length) {
      return Scaffold(
          appBar: AppBar(title: const Text('Design not found')),
          body: const Center(
              child: Text('Choose a screen from the collection.')));
    }
    return Scaffold(
        appBar: AppBar(
            title: Text('$id / 54 · Design preview',
                style: const TextStyle(fontSize: 14)),
            actions: [
              IconButton(
                  tooltip: 'Previous design',
                  onPressed: id > 1
                      ? () => context.replace('/designs/${id - 1}')
                      : null,
                  icon: const Icon(Icons.chevron_left)),
              IconButton(
                  tooltip: 'Next design',
                  onPressed: id < 54
                      ? () => context.replace('/designs/${id + 1}')
                      : null,
                  icon: const Icon(Icons.chevron_right)),
            ]),
        body: buildNativeDesign(id));
  }
}
