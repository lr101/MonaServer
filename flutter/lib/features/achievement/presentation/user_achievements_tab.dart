import 'dart:math';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_tier_carousel.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/util/types/achievement.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class UserAchievementsTab extends ConsumerStatefulWidget {
  const UserAchievementsTab({super.key});

  @override
  ConsumerState<UserAchievementsTab> createState() =>
      _UserAchievementsTabState();
}

class _UserAchievementsTabState extends ConsumerState<UserAchievementsTab> {
  @override
  Widget build(BuildContext context) {
    final achievements = ref.watch(achievementsProvider);
    final userId = ref.watch(userIdProvider);
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
      data: (items) => _buildAchievementTracks(items, userId),
    );
  }

  Widget _buildAchievementTracks(
    List<UserAchievementsDtoInner> items,
    String userId,
  ) {
    final tracks = _personalAchievementTracks
        .map(
          (track) => _PersonalAchievementTrack(
            id: track.id,
            title: track.title,
            achievements:
                items
                    .where((achievement) => achievement.track == track.id)
                    .toList()
                  ..sort((a, b) {
                    final threshold = a.thresholdValue.compareTo(
                      b.thresholdValue,
                    );
                    return threshold == 0
                        ? a.achievementId.compareTo(b.achievementId)
                        : threshold;
                  }),
          ),
        )
        .where((track) => track.achievements.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(achievementsProvider.future).then<void>((_) {}),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: tracks.isEmpty ? 2 : tracks.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, itemIndex) {
            if (itemIndex == 0) {
              return UserXpProfilePanel(userId: userId);
            }
            if (tracks.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No achievements yet.')),
              );
            }
            final track = tracks[itemIndex - 1];
            return AchievementTierCarousel(
              key: ValueKey(track.id),
              title: track.title,
              tierCount: track.achievements.length,
              initialPage: activeAchievementTierIndex(
                track.achievements,
                (achievement) => achievement.claimed,
              ),
              itemBuilder: (context, tierIndex) => _AchievementMilestoneCard(
                achievement: track.achievements[tierIndex],
              ),
            );
          },
        ),
      ),
    );
  }
}

const _personalAchievementTracks = <_PersonalAchievementTrackDefinition>[
  _PersonalAchievementTrackDefinition('sticks', 'Pins'),
  _PersonalAchievementTrackDefinition('photos', 'Photos'),
  _PersonalAchievementTrackDefinition('places', 'Countries'),
  _PersonalAchievementTrackDefinition('groups', 'Groups'),
  _PersonalAchievementTrackDefinition('likes_given', 'Likes given'),
  _PersonalAchievementTrackDefinition('likes_received', 'Likes received'),
];

class _PersonalAchievementTrackDefinition {
  const _PersonalAchievementTrackDefinition(this.id, this.title);

  final String id;
  final String title;
}

class _PersonalAchievementTrack {
  const _PersonalAchievementTrack({
    required this.id,
    required this.title,
    required this.achievements,
  });

  final String id;
  final String title;
  final List<UserAchievementsDtoInner> achievements;
}

class _AchievementMilestoneCard extends ConsumerWidget {
  const _AchievementMilestoneCard({required this.achievement});

  final UserAchievementsDtoInner achievement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _calculateProgress(achievement);
    final claimable =
        achievement.claimable ?? (!achievement.claimed && progress >= 1);
    final legacy = _legacyAchievement(achievement);
    final rewardDescription = _achievementRewardDescription(achievement);
    return AchievementCard(
      title: achievement.name ?? legacy.name,
      description: achievement.description ?? legacy.description,
      currentValue: achievement.currentValue,
      thresholdValue: achievement.thresholdValue,
      progress: progress,
      claimed: achievement.claimed,
      claimable: claimable,
      reward: _AchievementRewardPreview(
        achievement: achievement,
        definition: legacy,
      ),
      rewardDescription: rewardDescription,
      onTap: claimable ? () => _claim(context, ref) : null,
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
    final rewardType = _achievementRewardType(achievement);
    final rewardMessage = switch (rewardType) {
      'xp' =>
        rewardAvailable
            ? 'Claimed $achievementName · +${achievement.rewardXp ?? 20} XP'
            : 'Restored $achievementName · XP already earned',
      'color' =>
        'Claimed $achievementName · ${achievement.rewardColor == null ? 'badge color' : '${_batchColorName(achievement.rewardColor!)} color'} unlocked',
      _ =>
        'Claimed $achievementName · ${_badgeRarity(achievement.difficulty)} badge unlocked',
    };
    final message = result ?? rewardMessage;
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
}

class _AchievementRewardPreview extends StatelessWidget {
  const _AchievementRewardPreview({
    required this.achievement,
    required this.definition,
  });

  final UserAchievementsDtoInner achievement;
  final Achievement definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = achievement.rewardColor;
    final colorValue = color == null
        ? null
        : Color(int.parse(color.substring(1), radix: 16));
    final rewardType = _achievementRewardType(achievement);
    final rewardContent = switch (rewardType) {
      'xp' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text('${achievement.rewardXp ?? 20} XP'),
        ],
      ),
      'color' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colorValue != null)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorValue,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              color == null ? 'Badge color' : '${_batchColorName(color)} color',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Batch(batchId: definition.id, fontSize: 10),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${_badgeRarity(achievement.difficulty)} badge',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: rewardContent)],
    );
  }
}

String _achievementRewardDescription(UserAchievementsDtoInner achievement) {
  final color = achievement.rewardColor;
  return switch (_achievementRewardType(achievement)) {
    'xp' => '${achievement.rewardXp ?? 20} XP',
    'color' =>
      color == null ? 'Badge color' : '${_batchColorName(color)} badge color',
    _ => '${_badgeRarity(achievement.difficulty)} profile badge',
  };
}

String _achievementRewardType(UserAchievementsDtoInner achievement) =>
    achievement.rewardType?.value ??
    switch (achievement.difficulty) {
      'easy' => 'xp',
      'medium' => 'color',
      _ => 'badge',
    };

String _badgeRarity(String? difficulty) => switch (difficulty) {
  'hard' => 'Legendary',
  'medium' => 'Rare',
  _ => 'Starter',
};

String _batchColorName(String color) => switch (color) {
  '#FF7CB342' => 'Leaf green',
  '#FFE53935' => 'Ruby',
  '#FFC62828' => 'Crimson',
  '#FF26A69A' => 'Sea teal',
  '#FFD81B60' => 'Magenta',
  '#FFC2185B' => 'Raspberry',
  '#FFEF6C00' => 'Burnt orange',
  '#FFFFC107' => 'Amber',
  '#FFFF5722' => 'Deep orange',
  '#FFD4E157' => 'Lime',
  '#FF2196F3' => 'Blue',
  '#FFFF7043' => 'Coral',
  '#FF673AB7' => 'Violet',
  '#FF00ACC1' => 'Cyan',
  '#FF7B1FA2' => 'Amethyst',
  '#FF3F51B5' => 'Indigo',
  '#FF795548' => 'Brown',
  _ => 'Custom',
};

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
      orElse: () => Achievement.unknown,
    );
