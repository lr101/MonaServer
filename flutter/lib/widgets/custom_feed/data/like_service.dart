import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_like_entity.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'like_service.g.dart';

@riverpod
class LikeService extends _$LikeService {
  final Mutex _mutex = Mutex();

  late LikesApi _likesApi;
  late SessionIdentity _session;

  @override
  Future<PinLikeDto> build(String pinId) async {
    _likesApi = ref.watch(likeApiProvider);
    final session = watchSession(ref);
    _session = session;
    try {
      await _mutex.acquire();
      final pinLikeRepo = ref.watch(pinLikeRepositoryProvider);
      final pinLike = await pinLikeRepo.get(pinId);
      if (pinLike != null) {
        return _nonNegative(pinLike.toDto());
      } else {
        try {
          final pinLikeDto = _nonNegative(await _fetchLike(pinId));
          if (!isCurrentSession(ref, session)) {
            return PinLikeDto();
          }
          await pinLikeRepo.put(PinLikeEntity.fromDto(pinLikeDto, pinId));
          return pinLikeDto;
        } catch (error) {
          // Keep retryable transport/item failures out of the negative cache.
          // A later consumer should be able to retry the batch read instead of
          // observing a fabricated all-zero like result.
          if (kDebugMode) print(error);
          return PinLikeDto();
        }
      }
    } finally {
      _mutex.release();
    }
  }

  Future<PinLikeDto> _fetchLike(String pinId) async {
    final result = await ref
        .read(batchReadCoalescerProvider)
        .readKey(BatchReadKey(BatchReadKind.pinLikes, pinId));
    return result.likes ?? PinLikeDto();
  }

  Future<void> addLike(String creatorId, CreateLikeDto createLikeDto) async {
    final pinLikeRepo = ref.read(pinLikeRepositoryProvider);
    final session = _session;
    await _mutex.acquire();
    final currentState = _nonNegative(state.value ?? PinLikeDto());
    try {
      final pinDto = PinLikeDto(
        likeCount: _likeUpdate(
          createLikeDto.like,
          currentState.likedByUser,
          currentState.likeCount ?? 0,
        ),
        likedByUser: createLikeDto.like ?? currentState.likedByUser ?? false,
      );
      if (!isCurrentSession(ref, session)) return;
      state = AsyncData(pinDto);
      final PinLikeDto confirmed;
      try {
        confirmed = _nonNegative(
          await _likesApi.createOrUpdateLike(pinId, createLikeDto) ?? pinDto,
        );
      } catch (_) {
        if (isCurrentSession(ref, session)) state = AsyncData(currentState);
        return;
      }
      if (!isCurrentSession(ref, session)) return;
      state = AsyncData(confirmed);
      try {
        await pinLikeRepo.put(PinLikeEntity.fromDto(confirmed, pinId));
      } catch (error) {
        if (kDebugMode) print(error);
      }
      if (!isCurrentSession(ref, session)) return;
      try {
        await ref
            .read(userLikeServiceProvider(creatorId).notifier)
            .updateLikeCount(
              CreateLikeDto(
                userId: createLikeDto.userId,
                like: _changed(currentState.likedByUser, confirmed.likedByUser),
              ),
            );
      } catch (error) {
        if (kDebugMode) print(error);
      }
    } finally {
      _mutex.release();
    }
  }

  PinLikeDto _nonNegative(PinLikeDto likes) => PinLikeDto(
    likeCount: _count(likes.likeCount),
    likedByUser: likes.likedByUser,
  );

  int? _count(int? value) => value == null || value >= 0 ? value : 0;

  bool? _changed(bool? before, bool? after) =>
      (before ?? false) == (after ?? false) ? null : after ?? false;

  int _likeUpdate(bool? like, bool? likeCurrent, int current) {
    final count = current < 0 ? 0 : current;
    if (like == true && likeCurrent != true) {
      return count + 1;
    } else if (like == false && likeCurrent == true) {
      return count > 0 ? count - 1 : 0;
    } else {
      return count;
    }
  }
}
