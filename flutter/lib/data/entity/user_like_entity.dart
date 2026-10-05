import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';

class UserLikeEntity extends CacheEntity {
  @override
  int get isarId => fastHash(userId);
  String userId;
  final int likeCount;

  UserLikeEntity({
    required this.userId,
    required this.likeCount,
    super.hits,
    required super.ttl,
    required super.onlySession,
  });

  factory UserLikeEntity.fromDto(
    UserLikesDto likes,
    String userId,
    bool onlySession,
  ) {
    return UserLikeEntity(
      userId: userId,
      likeCount: likes.likeCount,
      ttl: DateTime.now(),
      onlySession: onlySession,
    );
  }

  @override
  CacheEntity copyWith({
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
  }) {
    return UserLikeEntity(
      userId: userId,
      likeCount: likeCount,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession,
    );
  }
}
