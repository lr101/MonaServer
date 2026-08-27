
import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';


class UserLikeEntity extends CacheEntity {

  @override
  int get isarId => fastHash(userId);
  String userId;
  final int likeCount;
  final int likePhotographyCount;
  final int likeLocationCount;
  final int likeArtCount;

  UserLikeEntity({
    required this.userId,
    required this.likeCount,
    required this.likePhotographyCount,
    required this.likeLocationCount,
    required this.likeArtCount,
    super.hits,
    required super.ttl,
    required super.onlySession
  });

  factory UserLikeEntity.fromDto(UserLikesDto likes, String userId, bool onlySession) {
    return UserLikeEntity(
        userId: userId,
        likeCount: likes.likeCount,
        likePhotographyCount: likes.likePhotographyCount,
        likeLocationCount: likes.likeLocationCount,
        likeArtCount: likes.likeArtCount,
        ttl: DateTime.now(),
        onlySession: onlySession
    );
  }

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return UserLikeEntity(
      userId: userId,
      likeCount: likeCount,
      likePhotographyCount: likePhotographyCount,
      likeLocationCount: likeLocationCount,
      likeArtCount: likeArtCount,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession
    );
  }

}
