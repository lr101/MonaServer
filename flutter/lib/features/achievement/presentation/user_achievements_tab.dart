import 'dart:math';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/util/types/achievement.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class UserAchievementsTab extends ConsumerWidget {
  const UserAchievementsTab({super.key});

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
            for (final achievement in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AchievementMilestoneCard(
                  achievement: achievement,
                  isSelected: selectedBatch.value == achievement.achievementId,
                  userId: userId,
                ),
              ),
          ],
        ),
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
    final progress = _calculateProgress(achievement);
    final claimable =
        achievement.claimable ?? (!achievement.claimed && progress >= 1);
    final legacy = _legacyAchievement(achievement);
    return AchievementCard(
      title: achievement.name ?? legacy.name,
      description: achievement.description ?? legacy.description,
      currentValue: achievement.currentValue,
      thresholdValue: achievement.thresholdValue,
      progress: progress,
      claimed: achievement.claimed,
      claimable: claimable,
      selected: isSelected,
      onTap: claimable
          ? () => _claim(context, ref)
          : achievement.claimed && !isSelected
          ? () => _selectBadge(context, ref)
          : null,
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

double _calculateProgress(UserAchievementsDtoInner achievement) {
  if (achievement.thresholdValue <= 0) return 0;
  if (!achievement.thresholdUp) {
    return achievement.currentValue <= achievement.thresholdValue ? 1 : 0;
  }
  return min(1, achievement.currentValue / achievement.thresholdValue);
}

Achievement _legacyAchievement(UserAchievementsDtoInner achievement) =>
    Achievement.values.firstWhere(
      (item) => item.id == achievement.achievementId,
      orElse: () => Achievement.admin,
    );
