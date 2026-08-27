
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_review_state.g.dart';

@riverpod
class AppReviewState extends _$AppReviewState {
  @override
  bool build() {
    final pref = ref.watch(sharedPreferencesProvider);
    final lastReviewDate = pref.getString(GlobalDataRepository.lastReviewKey);
    if (lastReviewDate == null || DateTime.tryParse(lastReviewDate)?.add(const Duration(days: 7)).isBefore(DateTime.now()) == true)  {
      return true;
    }
    return false;
  }

  void updateLastReviewDate() {
    final pref = ref.watch(sharedPreferencesProvider);
    pref.setString(GlobalDataRepository.lastReviewKey, DateTime.now().toIso8601String());
    state = false;
  }
}
