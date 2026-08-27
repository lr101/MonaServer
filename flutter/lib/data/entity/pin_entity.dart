import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';


class PinEntity extends CacheEntity {
  @override
  int get isarId => fastHash(pinId);
  final String pinId;
  final double latitude;
  final double longitude;
  final DateTime creationDate;
  final String? description;

  int get creatorFastId => fastHash(creator);
  final String creator; // Assuming this is a userId

  int get groupFastId => fastHash(groupId);


  final String groupId; // Assuming this is a groupId
  final bool isHidden;
  final DateTime? lastSynced;

  PinEntity({
    required this.pinId,
    required this.latitude,
    required this.longitude,
    required this.creationDate,
    this.description,
    required this.creator,
    required this.groupId,
    this.isHidden = false,
    this.lastSynced,
    super.keepAlive,
    super.hits,
    required super.ttl,
    required super.onlySession,
  });

  factory PinEntity.fromDto(
    PinWithOptionalImageDto pinDto, bool onlySession, {
    bool keepAlive = false,
  }) {
    return PinEntity(
      pinId: pinDto.id,
      latitude: pinDto.latitude as double,
      longitude: pinDto.longitude as double,
      creationDate: pinDto.creationDate,
      creator: pinDto.creationUser,
      groupId: pinDto.groupId,
      description: pinDto.description,
      lastSynced: DateTime.now(),
      keepAlive: keepAlive,
      onlySession: onlySession,
      ttl: DateTime.now(),
    );
  }

  PinRequestDto toRequestDto(Uint8List image) {
    return PinRequestDto(
      image: base64Encode(image),
      latitude: latitude,
      longitude: longitude,
      userId: creator,
      groupId: groupId,
      creationDate: creationDate,
      description: description,
    );
  }

  @override
  CacheEntity copyWith({DateTime? ttl, int? hits, bool? keepAlive, bool? onlySession}) {
    return PinEntity(
      pinId: pinId,
      latitude: latitude,
      longitude: longitude,
      creationDate: creationDate,
      description: description,
      creator: creator,
      groupId: groupId,
      isHidden: isHidden,
      lastSynced: lastSynced,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession
    );
  }
}
