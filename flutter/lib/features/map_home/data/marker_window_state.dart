

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'marker_window_state.g.dart';

@riverpod
class MarkerWindowState extends _$MarkerWindowState {

  @override
  PinEntity? build() {
    return null;
  }

  // ignore: use_setters_to_change_properties
  void openPopup(PinEntity pin) {
    state = pin;
  }

}
