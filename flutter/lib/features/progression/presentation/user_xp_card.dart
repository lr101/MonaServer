import 'dart:typed_data';

import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:openapi/api.dart';

export 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart'
    show AvatarLevelBadge, SmallProfilePicture, UserXpAvatarIndicator;

class UserXpProfilePanel extends ConsumerWidget {
  const UserXpProfilePanel({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(userXpProvider(userId))
        .when(
          data: (xp) =>
              xp == null ? const SizedBox.shrink() : UserXpCard(xp: xp),
          error: (error, stackTrace) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        );
  }
}

class UserXpCompactPanel extends ConsumerWidget {
  const UserXpCompactPanel({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(userXpProvider(userId))
        .when(
          data: (xp) => xp == null
              ? const SizedBox.shrink()
              : CompactUserLevelIndicator(xp: xp),
          error: (error, stackTrace) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        );
  }
}

class UserXpAvatarPanel extends ConsumerWidget {
  const UserXpAvatarPanel({
    super.key,
    required this.userId,
    required this.imageCallback,
  });

  final String userId;
  final AsyncValue<Uint8List?> imageCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SmallProfilePicture.user(
      userId: userId,
      radius: 17,
      imageCallback: imageCallback,
      showProgressRing: true,
    );
  }
}

class UserXpCard extends StatelessWidget {
  const UserXpCard({super.key, required this.xp});

  final UserXpDto xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final progress = XpLevelProgress.fromDto(xp);
    final formattedXp = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(progress.totalXp);
    final nextLevelText = progress.xpToNextLevel == 0
        ? 'Maximum level'
        : '${NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(progress.xpToNextLevel)} XP to next level';

    return Semantics(
      container: true,
      label: 'Level ${progress.level}, $formattedXp XP, $nextLevelText',
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
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: Text(
                          '${progress.level}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
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
                            'Level ${progress.level}',
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
                            '$formattedXp XP',
                            key: ValueKey(progress.totalXp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.stars_rounded),
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
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
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

class CompactUserLevelIndicator extends StatelessWidget {
  const CompactUserLevelIndicator({super.key, required this.xp});

  final UserXpDto xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final progress = XpLevelProgress.fromDto(xp);
    return Tooltip(
      message: 'Level ${progress.level} · ${progress.totalXp} XP',
      child: Container(
        width: 48,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: Text(
                'Lv ${progress.level}',
                key: ValueKey(progress.level),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 3),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: progress.fraction),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
