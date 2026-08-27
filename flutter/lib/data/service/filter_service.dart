import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filter_service.g.dart';

@Riverpod(keepAlive: true)
class HiddenUserService extends _$HiddenUserService {

  @override
  List<String> build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    return sharedPrefs.getStringList('hiddenUsers') ?? [];
  }


  void addHiddenUser(String userId) {
    final updatedUsers = [...state, userId];
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    sharedPrefs.setStringList('hiddenUsers', updatedUsers);
    state = updatedUsers;
  }

  void removeHiddenUser(String userId) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final updatedUsers = state.where((id) => id != userId).toList();
    sharedPrefs.setStringList('hiddenUsers', updatedUsers);
    state = updatedUsers;
  }

}


@Riverpod(keepAlive: true)
class HiddenPostsService extends _$HiddenPostsService {

  @override
  List<String> build() {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    return sharedPrefs.getStringList('hiddenPosts') ?? [];
  }


  void addHiddenPost(String pinId) {
    final updatedPosts = [...state, pinId];
    ref.read(sharedPreferencesProvider).setStringList('hiddenPosts', updatedPosts);
    state = updatedPosts;
  }

  void removeHiddenPost(String pinId) {
    final updatedPosts = state.where((id) => id != pinId).toList();
    ref.read(sharedPreferencesProvider).setStringList('hiddenPosts', updatedPosts);
    state = updatedPosts;
  }

}
