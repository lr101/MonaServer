
import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';


class UserPinsEntity extends CacheEntity {

  @override
  int get isarId => fastHash(userId);
  String userId;
  List<String> pins = [];
  UserPinsEntity({required this.pins, required this.userId, super.keepAlive = false, super.hits, required super.ttl, required super.onlySession});
 
  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return UserPinsEntity(
      pins: pins,
      userId: userId,
      ttl: ttl ?? this.ttl,
      hits: hits ?? this.hits,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession
    );
  }

}
