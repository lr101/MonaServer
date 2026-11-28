import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:flutter/material.dart';

/// Supplies the category identity to a milestone displayed in a track list.
class AchievementTrackScope extends InheritedWidget {
  const AchievementTrackScope({
    super.key,
    required this.icon,
    required this.title,
    required super.child,
  });
  final IconData icon;
  final String title;
  @override
  bool updateShouldNotify(AchievementTrackScope oldWidget) =>
      oldWidget.icon != icon || oldWidget.title != title;
}

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
    final scope = context
        .dependOnInheritedWidgetOfExactType<AchievementTrackScope>();
    if (scope != null) return _compact(context, scope);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final cardSurface = isLight
        ? colors.surfaceContainerLowest
        : colors.surfaceContainer;
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
        color: cardSurface,
        elevation: isLight ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: claimable
                    ? fillColor
                    : colors.outlineVariant.withValues(
                        alpha: isLight ? 0.55 : 0.7,
                      ),
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
                    vertical: 10,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (reward != null) ...[
                              const SizedBox(height: 5),
                              reward!,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 88),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currentValue/$thresholdValue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'About $title',
                              icon: Icon(
                                claimed
                                    ? Icons.check_circle_outline
                                    : claimable
                                    ? Icons.redeem_outlined
                                    : Icons.info_outline,
                              ),
                              onPressed: () => _showDetails(context),
                            ),
                          ],
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

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(description),
              const SizedBox(height: 12),
              Text('$currentValue of $thresholdValue'),
              if (rewardDescription != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Reward: $rewardDescription'),
                ),
              if (claimable && onTap != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onTap!();
                  },
                  icon: const Icon(Icons.redeem),
                  label: const Text('Collect reward'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, AchievementTrackScope scope) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final ready = claimable && !claimed;
    final color = claimed
        ? colors.tertiary
        : ready
        ? colors.primaryOnSurface
        : colors.onSurfaceVariant;
    final shownValue = thresholdValue > 0 && currentValue > thresholdValue
        ? thresholdValue
        : currentValue;
    final status = claimed ? 'Collected' : '$shownValue / $thresholdValue';
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: () => _showDetails(context),
      label:
          '${scope.title}, $title, $description, $currentValue of $thresholdValue${ready
              ? ', ready to collect'
              : claimed
              ? ', collected'
              : ''}${rewardDescription == null ? '' : ', unlocks $rewardDescription'}',
      child: Material(
        color: isLight
            ? colors.surfaceContainerLowest
            : colors.surfaceContainer,
        elevation: isLight ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: ready
                ? colors.primary.withValues(alpha: isLight ? 0.42 : 0.50)
                : colors.outlineVariant.withValues(
                    alpha: isLight ? 0.55 : 0.72,
                  ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isLight ? 0.16 : 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    claimed ? Icons.check_circle_outline : scope.icon,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${scope.title} · $status',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (!claimed &&
                          !(ready && currentValue >= thresholdValue)) ...[
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          color: ready
                              ? colors.primary
                              : colors.primary.withValues(alpha: 0.8),
                          backgroundColor: colors.surfaceContainerHighest,
                          minHeight: 3.5,
                          borderRadius: BorderRadius.circular(999),
                          semanticsLabel: '$title progress',
                        ),
                      ],
                      if (reward != null) ...[
                        const SizedBox(height: 5),
                        reward!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (ready)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Collect',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
