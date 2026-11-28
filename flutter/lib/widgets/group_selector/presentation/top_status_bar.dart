import 'package:buff_lisa/data/service/global_data_service.dart'; // Adjust path
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/group_filter.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopStatusBar extends ConsumerWidget {
  const TopStatusBar({
    super.key,
    this.showProfileProgression = true,
    this.showUserLevel = true,
  });

  final bool showProfileProgression;
  final bool showUserLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double height = 48.0;
    const double borderRadius = 24.0;
    const double innerPadding = 6.0;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = colors.brightness == Brightness.light;
    final userId = ref.watch(userIdProvider);
    final user = ref.watch(currentUserProvider).value;

    return GestureDetector(
      onTap: () => ref.read(navigationStateProvider.notifier).setIndex(4),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isLight
              ? colors.surfaceContainerLowest
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: colors.outlineVariant.withValues(
              alpha: isLight ? 0.55 : 0.72,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.09 : 0.30),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.14),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: innerPadding),
          child: Row(
            children: [
              if (showUserLevel && showProfileProgression)
                UserXpAvatarPanel(userId: userId)
              else
                SmallProfilePicture.user(userId: userId, radius: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.username ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.onSurface,
                      ),
                    ),
                    if (user?.selectedBatch != null)
                      GestureDetector(
                        child: Batch(
                          batchId: user!.selectedBatch!,
                          fontSize: 7,
                          colorOverride: user.selectedBatchColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (showUserLevel && !showProfileProgression) ...[
                const SizedBox(width: 8),
                UserXpCompactPanel(userId: userId),
              ],
              const SizedBox(width: 4),
              const GroupFilterWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
