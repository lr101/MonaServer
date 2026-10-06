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
  final String? title;
  final String? description;
  final String? imageBlurhash;

  int get creatorFastId => fastHash(creator);
  final String creator; // Assuming this is a userId

  int get groupFastId => fastHash(groupId);

  final String groupId; // Assuming this is a groupId
  final bool isHidden;
  final bool isGone;
  final DateTime? lastSynced;

  /// Set only on transient feed/profile entries for later photographs.
  final String? photoId;
  final String? photoUrl;
  final String? contributorUsername;
  String get entryId => photoId ?? pinId;
  bool get isPhotoUpdate => photoId != null;

  PinEntity({
    required this.pinId,
    required this.latitude,
    required this.longitude,
    required this.creationDate,
    this.title,
    this.description,
    this.imageBlurhash,
    required this.creator,
    required this.groupId,
    this.isHidden = false,
    this.isGone = false,
    this.lastSynced,
    this.photoId,
    this.photoUrl,
    this.contributorUsername,
    super.keepAlive,
    super.hits,
    required super.ttl,
    required super.onlySession,
  });

  factory PinEntity.fromDto(
    PinWithOptionalImageDto pinDto,
    bool onlySession, {
    bool keepAlive = false,
  }) {
    return PinEntity(
      pinId: pinDto.id,
      latitude: pinDto.latitude.toDouble(),
      longitude: pinDto.longitude.toDouble(),
      creationDate: pinDto.creationDate,
      creator: pinDto.creationUser,
      groupId: pinDto.groupId,
      title: pinDto.title,
      description: pinDto.description,
      imageBlurhash: pinDto.imageBlurhash,
      isGone: pinDto.isGone ?? false,
      lastSynced: DateTime.now(),
      keepAlive: keepAlive,
      onlySession: onlySession,
      ttl: DateTime.now(),
    );
  }

  PinEntity withPhotoUpdate(PinPhotoDto photo) => PinEntity(
    pinId: pinId,
    latitude: latitude,
    longitude: longitude,
    creationDate: photo.observedAt,
    title: title,
    description: photo.caption,
    creator: photo.contributorId ?? '',
    groupId: groupId,
    isHidden: isHidden,
    isGone: isGone,
    lastSynced: lastSynced,
    photoId: photo.id,
    photoUrl: photo.image,
    contributorUsername: photo.contributorUsername,
    keepAlive: keepAlive,
    hits: hits,
    ttl: ttl,
    onlySession: onlySession,
  );

  PinRequestDto toRequestDto(Uint8List image) {
    return PinRequestDto(
      image: base64Encode(image),
      latitude: latitude,
      longitude: longitude,
      userId: creator,
      groupId: groupId,
      creationDate: creationDate,
      title: title,
      description: description,
    );
  }

  @override
  CacheEntity copyWith({
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    bool? isGone,
    String? imageBlurhash,
  }) {
    return PinEntity(
      pinId: pinId,
      latitude: latitude,
      longitude: longitude,
      creationDate: creationDate,
      title: title,
      description: description,
      imageBlurhash: imageBlurhash ?? this.imageBlurhash,
      creator: creator,
      groupId: groupId,
      isHidden: isHidden,
      isGone: isGone ?? this.isGone,
      lastSynced: lastSynced,
      photoId: photoId,
      photoUrl: photoUrl,
      contributorUsername: contributorUsername,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      keepAlive: keepAlive ?? this.keepAlive,
      onlySession: onlySession ?? this.onlySession,
    );
  }
}
