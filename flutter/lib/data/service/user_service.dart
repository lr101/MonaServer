import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_service.g.dart';

@riverpod
class UserService extends _$UserService {
  late IUserRepository _repo;
  late GlobalDataDto _global;

  @override
  Stream<UserEntity?> build(String userId) {
    _repo = ref.watch(userRepositoryProvider);
    _global = ref.watch(globalDataServiceProvider);
    final userApi = ref.watch(userApiProvider);

    _updateRemoteIfMissing(_repo, _global, userApi);

    return _repo.watchById(userId);
    
  }

  Future<void> _updateRemoteIfMissing(IUserRepository repo, GlobalDataDto global, UsersApi userApi) async {
    final localUser = await _repo.get(this.userId);
    if (localUser != null) return;
    final bool isCurrentUser = this.userId == _global.userId;
    final userDto = await userApi.getUser(this.userId);
    await _repo.put(UserEntity.fromDto(userDto!, !isCurrentUser, keepAlive: isCurrentUser,),);
  }

  Future<String?> changeUser({
    String? password,
    String? email,
    Uint8List? profilePicture,
    String? description,
    String? username,
    int? selectedBatch,
  }) async {
    try {
      final userApi = ref.watch(userApiProvider);
      final result = await userApi.updateUser(
          this.userId,
          UserUpdateDto(
              password: password,
              email: email,
              description: description,
              username: username,
              selectedBatch: selectedBatch,
              image: profilePicture == null ? null : base64Encode(profilePicture,),),
      );

      final userEntity = state.value;
      if (result != null && userEntity != null) {
        final userDto = userEntity.copyUserWith(result, selectedBatch);
        await _repo.put(userDto);
        if (profilePicture != null) {
          ref.read(userImageRepoProvider).overrideUrl(
              this.userId, result.profileImage!, true,);
          ref.read(userImageSmallRepoProvider).overrideUrl(
              this.userId, result.profileImageSmall!, true,);
        }
      }
      return null;
    } on ApiException catch (e) {
      return e.message ?? "Something unexpected happened";
    }
  }
}

@riverpod
Future<String?> userByIdUsername(Ref ref, String userId) async {
  return await ref.watch(userServiceProvider(userId).selectAsync((e) => e?.username));
}

@riverpod
Future<int?> userByIdSelectedBatch(Ref ref, String userId) async {
  return await ref.watch(userServiceProvider(userId).selectAsync((e) => e?.selectedBatch));
}

@riverpod
Future<String?> userByIdDescription(Ref ref, String userId) async {
  return await ref.watch(userServiceProvider(userId).selectAsync((e) => e?.description));
}

@riverpod
Future<SeasonEntity?> userByIdBestSeason(Ref ref, String userId) async {
  return await ref.watch(userServiceProvider(userId).selectAsync((e) => e?.bestSeason));
}

@riverpod
Future<UserEntity?> currentUser(Ref ref) async {
  final userId = ref.watch(userIdProvider);
  return ref.watch(userServiceProvider(userId)).value;
}
