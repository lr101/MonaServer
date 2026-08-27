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
    final c1 = Theme.of(context).colorScheme.surfaceContainerHighest; // Color when not selected
    final c2 = Theme.of(context).primaryColor; // Color when selected

    return ListenableBuilder(
      listenable: tabController,
      builder: (context, child) {
        final isSelected = tabController.index == index; // Check if selected

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? c2 : c1, // Set background color
          ),
          onPressed: () {
            tabController.index = index; // Update the TabController index
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              label,
              style: TextStyle(color: isSelected ? c1 : c2), // Set text color
            ),
          ),
        );
      },
    );
  }
}
