import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/progression/data/refresh_xp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_provider.g.dart';

/// Reads earned achievements for another user's public profile.
final publicUserAchievementsProvider =
    FutureProvider.family<List<UserAchievementsDtoInner>, String>((
      ref,
      userId,
    ) async {
      if (!ref.watch(accountSessionProvider).isActive) return const [];
      final achievements = await ref
          .watch(userApiProvider)
          .getUserAchievements(userId);
      return achievements ?? const [];
    });

@riverpod
class Achievements extends _$Achievements {
  @override
  Future<List<UserAchievementsDtoInner>> build() async {
    final userId = ref.watch(userIdProvider);
    final achievement = await ref
        .watch(userApiProvider)
        .getUserAchievements(userId);
    return achievement!;
  }

  Future<String?> claimAchievement(int achievementId) async {
    final userId = ref.watch(userIdProvider);
    final session = captureSession(ref);
    try {
      await readXpBestEffort(ref, userId);
      if (!isCurrentSession(ref, session)) return 'Session ended';
      await ref
          .watch(userApiProvider)
          .claimUserAchievement(userId, achievementId);
      if (!isCurrentSession(ref, session)) return 'Session ended';
      if (state.hasValue) {
        final achievements = state.value!;
        final index = achievements.indexWhere(
          (element) => element.achievementId == achievementId,
        );
        if (index >= 0) {
          final previous = achievements[index];
          state = AsyncData([
            for (var i = 0; i < achievements.length; i++)
              if (i == index)
                UserAchievementsDtoInner(
                  achievementId: previous.achievementId,
                  name: previous.name,
                  description: previous.description,
                  track: previous.track,
                  difficulty: previous.difficulty,
                  rewardType: previous.rewardType,
                  rewardColor: previous.rewardColor,
                  rewardXp: previous.rewardXp,
                  claimable: false,
                  rewardAvailable: false,
                  definitionVersion: previous.definitionVersion,
                  claimed: true,
                  thresholdValue: previous.thresholdValue,
                  currentValue: previous.currentValue,
                  thresholdUp: previous.thresholdUp,
                )
              else
                achievements[i],
          ]);
        }
      }
      unawaited(readXpBestEffort(ref, userId, refresh: true));
    } on ApiException catch (e) {
      return e.message ?? "Claim unsuccessful";
    }
    return null;
  }
}
