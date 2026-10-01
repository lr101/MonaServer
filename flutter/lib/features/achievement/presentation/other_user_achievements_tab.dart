import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtherUserAchievementsTab extends ConsumerWidget {
  const OtherUserAchievementsTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(publicUserAchievementsProvider(userId));
    return achievements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Achievements could not be loaded.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(publicUserAchievementsProvider(userId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (items) {
        final earned = items.where((item) => item.claimed).toList();
        if (earned.isEmpty) {
          return const Center(child: Text('No achievements yet.'));
        }
        return RefreshIndicator(
          onRefresh: () => ref
              .refresh(publicUserAchievementsProvider(userId).future)
              .then<void>((_) {}),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: earned.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final achievement = earned[index];
              final threshold = achievement.thresholdValue > 0
                  ? achievement.thresholdValue
                  : 1;
              return AchievementCard(
                title: achievement.name ?? 'Achievement',
                description: achievement.description ?? '',
                currentValue: threshold,
                thresholdValue: threshold,
                progress: 1,
                claimed: true,
                claimable: false,
              );
            },
          ),
        );
      },
    );
  }
}
