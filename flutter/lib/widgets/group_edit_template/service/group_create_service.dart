
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_create_service.g.dart';

class GroupCreateState {

  GroupCreateState({
    this.visibility = 0,
    this.profileImage,
  });

  int visibility;
  Uint8List? profileImage;


  factory GroupCreateState.fromGroupEntity(GroupEntity groupEntity, Uint8List? profileImage) {
    return GroupCreateState(
      visibility: groupEntity.visibility,
      profileImage: profileImage,
    );
  }


}

@riverpod
class GroupCreateService extends _$GroupCreateService {


  @override
  GroupCreateState build() =>  GroupCreateState();

  void init(GroupEntity groupEntity, Uint8List? profileImage) {
    state = GroupCreateState.fromGroupEntity(groupEntity, profileImage);
  }

  void updateProfileImage(Uint8List profileImage) {
    state.profileImage = profileImage;
    ref.notifyListeners();
  }

  void updateVisibility(int visibility) {
    state.visibility = visibility;
    ref.notifyListeners();
  }

}


@riverpod
Uint8List? createGroupProfileImage(Ref ref) {
  return ref.watch(groupCreateServiceProvider.select((e) => e.profileImage));
}
