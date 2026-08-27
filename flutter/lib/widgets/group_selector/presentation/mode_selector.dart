import 'package:buff_lisa/data/service/view_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentMode = ref.watch(viewServiceProvider);
    final isGroup = currentMode == ViewState.group;

    // Matches GroupFilterWidget dimensions
    const double height = 48.0; 
    const double borderRadius = 24.0;
    const double innerPadding = 4.0; 

    return Container(
        height: height,
        width: 120, // Compact pill width
        decoration: BoxDecoration(
          // 1. Match Background to Filter Widget
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          // 2. Match Border to Filter Widget
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          // 3. Match Shadow to Filter Widget
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // --- SLIDING INDICATOR ---
            AnimatedAlign(
              alignment: isGroup ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutBack,
              child: Padding(
                padding: const EdgeInsets.all(innerPadding),
                child: Container(
                  width: (120 - (innerPadding * 2)) / 2, // Exact half width
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius - 4),
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // --- ICONS ---
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    context: context,
                    ref: ref,
                    mode: ViewState.group,
                    icon: Icons.groups,
                    isSelected: isGroup,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _buildModeButton(
                    context: context,
                    ref: ref,
                    mode: ViewState.personal,
                    icon: Icons.person,
                    isSelected: !isGroup,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildModeButton({
    required BuildContext context,
    required WidgetRef ref,
    required ViewState mode,
    required IconData icon,
    required bool isSelected,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final current = ref.read(viewServiceProvider);
          if (current != mode) {
             ref.read(viewServiceProvider.notifier).toggleViewState();
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isSelected ? 1.0 : 0.9,
            child: Icon(
              icon,
              size: 20,
              // If Selected: White (because indicator is Primary Orange/Blue)
              // If Unselected: OnSurfaceVariant (Subtle Grey)
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
