import 'package:flutter/material.dart';

/// The same compact milestone surface for personal and group achievements.
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.currentValue,
    required this.thresholdValue,
    required this.progress,
    required this.claimed,
    required this.claimable,
    this.reward,
    this.rewardDescription,
    this.onTap,
  });

  final String title;
  final String description;
  final int currentValue;
  final int thresholdValue;
  final double progress;
  final bool claimed;
  final bool claimable;
  final Widget? reward;
  final String? rewardDescription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fillColor = claimed ? colors.tertiary : colors.primary;
    final value = progress.clamp(0.0, 1.0);
    return Semantics(
      button: onTap != null,
      label:
          '$title, $description, $currentValue of $thresholdValue${claimable
              ? ', reward ready to claim'
              : claimed
              ? ', reward earned'
              : ''}${rewardDescription == null ? '' : ', unlocks $rewardDescription'}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: claimable ? fillColor : colors.outlineVariant,
                width: claimable ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: const ValueKey('achievement-progress-fill'),
                      widthFactor: value,
                      heightFactor: 1,
                      child: ColoredBox(
                        color: fillColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            if (reward != null) ...[
                              const SizedBox(height: 5),
                              reward!,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$currentValue/$thresholdValue',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: claimable
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
