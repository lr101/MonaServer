
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_panel_state.g.dart';

@riverpod
class MapPanelState extends _$MapPanelState {
  @override
  bool build() {
    return false;
  }

  // ignore: use_setters_to_change_properties
  void set(bool val) {
    state = val;
  }
}
