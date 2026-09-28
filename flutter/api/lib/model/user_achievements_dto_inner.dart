//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserAchievementsDtoInner {
  /// Returns a new [UserAchievementsDtoInner] instance.
  UserAchievementsDtoInner({
    required this.achievementId,
    this.name,
    this.description,
    this.track,
    this.difficulty,
    this.rewardType,
    this.rewardColor,
    this.rewardXp,
    this.claimable,
    this.rewardAvailable,
    this.definitionVersion,
    required this.claimed,
    required this.thresholdValue,
    required this.currentValue,
    required this.thresholdUp,
  });

  int achievementId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? name;

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
  String? track;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? difficulty;

  /// Each achievement grants exactly one reward category. Easy achievements grant XP, medium achievements grant a color, and hard achievements grant a badge.
  UserAchievementsDtoInnerRewardTypeEnum? rewardType;

  String? rewardColor;

  /// XP amount for XP rewards; omitted for color and badge rewards.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? rewardXp;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? claimable;

  bool? rewardAvailable;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? definitionVersion;

  bool claimed;

  int thresholdValue;

  int currentValue;

  bool thresholdUp;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserAchievementsDtoInner &&
    other.achievementId == achievementId &&
    other.name == name &&
    other.description == description &&
    other.track == track &&
    other.difficulty == difficulty &&
    other.rewardType == rewardType &&
    other.rewardColor == rewardColor &&
    other.rewardXp == rewardXp &&
    other.claimable == claimable &&
    other.rewardAvailable == rewardAvailable &&
    other.definitionVersion == definitionVersion &&
    other.claimed == claimed &&
    other.thresholdValue == thresholdValue &&
    other.currentValue == currentValue &&
    other.thresholdUp == thresholdUp;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (achievementId.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (description == null ? 0 : description!.hashCode) +
    (track == null ? 0 : track!.hashCode) +
    (difficulty == null ? 0 : difficulty!.hashCode) +
    (rewardType == null ? 0 : rewardType!.hashCode) +
    (rewardColor == null ? 0 : rewardColor!.hashCode) +
    (rewardXp == null ? 0 : rewardXp!.hashCode) +
    (claimable == null ? 0 : claimable!.hashCode) +
    (rewardAvailable == null ? 0 : rewardAvailable!.hashCode) +
    (definitionVersion == null ? 0 : definitionVersion!.hashCode) +
    (claimed.hashCode) +
    (thresholdValue.hashCode) +
    (currentValue.hashCode) +
    (thresholdUp.hashCode);

  @override
  String toString() => 'UserAchievementsDtoInner[achievementId=$achievementId, name=$name, description=$description, track=$track, difficulty=$difficulty, rewardType=$rewardType, rewardColor=$rewardColor, rewardXp=$rewardXp, claimable=$claimable, rewardAvailable=$rewardAvailable, definitionVersion=$definitionVersion, claimed=$claimed, thresholdValue=$thresholdValue, currentValue=$currentValue, thresholdUp=$thresholdUp]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'achievementId'] = this.achievementId;
    if (this.name != null) {
      json[r'name'] = this.name;
    } else {
      json[r'name'] = null;
    }
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    if (this.track != null) {
      json[r'track'] = this.track;
    } else {
      json[r'track'] = null;
    }
    if (this.difficulty != null) {
      json[r'difficulty'] = this.difficulty;
    } else {
      json[r'difficulty'] = null;
    }
    if (this.rewardType != null) {
      json[r'rewardType'] = this.rewardType;
    } else {
      json[r'rewardType'] = null;
    }
    if (this.rewardColor != null) {
      json[r'rewardColor'] = this.rewardColor;
    } else {
      json[r'rewardColor'] = null;
    }
    if (this.rewardXp != null) {
      json[r'rewardXp'] = this.rewardXp;
    } else {
      json[r'rewardXp'] = null;
    }
    if (this.claimable != null) {
      json[r'claimable'] = this.claimable;
    } else {
      json[r'claimable'] = null;
    }
    if (this.rewardAvailable != null) {
      json[r'rewardAvailable'] = this.rewardAvailable;
    } else {
      json[r'rewardAvailable'] = null;
    }
    if (this.definitionVersion != null) {
      json[r'definitionVersion'] = this.definitionVersion;
    } else {
      json[r'definitionVersion'] = null;
    }
      json[r'claimed'] = this.claimed;
      json[r'thresholdValue'] = this.thresholdValue;
      json[r'currentValue'] = this.currentValue;
      json[r'thresholdUp'] = this.thresholdUp;
    return json;
  }

  /// Returns a new [UserAchievementsDtoInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserAchievementsDtoInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserAchievementsDtoInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserAchievementsDtoInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserAchievementsDtoInner(
        achievementId: mapValueOfType<int>(json, r'achievementId')!,
        name: mapValueOfType<String>(json, r'name'),
        description: mapValueOfType<String>(json, r'description'),
        track: mapValueOfType<String>(json, r'track'),
        difficulty: mapValueOfType<String>(json, r'difficulty'),
        rewardType: UserAchievementsDtoInnerRewardTypeEnum.fromJson(json[r'rewardType']),
        rewardColor: mapValueOfType<String>(json, r'rewardColor'),
        rewardXp: mapValueOfType<int>(json, r'rewardXp'),
        claimable: mapValueOfType<bool>(json, r'claimable'),
        rewardAvailable: mapValueOfType<bool>(json, r'rewardAvailable'),
        definitionVersion: mapValueOfType<int>(json, r'definitionVersion'),
        claimed: mapValueOfType<bool>(json, r'claimed')!,
        thresholdValue: mapValueOfType<int>(json, r'thresholdValue')!,
        currentValue: mapValueOfType<int>(json, r'currentValue')!,
        thresholdUp: mapValueOfType<bool>(json, r'thresholdUp')!,
      );
    }
    return null;
  }

  static List<UserAchievementsDtoInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserAchievementsDtoInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserAchievementsDtoInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserAchievementsDtoInner> mapFromJson(dynamic json) {
    final map = <String, UserAchievementsDtoInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserAchievementsDtoInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserAchievementsDtoInner-objects as value to a dart map
  static Map<String, List<UserAchievementsDtoInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserAchievementsDtoInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserAchievementsDtoInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'achievementId',
    'claimed',
    'thresholdValue',
    'currentValue',
    'thresholdUp',
  };
}

