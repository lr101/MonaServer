import 'package:buff_lisa/features/ranking/data/ranking_state.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surfaceContainerHighest;
    final primary = colorScheme.primary;
    final isSelected =
        ref.watch(rankingTimeSelectorProvider) == index; // Check if selected

    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 5, bottom: 5, right: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? primary : surface,
          minimumSize: Size.zero,
        ),
        onPressed: () {
          ref.read(rankingTimeSelectorProvider.notifier).updateIndex(index);
        },
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.primaryOnSurface,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
