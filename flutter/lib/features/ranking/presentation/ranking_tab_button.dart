import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:flutter/material.dart';

class RankingTabButton extends StatelessWidget {
  final String label;
  final int index;
  final TabController tabController;

  const RankingTabButton({
    super.key,
    required this.label,
    required this.index,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surface = colorScheme.surfaceContainerHighest;
    final primary = colorScheme.primary;

    return ListenableBuilder(
      listenable: tabController,
      builder: (context, child) {
        final isSelected = tabController.index == index; // Check if selected

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? primary : surface,
          ),
          onPressed: () {
            tabController.index = index; // Update the TabController index
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.primaryOnSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}
