import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openapi/api.dart';

class GroupXpCard extends StatelessWidget {
  const GroupXpCard({super.key, required this.xp});

  final GroupProgressionDto xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final progress = XpLevelProgress.fromGroupDto(xp);
    final locale = Localizations.localeOf(context).toString();
    final formattedXp = NumberFormat.decimalPattern(locale)
        .format(progress.totalXp);
    final nextLevelText = progress.xpToNextLevel == 0
        ? 'Maximum group level'
        : '${NumberFormat.decimalPattern(locale).format(progress.xpToNextLevel)} XP to next group level';

    return Semantics(
      container: true,
      label: 'Group level ${progress.level}, $formattedXp XP, $nextLevelText',
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: Text(
                          '${progress.level}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          child: Text(
                            'Group level ${progress.level}',
                            key: ValueKey(progress.level),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          child: Text(
                            '$formattedXp group XP',
                            key: ValueKey(progress.totalXp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.groups_2_rounded,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress.fraction),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.centerRight,
                  key: ValueKey(nextLevelText),
                  child: Text(
                    nextLevelText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
