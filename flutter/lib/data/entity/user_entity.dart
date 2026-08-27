import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';


class UserEntity extends CacheEntity {

  @override
  int get isarId => fastHash(userId);
  final String userId;
  final String username;
  final int? selectedBatch;
  final String? description;
  final SeasonEntity? bestSeason;

  UserEntity({
    required this.userId,
    required this.username,
    this.selectedBatch,
    this.description,
    this.bestSeason,
    super.keepAlive,
    super.hits,
    required super.ttl,
    required super.onlySession
  });

  factory UserEntity.fromDto(UserInfoDto user, bool onlySession, {bool keepAlive = false}) {
    return UserEntity(
      userId: user.userId,
      username: user.username,
      selectedBatch: user.selectedBatch,
      description: user.description,
      bestSeason: user.bestSeason == null ? null : SeasonEntity.fromDto(user.bestSeason!),
      keepAlive: keepAlive,
      ttl: DateTime.now(),
      onlySession: onlySession
    );
  }

  UserEntity copyUserWith(UserUpdateResponseDto userDto, int? selectedBatch) {
    return UserEntity(
      userId: userId,
      username: userDto.userInfoDto!.username,
      selectedBatch: selectedBatch ?? this.selectedBatch,
      description: userDto.userInfoDto!.description ?? description,
      bestSeason: userDto.userInfoDto!.bestSeason == null ? bestSeason : SeasonEntity.fromDto(userDto.userInfoDto!.bestSeason!),
      keepAlive: keepAlive,
      ttl: ttl,
      hits: hits,
      onlySession: onlySession
    );
  }

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool?keepAlive, bool? onlySession}) {
    return UserEntity(
      userId: userId,
      username: username,
      selectedBatch: selectedBatch,
      description: description,
      bestSeason: bestSeason,
      keepAlive: keepAlive ?? this.keepAlive,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      onlySession: onlySession ?? this.onlySession
    );
  }

}
