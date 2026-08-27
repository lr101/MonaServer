
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_map_state.g.dart';

@riverpod
class FeedMapState extends _$FeedMapState {
  @override
  bool build(String pinId) {
    return true;
  }

  void update() {
    state = !state;
    ref.notifyListeners();
  }

}
