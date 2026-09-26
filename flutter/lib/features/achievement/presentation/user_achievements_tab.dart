import 'dart:math';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/util/types/achievement.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class UserAchievementsTab extends ConsumerWidget {
  const UserAchievementsTab({super.key});

  static const _tracks = <String>[
    'sticks',
    'places',
    'groups',
    'likes_given',
    'likes_received',
    'other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final userId = ref.watch(userIdProvider);
    final selectedBatch = ref.watch(userByIdSelectedBatchProvider(userId));
    return achievements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Achievements could not be loaded.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(achievementsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(achievementsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            UserXpProfilePanel(userId: userId),
            const SizedBox(height: 12),
            Text(
              'Choose a track and work through its milestones. Claim each reward when it is ready.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final track in _tracks)
              _AchievementTrackSection(
                track: track,
                achievements:
                    items.where((item) => _trackFor(item) == track).toList()
                      ..sort(
                        (a, b) => a.thresholdValue.compareTo(b.thresholdValue),
                      ),
                selectedBatch: selectedBatch.value,
                userId: userId,
              ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTrackSection extends StatelessWidget {
  const _AchievementTrackSection({
    required this.track,
    required this.achievements,
    required this.selectedBatch,
    required this.userId,
  });

  final String track;
  final List<UserAchievementsDtoInner> achievements;
  final int? selectedBatch;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = achievements.where((item) => item.claimed).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_trackIcon(track), color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _trackTitle(track),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$earned/${achievements.length} earned',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final achievement in achievements)
            _AchievementMilestoneCard(
              achievement: achievement,
              isSelected: selectedBatch == achievement.achievementId,
              userId: userId,
            ),
        ],
      ),
    );
  }
}

class _AchievementMilestoneCard extends ConsumerWidget {
  const _AchievementMilestoneCard({
    required this.achievement,
    required this.isSelected,
    required this.userId,
  });

  final UserAchievementsDtoInner achievement;
  final bool isSelected;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final progress = _calculateProgress(achievement);
    final track = _trackFor(achievement);
    final claimable =
        achievement.claimable ?? (!achievement.claimed && progress >= 1);
    final legacy = _legacyAchievement(achievement);
    final name = achievement.name ?? legacy.name;
    final description = achievement.description ?? legacy.description;
    final difficulty = achievement.difficulty ?? 'easy';
    final rewardXp = achievement.rewardXp ?? 20;
    final cardColor = achievement.claimed
        ? colors.surfaceContainerHighest
        : colors.surface;
    final borderColor = claimable
        ? colors.primary
        : isSelected
        ? colors.tertiary
        : colors.outlineVariant;
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: claimable || isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _trackIcon(track),
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RewardPill(
                  difficulty: difficulty,
                  rewardXp: rewardXp,
                  rewardAvailable: achievement.rewardAvailable ?? true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: achievement.claimed
                          ? colors.tertiary
                          : colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${achievement.currentValue}/${achievement.thresholdValue}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutBack,
              child: claimable
                  ? SizedBox(
                      key: const ValueKey('claim'),
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _claim(context, ref),
                        icon: const Icon(Icons.redeem),
                        label: Text(
                          achievement.rewardAvailable == false
                              ? 'Restore badge'
                              : 'Claim $rewardXp XP',
                        ),
                      ),
                    )
                  : achievement.claimed
                  ? SizedBox(
                      key: const ValueKey('earned'),
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isSelected
                            ? null
                            : () => _selectBadge(context, ref),
                        icon: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.workspace_premium,
                        ),
                        label: Text(
                          isSelected ? 'Shown on profile' : 'Show on profile',
                        ),
                      ),
                    )
                  : Padding(
                      key: const ValueKey('progress'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Keep going to unlock this reward',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final result = await ref
        .read(achievementsProvider.notifier)
        .claimAchievement(achievement.achievementId);
    final achievementName =
        achievement.name ?? _legacyAchievement(achievement).name;
    final rewardAvailable = achievement.rewardAvailable ?? true;
    final message =
        result ??
        (rewardAvailable
            ? 'Claimed $achievementName · +${achievement.rewardXp ?? 20} XP'
            : 'Restored $achievementName · XP already earned');
    if (result == null && !reduceMotion) {
      await HapticFeedback.lightImpact();
    }
    CustomErrorSnackBar.message(
      message: message,
      type: result == null
          ? CustomErrorSnackBarType.success
          : CustomErrorSnackBarType.error,
    );
  }

  Future<void> _selectBadge(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(userServiceProvider(userId).notifier)
        .changeUser(selectedBatch: achievement.achievementId);
    CustomErrorSnackBar.message(
      message:
          result ??
          'Showing ${achievement.name ?? _legacyAchievement(achievement).name} on your profile',
      type: result != null
          ? CustomErrorSnackBarType.error
          : CustomErrorSnackBarType.success,
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({
    required this.difficulty,
    required this.rewardXp,
    required this.rewardAvailable,
  });

  final String difficulty;
  final int rewardXp;
  final bool rewardAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rewardAvailable
            ? '${_capitalize(difficulty)} · $rewardXp XP'
            : 'XP already earned',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

double _calculateProgress(UserAchievementsDtoInner achievement) {
  if (achievement.thresholdValue <= 0) return 0;
  if (!achievement.thresholdUp) {
    return achievement.currentValue <= achievement.thresholdValue ? 1 : 0;
  }
  return min(1, achievement.currentValue / achievement.thresholdValue);
}

String _trackTitle(String track) => switch (track) {
  'sticks' => 'Sticks',
  'places' => 'Places',
  'groups' => 'Groups',
  'likes_given' => 'Likes you give',
  'likes_received' => 'Likes you receive',
  _ => 'Other milestones',
};

IconData _trackIcon(String track) => switch (track) {
  'sticks' => Icons.push_pin_outlined,
  'places' => Icons.explore_outlined,
  'groups' => Icons.groups_outlined,
  'likes_given' => Icons.favorite_border,
  'likes_received' => Icons.favorite,
  _ => Icons.emoji_events_outlined,
};

String _trackFor(UserAchievementsDtoInner achievement) {
  final track = achievement.track;
  if (track != null && track.isNotEmpty) return track;
  return switch (achievement.achievementId) {
    0 || 10 || 11 => 'places',
    2 || 4 || 13 => 'groups',
    3 || 9 || 12 => 'sticks',
    5 || 7 || 14 => 'likes_given',
    6 || 8 || 15 => 'likes_received',
    _ => 'other',
  };
}

Achievement _legacyAchievement(UserAchievementsDtoInner achievement) =>
    Achievement.values.firstWhere(
      (item) => item.id == achievement.achievementId,
      orElse: () => Achievement.admin,
    );

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
