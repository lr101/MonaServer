import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:openapi/api.dart';

class GroupEntity extends CacheEntity {
  @override
  int get isarId => fastHash(groupId);

  final String groupId;

  final String name;

  final int visibility;

  bool userIsMember;

  final String? inviteUrl;

  final String? groupAdmin;

  final String? description;

  bool isActivated;

  final DateTime? lastUpdated;

  final String? link;

  final String pinStyle;

  final SeasonEntity? bestSeason;

  GroupEntity({
    required this.groupId,
    required this.name,
    required this.visibility,
    required this.userIsMember,
    this.inviteUrl,
    this.groupAdmin,
    this.description,
    this.isActivated = false,
    this.lastUpdated,
    this.link,
    this.pinStyle = 'classic',
    this.bestSeason,
    super.keepAlive,
    super.hits,
    required super.ttl,
    required super.onlySession,
  });

  factory GroupEntity.fromGroupDto(
    GroupDto groupDto,
    bool onlySession,
    bool userIsMember, {
    bool keepAlive = false,
    bool isActivated = false,
  }) {
    return GroupEntity(
      groupId: groupDto.id,
      name: groupDto.name,
      userIsMember: userIsMember,
      visibility: groupDto.visibility,
      isActivated: isActivated,
      description: groupDto.description,
      inviteUrl: groupDto.inviteUrl,
      groupAdmin: groupDto.groupAdmin,
      lastUpdated: groupDto.lastUpdated,
      bestSeason: groupDto.bestSeason == null
          ? null
          : SeasonEntity.fromDto(groupDto.bestSeason!),
      link: groupDto.link,
      pinStyle: groupDto.pinStyle?.value ?? 'classic',
      keepAlive: keepAlive,
      ttl: DateTime.now(),
      onlySession: onlySession,
    );
  }

  CreateGroupDto toCreateGroupDto(Uint8List image) {
    return CreateGroupDto(
      name: name,
      groupAdmin: groupAdmin!,
      description: description!,
      profileImage: base64Encode(image),
      visibility: visibility,
      link: link,
    );
  }

  static UpdateGroupDtoPinStyleEnum _updatePinStyle(String style) =>
      switch (style) {
        'moss' => UpdateGroupDtoPinStyleEnum.moss,
        'sunset' => UpdateGroupDtoPinStyleEnum.sunset,
        'aurora' => UpdateGroupDtoPinStyleEnum.aurora,
        _ => UpdateGroupDtoPinStyleEnum.classic,
      };

  UpdateGroupDto toUpdateGroupDto(Uint8List? image) {
    return UpdateGroupDto(
      name: name,
      description: description,
      profileImage: image != null ? base64Encode(image) : null,
      visibility: visibility,
      groupAdmin: groupAdmin,
      link: link,
      pinStyle: _updatePinStyle(pinStyle),
    );
  }

  @override
  GroupEntity copyWith({
    DateTime? ttl,
    int? hits,
    bool? keepAlive,
    bool? onlySession,
    String? pinStyle,
  }) {
    return GroupEntity(
      groupId: groupId,
      name: name,
      userIsMember: userIsMember,
      visibility: visibility,
      description: description,
      inviteUrl: inviteUrl,
      groupAdmin: groupAdmin,
      lastUpdated: lastUpdated,
      isActivated: isActivated,
      link: link,
      pinStyle: pinStyle ?? this.pinStyle,
      bestSeason: bestSeason,
      keepAlive: keepAlive ?? this.keepAlive,
      hits: hits ?? this.hits,
      ttl: ttl ?? this.ttl,
      onlySession: onlySession ?? this.onlySession,
    );
  }
}
