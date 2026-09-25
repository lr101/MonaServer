//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupDto {
  /// Returns a new [GroupDto] instance.
  GroupDto({
    required this.id,
    this.description,
    this.inviteUrl,
    required this.name,
    required this.visibility,
    this.groupAdmin,
    this.link,
    this.lastUpdated,
    this.profileImage,
    this.profileImageSmall,
    this.pinImage,
    this.pinStyle,
    this.bestSeason,
  });

  String id;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? description;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? inviteUrl;

  String name;

  /// The visibility of the group. 0 for public, 1 for private
  int visibility;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? groupAdmin;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? link;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? lastUpdated;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImage;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImageSmall;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? pinImage;

  GroupDtoPinStyleEnum? pinStyle;

  SeasonItemDto? bestSeason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupDto &&
    other.id == id &&
    other.description == description &&
    other.inviteUrl == inviteUrl &&
    other.name == name &&
    other.visibility == visibility &&
    other.groupAdmin == groupAdmin &&
    other.link == link &&
    other.lastUpdated == lastUpdated &&
    other.profileImage == profileImage &&
    other.profileImageSmall == profileImageSmall &&
    other.pinImage == pinImage &&
    other.pinStyle == pinStyle &&
    other.bestSeason == bestSeason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (description == null ? 0 : description!.hashCode) +
    (inviteUrl == null ? 0 : inviteUrl!.hashCode) +
    (name.hashCode) +
    (visibility.hashCode) +
    (groupAdmin == null ? 0 : groupAdmin!.hashCode) +
    (link == null ? 0 : link!.hashCode) +
    (lastUpdated == null ? 0 : lastUpdated!.hashCode) +
    (profileImage == null ? 0 : profileImage!.hashCode) +
    (profileImageSmall == null ? 0 : profileImageSmall!.hashCode) +
    (pinImage == null ? 0 : pinImage!.hashCode) +
    (pinStyle == null ? 0 : pinStyle!.hashCode) +
    (bestSeason == null ? 0 : bestSeason!.hashCode);

  @override
  String toString() => 'GroupDto[id=$id, description=$description, inviteUrl=$inviteUrl, name=$name, visibility=$visibility, groupAdmin=$groupAdmin, link=$link, lastUpdated=$lastUpdated, profileImage=$profileImage, profileImageSmall=$profileImageSmall, pinImage=$pinImage, pinStyle=$pinStyle, bestSeason=$bestSeason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    if (this.inviteUrl != null) {
      json[r'invite_url'] = this.inviteUrl;
    } else {
      json[r'invite_url'] = null;
    }
      json[r'name'] = this.name;
      json[r'visibility'] = this.visibility;
    if (this.groupAdmin != null) {
      json[r'group_admin'] = this.groupAdmin;
    } else {
      json[r'group_admin'] = null;
    }
    if (this.link != null) {
      json[r'link'] = this.link;
    } else {
      json[r'link'] = null;
    }
    if (this.lastUpdated != null) {
      json[r'lastUpdated'] = this.lastUpdated!.toUtc().toIso8601String();
    } else {
      json[r'lastUpdated'] = null;
    }
    if (this.profileImage != null) {
      json[r'profileImage'] = this.profileImage;
    } else {
      json[r'profileImage'] = null;
    }
    if (this.profileImageSmall != null) {
      json[r'profileImageSmall'] = this.profileImageSmall;
    } else {
      json[r'profileImageSmall'] = null;
    }
    if (this.pinImage != null) {
      json[r'pinImage'] = this.pinImage;
    } else {
      json[r'pinImage'] = null;
    }
    if (this.pinStyle != null) {
      json[r'pinStyle'] = this.pinStyle;
    } else {
      json[r'pinStyle'] = null;
    }
    if (this.bestSeason != null) {
      json[r'bestSeason'] = this.bestSeason;
    } else {
      json[r'bestSeason'] = null;
    }
    return json;
  }

  /// Returns a new [GroupDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupDto(
        id: mapValueOfType<String>(json, r'id')!,
        description: mapValueOfType<String>(json, r'description'),
        inviteUrl: mapValueOfType<String>(json, r'invite_url'),
        name: mapValueOfType<String>(json, r'name')!,
        visibility: mapValueOfType<int>(json, r'visibility')!,
        groupAdmin: mapValueOfType<String>(json, r'group_admin'),
        link: mapValueOfType<String>(json, r'link'),
        lastUpdated: mapDateTime(json, r'lastUpdated', r''),
        profileImage: mapValueOfType<String>(json, r'profileImage'),
        profileImageSmall: mapValueOfType<String>(json, r'profileImageSmall'),
        pinImage: mapValueOfType<String>(json, r'pinImage'),
        pinStyle: GroupDtoPinStyleEnum.fromJson(json[r'pinStyle']),
        bestSeason: SeasonItemDto.fromJson(json[r'bestSeason']),
      );
    }
    return null;
  }

  static List<GroupDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupDto> mapFromJson(dynamic json) {
    final map = <String, GroupDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupDto-objects as value to a dart map
  static Map<String, List<GroupDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
    'visibility',
  };
}


class GroupDtoPinStyleEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupDtoPinStyleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const classic = GroupDtoPinStyleEnum._(r'classic');
  static const moss = GroupDtoPinStyleEnum._(r'moss');
  static const sunset = GroupDtoPinStyleEnum._(r'sunset');
  static const aurora = GroupDtoPinStyleEnum._(r'aurora');

  /// List of all possible values in this [enum][GroupDtoPinStyleEnum].
  static const values = <GroupDtoPinStyleEnum>[
    classic,
    moss,
    sunset,
    aurora,
  ];

  static GroupDtoPinStyleEnum? fromJson(dynamic value) => GroupDtoPinStyleEnumTypeTransformer().decode(value);

  static List<GroupDtoPinStyleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupDtoPinStyleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupDtoPinStyleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupDtoPinStyleEnum] to String,
/// and [decode] dynamic data back to [GroupDtoPinStyleEnum].
class GroupDtoPinStyleEnumTypeTransformer {
  factory GroupDtoPinStyleEnumTypeTransformer() => _instance ??= const GroupDtoPinStyleEnumTypeTransformer._();

  const GroupDtoPinStyleEnumTypeTransformer._();

  String encode(GroupDtoPinStyleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupDtoPinStyleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupDtoPinStyleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'classic': return GroupDtoPinStyleEnum.classic;
        case r'moss': return GroupDtoPinStyleEnum.moss;
        case r'sunset': return GroupDtoPinStyleEnum.sunset;
        case r'aurora': return GroupDtoPinStyleEnum.aurora;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupDtoPinStyleEnumTypeTransformer] instance.
  static GroupDtoPinStyleEnumTypeTransformer? _instance;
}
