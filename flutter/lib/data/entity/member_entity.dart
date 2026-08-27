import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';


class MembersEntity extends CacheEntity{

  @override
  int get isarId => fastHash(groupId);

  final String groupId;
  final List<MemberEntity> members;

  MembersEntity({
    required this.groupId,
    required this.members,
    required super.ttl,
    required super.onlySession,
    super.hits,
    super.keepAlive,
  });

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return MembersEntity(
      groupId: groupId,
      members: members,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession
    );
  }

}

class MemberEntity {

  final String userId;

  final int points;

  final String username;

  final int? selectedBatch;

  MemberEntity({
    this.userId = "",
    this.points = 0,
    this.username = "",
    this.selectedBatch,
  });

  factory MemberEntity.fromRanking(MemberResponseDto memberDto) {
    return MemberEntity(userId: memberDto.userId, points: memberDto.ranking, username: memberDto.username, selectedBatch: memberDto.selectedBatch);
  }

}
