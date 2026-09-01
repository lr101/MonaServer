import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/user_like_entity.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'like_service.g.dart';

@riverpod
class UserLikeService extends _$UserLikeService {
  @override
  Future<UserLikesDto> build(String userId) async {
    final userLikeRepo = ref.watch(userLikeRepositoryProvider);
    final likeApi = ref.watch(likeApiProvider);
    final sessionGuard = ref.watch(accountDataSessionGuardProvider);
    final generation = sessionGuard.generation;
    final likes = await userLikeRepo.get(userId);
    if (likes != null) {
      return UserLikesDto(
        likeCount: likes.likeCount,
        likeArtCount: likes.likeArtCount,
        likeLocationCount: likes.likeLocationCount,
        likePhotographyCount: likes.likePhotographyCount,
      );
    } else {
      final likeDto = await likeApi.getUserLikes(userId);
      if (likeDto == null) {
        throw StateError('The likes response was empty');
      }
      await sessionGuard.runIfCurrent(
        generation,
        () => userLikeRepo.put(UserLikeEntity.fromDto(likeDto, userId, true)),
      );
      return likeDto;
    }
  }

  Future<void> updateLikeCount(
    CreateLikeDto likeUpdate, {
    int? sessionGeneration,
  }) async {
    if (state.value == null) return;
    final sessionGuard = ref.read(accountDataSessionGuardProvider);
    final generation = sessionGeneration ?? sessionGuard.generation;
    final UserLikesDto likes = UserLikesDto(
      likeCount: state.value!.likeCount + _likeUpdate(likeUpdate.like),
      likeArtCount: state.value!.likeArtCount + _likeUpdate(likeUpdate.likeArt),
      likeLocationCount:
          state.value!.likeLocationCount + _likeUpdate(likeUpdate.likeLocation),
      likePhotographyCount:
          state.value!.likePhotographyCount +
          _likeUpdate(likeUpdate.likePhotography),
    );
    final userLikeRepo = ref.read(userLikeRepositoryProvider);
    await sessionGuard.runIfCurrent(generation, () async {
      state = AsyncData(likes);
      await userLikeRepo.put(UserLikeEntity.fromDto(likes, userId, true));
    });
  }

  int _likeUpdate(bool? like) {
    if (like == true) {
      return 1;
    } else if (like == false) {
      return -1;
    } else {
      return 0;
    }
  }
}
