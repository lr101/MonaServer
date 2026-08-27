import 'dart:typed_data';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_edit_state.g.dart';

@riverpod
class UserEditState extends _$UserEditState {

  bool _hasChanged = false;

  bool get hasChanged => _hasChanged;

  @override
  Uint8List? build() {
    final userId = ref.watch(userIdProvider);
    return ref.watch(getUserProfileProvider(userId)).value;
  }

  void update(Uint8List image) {
    state = image;
    _hasChanged = true;
  }
}