/// Each achievement grants exactly one reward category. Easy achievements grant XP, medium achievements grant a color, and hard achievements grant a badge.
class UserAchievementsDtoInnerRewardTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const UserAchievementsDtoInnerRewardTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const xp = UserAchievementsDtoInnerRewardTypeEnum._(r'xp');
  static const color = UserAchievementsDtoInnerRewardTypeEnum._(r'color');
  static const badge = UserAchievementsDtoInnerRewardTypeEnum._(r'badge');

  /// List of all possible values in this [enum][UserAchievementsDtoInnerRewardTypeEnum].
  static const values = <UserAchievementsDtoInnerRewardTypeEnum>[
    xp,
    color,
    badge,
  ];

  static UserAchievementsDtoInnerRewardTypeEnum? fromJson(dynamic value) => UserAchievementsDtoInnerRewardTypeEnumTypeTransformer().decode(value);

  static List<UserAchievementsDtoInnerRewardTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserAchievementsDtoInnerRewardTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserAchievementsDtoInnerRewardTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UserAchievementsDtoInnerRewardTypeEnum] to String,
/// and [decode] dynamic data back to [UserAchievementsDtoInnerRewardTypeEnum].
class UserAchievementsDtoInnerRewardTypeEnumTypeTransformer {
  factory UserAchievementsDtoInnerRewardTypeEnumTypeTransformer() => _instance ??= const UserAchievementsDtoInnerRewardTypeEnumTypeTransformer._();

  const UserAchievementsDtoInnerRewardTypeEnumTypeTransformer._();

  String encode(UserAchievementsDtoInnerRewardTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a UserAchievementsDtoInnerRewardTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UserAchievementsDtoInnerRewardTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'xp': return UserAchievementsDtoInnerRewardTypeEnum.xp;
        case r'color': return UserAchievementsDtoInnerRewardTypeEnum.color;
        case r'badge': return UserAchievementsDtoInnerRewardTypeEnum.badge;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [UserAchievementsDtoInnerRewardTypeEnumTypeTransformer] instance.
  static UserAchievementsDtoInnerRewardTypeEnumTypeTransformer? _instance;
}
