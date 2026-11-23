import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'design_system.dart';

final _avatarCollectionProvider = StateProvider.autoDispose
    .family<String, String>(
        (ref, selected) => selected.startsWith('female_') ? 'female' : 'male');

Future<String?> showAvatarPicker(BuildContext context,
        {required String selected, bool tamil = false}) =>
    showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AvatarPicker(selected: selected, tamil: tamil));

class _AvatarPicker extends ConsumerWidget {
  const _AvatarPicker({required this.selected, required this.tamil});
  final String selected;
  final bool tamil;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(_avatarCollectionProvider(selected));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(children: [
                Text(
                    tamil
                        ? 'உங்கள் அவதாரத்தை தேர்ந்தெடுக்கவும்'
                        : 'Find your look',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                    tamil
                        ? 'எந்த தோற்றத்தையும் தேர்ந்தெடுக்கலாம்'
                        : 'Choose any appearance you like.',
                    style:
                        const TextStyle(color: NsColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final code in ['moon', 'star', 'leaf', 'wave'])
                    InkWell(
                        key: ValueKey('avatar-choice-$code'),
                        borderRadius: BorderRadius.circular(32),
                        onTap: () => Navigator.pop(context, code),
                        child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: NightshiftAvatar(
                                name: code, avatarCode: code, size: 48))),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 10, children: [
                  for (final group in ['male', 'female'])
                    ChoiceChip(
                        selected: collection == group,
                        label: Text(group == 'male'
                            ? (tamil ? 'ஆண் அவதாரங்கள்' : 'Male avatars')
                            : (tamil ? 'பெண் அவதாரங்கள்' : 'Female avatars')),
                        onSelected: (_) => ref
                            .read(_avatarCollectionProvider(selected).notifier)
                            .state = group),
                ]),
              ])),
          Expanded(
              child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .82),
            itemCount: 30,
            itemBuilder: (context, index) {
              final code =
                  '${collection}_${(index + 1).toString().padLeft(2, '0')}';
              return Semantics(
                button: true,
                selected: code == selected,
                label:
                    '${collection == 'male' ? 'Male' : 'Female'} avatar ${index + 1}',
                child: InkWell(
                    key: ValueKey('avatar-choice-$code'),
                    onTap: () => Navigator.pop(context, code),
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(fit: StackFit.expand, children: [
                      AvatarPortrait(
                          assetPath: avatarAssetPath(code)!,
                          borderRadius: BorderRadius.circular(18)),
                      if (code == selected)
                        Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: NsColors.violet,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 18))),
                    ])),
              );
            },
          )),
        ]),
      ),
    );
  }
}
