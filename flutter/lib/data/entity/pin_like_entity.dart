
import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';


class PinLikeEntity extends CacheEntity {
  @override
  int get isarId => fastHash(id);
  final String id;
  final int likeCount;
  final int likePhotographyCount;
  final int likeLocationCount;
  final int likeArtCount;
  final bool hasLike;
  final bool hasLikePhotography;
  final bool hasLikeLocation;
  final bool hasLikeArt;

  PinLikeEntity({
    required this.id,
    required this.likeCount,
    required this.likePhotographyCount,
    required this.likeLocationCount,
    required this.likeArtCount,
    required this.hasLikeArt,
    required this.hasLike,
    required this.hasLikeLocation,
    required this.hasLikePhotography,
    super.hits,
    super.onlySession = true,
    required super.ttl,
  });

  factory PinLikeEntity.fromDto(PinLikeDto likes, String pinId) {
    return PinLikeEntity(
      id: pinId,
      likeCount: likes.likeCount ?? 0,
      likePhotographyCount: likes.likePhotographyCount ?? 0,
      likeLocationCount: likes.likeLocationCount ?? 0,
      likeArtCount: likes.likeArtCount ?? 0,
      hasLike: likes.likedByUser ?? false,
      hasLikeLocation: likes.likedLocationByUser ?? false,
      hasLikeArt: likes.likedArtByUser ?? false,
      hasLikePhotography: likes.likedPhotographyByUser ?? false,
      ttl: DateTime.now()
    );
  }


  PinLikeDto toDto() {
    return PinLikeDto(
      likeCount: likeCount,
      likePhotographyCount: likePhotographyCount,
      likeLocationCount: likeLocationCount,
      likeArtCount: likeArtCount,
      likedByUser: hasLike,
      likedPhotographyByUser: hasLikePhotography,
      likedLocationByUser: hasLikeLocation,
      likedArtByUser: hasLikeArt,
    );
  }

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return PinLikeEntity(
      id: id,
      likeCount: likeCount,
      likePhotographyCount: likePhotographyCount,
      likeLocationCount: likeLocationCount,
      likeArtCount: likeArtCount,
      hasLike: hasLike,
      hasLikeLocation: hasLikeLocation,
      hasLikeArt: hasLikeArt,
      hasLikePhotography: hasLikePhotography,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession
    );
  }

}
