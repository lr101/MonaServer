import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_service.g.dart';

@riverpod
class UserService extends _$UserService {
  late IUserRepository _repo;
  late AccountDataSessionGuard _sessionGuard;

  @override
  Stream<UserEntity?> build(String userId) {
    _repo = ref.watch(userRepositoryProvider);
    final global = ref.watch(globalDataServiceProvider);
    _sessionGuard = ref.watch(accountDataSessionGuardProvider);
    final userApi = ref.watch(userApiProvider);

    _updateRemoteIfMissing(_repo, global, userApi, _sessionGuard);

    return _repo.watchById(userId);
  }

  Future<void> _cacheImageBestEffort(
    IImageRepository repository,
    String userId,
    String url,
    int generation,
  ) async {
    try {
      await repository.overrideUrl(
        userId,
        url,
        true,
        sessionGeneration: generation,
      );
    } catch (error) {
      debugPrint('Unable to cache user image $userId: $error');
    }
  }

  Future<void> _updateRemoteIfMissing(
    IUserRepository repo,
    GlobalDataDto global,
    UsersApi userApi,
    AccountDataSessionGuard sessionGuard,
  ) async {
    final generation = sessionGuard.generation;
    final localUser = await repo.get(this.userId);
    if (localUser != null) return;
    final bool isCurrentUser = this.userId == global.userId;
    final userDto = await userApi.getUser(this.userId);
    if (userDto == null) return;
    await sessionGuard.runIfCurrent(
      generation,
      () => repo.put(
        UserEntity.fromDto(userDto, !isCurrentUser, keepAlive: isCurrentUser),
      ),
    );
  }

  Future<String?> changeUser({
    String? password,
    String? email,
    Uint8List? profilePicture,
    String? description,
    String? username,
    int? selectedBatch,
  }) async {
    final generation = _sessionGuard.generation;
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
          image: profilePicture == null ? null : base64Encode(profilePicture),
        ),
      );

      final userEntity = state.value;
      if (result != null && userEntity != null) {
        final userDto = userEntity.copyUserWith(result, selectedBatch);
        await _sessionGuard.runIfCurrent(generation, () => _repo.put(userDto));
        if (profilePicture != null) {
          final profileImage = result.profileImage;
          if (profileImage != null) {
            await _cacheImageBestEffort(
              ref.read(userImageRepoProvider),
              this.userId,
              profileImage,
              generation,
            );
          }
          final profileImageSmall = result.profileImageSmall;
          if (profileImageSmall != null) {
            await _cacheImageBestEffort(
              ref.read(userImageSmallRepoProvider),
              this.userId,
              profileImageSmall,
              generation,
            );
          }
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
  return await ref.watch(
    userServiceProvider(userId).selectAsync((e) => e?.username),
  );
}

@riverpod
Future<int?> userByIdSelectedBatch(Ref ref, String userId) async {
  return await ref.watch(
    userServiceProvider(userId).selectAsync((e) => e?.selectedBatch),
  );
}

@riverpod
Future<String?> userByIdDescription(Ref ref, String userId) async {
  return await ref.watch(
    userServiceProvider(userId).selectAsync((e) => e?.description),
  );
}

@riverpod
Future<SeasonEntity?> userByIdBestSeason(Ref ref, String userId) async {
  return await ref.watch(
    userServiceProvider(userId).selectAsync((e) => e?.bestSeason),
  );
}

@riverpod
Future<UserEntity?> currentUser(Ref ref) async {
  final userId = ref.watch(userIdProvider);
  return ref.watch(userServiceProvider(userId)).value;
}
