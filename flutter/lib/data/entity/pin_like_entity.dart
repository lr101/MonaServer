import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';

class PinLikeEntity extends CacheEntity {
  @override
  int get isarId => fastHash(id);
  final String id;
  final int likeCount;
  final bool hasLike;

  PinLikeEntity({
    required this.id,
    required this.likeCount,
    required this.hasLike,
    super.hits,
    super.onlySession = true,
    required super.ttl,
  });

  factory PinLikeEntity.fromDto(PinLikeDto likes, String pinId) {
    return PinLikeEntity(
      id: pinId,
      likeCount: likes.likeCount ?? 0,
      hasLike: likes.likedByUser ?? false,
      ttl: DateTime.now(),
    );
  }

  PinLikeDto toDto() {
    return PinLikeDto(likeCount: likeCount, likedByUser: hasLike);
  }

  @override
  CacheEntity copyWith({
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
  }) {
    return PinLikeEntity(
      id: id,
      likeCount: likeCount,
      hasLike: hasLike,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession,
    );
  }
}
