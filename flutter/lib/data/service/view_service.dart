
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'view_service.g.dart';

enum ViewState {
  personal,
  group
}

@Riverpod(keepAlive: true)
class ViewService extends _$ViewService {
  
  @override
  ViewState build() {
    final viewState = ref.watch(sharedPreferencesProvider).getString("viewState");
    return viewState == ViewState.personal.name ? ViewState.personal : ViewState.group;
  }

  void toggleViewState() {
    final newState = state == ViewState.personal ? ViewState.group : ViewState.personal;
    ref.read(sharedPreferencesProvider).setString("viewState", newState.name);
    state = newState;
  }

}
