import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/presentation/group_xp_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupXpPanel extends ConsumerWidget {
  const GroupXpPanel({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(groupProgressionProvider(groupId))
        .when(
          data: (xp) =>
              xp == null ? const SizedBox.shrink() : GroupXpCard(xp: xp),
          error: (error, stackTrace) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        );
  }
}
