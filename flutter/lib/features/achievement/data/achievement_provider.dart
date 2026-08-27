

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_provider.g.dart';

@riverpod
class Achievements extends _$Achievements {

  @override
  Future<List<UserAchievementsDtoInner>> build() async {
    final userId = ref.watch(userIdProvider);
    final achievement = await ref.watch(userApiProvider).getUserAchievements(userId);
    return achievement!;
  }

  Future<String?> claimAchievement(int achievementId) async {
    final userId = ref.watch(userIdProvider);
    try {
      await ref.watch(userApiProvider).claimUserAchievement(userId, achievementId);
      if (state.hasValue) {
        final index = state.value!.indexWhere((element) => element.achievementId == achievementId);
        state.value![index] = UserAchievementsDtoInner(
            achievementId: achievementId,
            claimed: true,
            thresholdValue: state.value![index].thresholdValue,
            currentValue: state.value![index].currentValue,
            thresholdUp: state.value![index].thresholdUp,
        );
        ref.notifyListeners();
      }
    } on ApiException catch (e) {
      return e.message ?? "Claim unsuccessful";
    }
    return null;
  }
}
