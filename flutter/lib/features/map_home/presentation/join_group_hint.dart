import 'package:buff_lisa/data/service/group_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinGroupHintOverlay extends ConsumerWidget {
  // Added super.key which is a standard Flutter best practice
  const JoinGroupHintOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const double height = 48.0; 
    const double borderRadius = 24.0;
    final currentGroup = ref.watch(userGroupServiceProvider);
    
    if (currentGroup.value == null || currentGroup.value!.isNotEmpty) {
      return const SizedBox.shrink();
    }

    // 3. Render the floating hint
    return GestureDetector(
      onTap: () => context.pushNamed("groupSearch"),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_rounded,
                color: theme.colorScheme.primary,
                size: 18.0,
              ),
              const SizedBox(width: 4.0),
              const Text(
                "Join a Group"
              ),
            ],
          ),
        ),
      ),
    );
  }
}
