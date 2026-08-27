import 'package:buff_lisa/features/ranking/data/ranking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RankingTimeButton extends ConsumerWidget {
  final String label;
  final int index;

  const RankingTimeButton({
    super.key,
    required this.label,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c1 = Theme.of(context).colorScheme.surfaceContainerHighest; // Color when not selected
    final c2 = Theme.of(context).primaryColor; // Color when selected
    final isSelected =
        ref.watch(rankingTimeSelectorProvider) == index; // Check if selected

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 5, bottom: 5, right: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? c2 : c1,
          minimumSize: Size.zero,
        ),
        onPressed: () {
          ref.read(rankingTimeSelectorProvider.notifier).updateIndex(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Text(
            label,
            style: TextStyle
              (color: isSelected ? c1 : c2, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
