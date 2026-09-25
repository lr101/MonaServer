//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupAchievementsDtoInner {
  /// Returns a new [GroupAchievementsDtoInner] instance.
  GroupAchievementsDtoInner({
    required this.achievementId,
    this.name,
    this.description,
    this.track,
    this.difficulty,
    required this.claimed,
    required this.claimable,
    required this.thresholdValue,
    required this.currentValue,
    required this.thresholdUp,
    required this.rewardPinStyle,
  });

  /// Minimum value: 1
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

  GroupAchievementsDtoInnerDifficultyEnum? difficulty;

  bool claimed;

  bool claimable;

  /// Minimum value: 1
  int thresholdValue;

  /// Minimum value: 0
  int currentValue;

  bool thresholdUp;

  GroupAchievementsDtoInnerRewardPinStyleEnum rewardPinStyle;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupAchievementsDtoInner &&
    other.achievementId == achievementId &&
    other.name == name &&
    other.description == description &&
    other.track == track &&
    other.difficulty == difficulty &&
    other.claimed == claimed &&
    other.claimable == claimable &&
    other.thresholdValue == thresholdValue &&
    other.currentValue == currentValue &&
    other.thresholdUp == thresholdUp &&
    other.rewardPinStyle == rewardPinStyle;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (achievementId.hashCode) +
    (name == null ? 0 : name!.hashCode) +
    (description == null ? 0 : description!.hashCode) +
    (track == null ? 0 : track!.hashCode) +
    (difficulty == null ? 0 : difficulty!.hashCode) +
    (claimed.hashCode) +
    (claimable.hashCode) +
    (thresholdValue.hashCode) +
    (currentValue.hashCode) +
    (thresholdUp.hashCode) +
    (rewardPinStyle.hashCode);

  @override
  String toString() => 'GroupAchievementsDtoInner[achievementId=$achievementId, name=$name, description=$description, track=$track, difficulty=$difficulty, claimed=$claimed, claimable=$claimable, thresholdValue=$thresholdValue, currentValue=$currentValue, thresholdUp=$thresholdUp, rewardPinStyle=$rewardPinStyle]';

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
      json[r'claimed'] = this.claimed;
      json[r'claimable'] = this.claimable;
      json[r'thresholdValue'] = this.thresholdValue;
      json[r'currentValue'] = this.currentValue;
      json[r'thresholdUp'] = this.thresholdUp;
      json[r'rewardPinStyle'] = this.rewardPinStyle;
    return json;
  }

  /// Returns a new [GroupAchievementsDtoInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupAchievementsDtoInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupAchievementsDtoInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupAchievementsDtoInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupAchievementsDtoInner(
        achievementId: mapValueOfType<int>(json, r'achievementId')!,
        name: mapValueOfType<String>(json, r'name'),
        description: mapValueOfType<String>(json, r'description'),
        track: mapValueOfType<String>(json, r'track'),
        difficulty: GroupAchievementsDtoInnerDifficultyEnum.fromJson(json[r'difficulty']),
        claimed: mapValueOfType<bool>(json, r'claimed')!,
        claimable: mapValueOfType<bool>(json, r'claimable')!,
        thresholdValue: mapValueOfType<int>(json, r'thresholdValue')!,
        currentValue: mapValueOfType<int>(json, r'currentValue')!,
        thresholdUp: mapValueOfType<bool>(json, r'thresholdUp')!,
        rewardPinStyle: GroupAchievementsDtoInnerRewardPinStyleEnum.fromJson(json[r'rewardPinStyle'])!,
      );
    }
    return null;
  }

  static List<GroupAchievementsDtoInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupAchievementsDtoInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupAchievementsDtoInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupAchievementsDtoInner> mapFromJson(dynamic json) {
    final map = <String, GroupAchievementsDtoInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupAchievementsDtoInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupAchievementsDtoInner-objects as value to a dart map
  static Map<String, List<GroupAchievementsDtoInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupAchievementsDtoInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupAchievementsDtoInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'achievementId',
    'claimed',
    'claimable',
    'thresholdValue',
    'currentValue',
    'thresholdUp',
    'rewardPinStyle',
  };
}


class GroupAchievementsDtoInnerDifficultyEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupAchievementsDtoInnerDifficultyEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const easy = GroupAchievementsDtoInnerDifficultyEnum._(r'easy');
  static const medium = GroupAchievementsDtoInnerDifficultyEnum._(r'medium');
  static const hard = GroupAchievementsDtoInnerDifficultyEnum._(r'hard');

  /// List of all possible values in this [enum][GroupAchievementsDtoInnerDifficultyEnum].
  static const values = <GroupAchievementsDtoInnerDifficultyEnum>[
    easy,
    medium,
    hard,
  ];

  static GroupAchievementsDtoInnerDifficultyEnum? fromJson(dynamic value) => GroupAchievementsDtoInnerDifficultyEnumTypeTransformer().decode(value);

  static List<GroupAchievementsDtoInnerDifficultyEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupAchievementsDtoInnerDifficultyEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupAchievementsDtoInnerDifficultyEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupAchievementsDtoInnerDifficultyEnum] to String,
/// and [decode] dynamic data back to [GroupAchievementsDtoInnerDifficultyEnum].
class GroupAchievementsDtoInnerDifficultyEnumTypeTransformer {
  factory GroupAchievementsDtoInnerDifficultyEnumTypeTransformer() => _instance ??= const GroupAchievementsDtoInnerDifficultyEnumTypeTransformer._();

  const GroupAchievementsDtoInnerDifficultyEnumTypeTransformer._();

  String encode(GroupAchievementsDtoInnerDifficultyEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupAchievementsDtoInnerDifficultyEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupAchievementsDtoInnerDifficultyEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'easy': return GroupAchievementsDtoInnerDifficultyEnum.easy;
        case r'medium': return GroupAchievementsDtoInnerDifficultyEnum.medium;
        case r'hard': return GroupAchievementsDtoInnerDifficultyEnum.hard;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupAchievementsDtoInnerDifficultyEnumTypeTransformer] instance.
  static GroupAchievementsDtoInnerDifficultyEnumTypeTransformer? _instance;
}



class GroupAchievementsDtoInnerRewardPinStyleEnum {
  /// Instantiate a new enum with the provided [value].
  const GroupAchievementsDtoInnerRewardPinStyleEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const moss = GroupAchievementsDtoInnerRewardPinStyleEnum._(r'moss');
  static const sunset = GroupAchievementsDtoInnerRewardPinStyleEnum._(r'sunset');
  static const aurora = GroupAchievementsDtoInnerRewardPinStyleEnum._(r'aurora');

  /// List of all possible values in this [enum][GroupAchievementsDtoInnerRewardPinStyleEnum].
  static const values = <GroupAchievementsDtoInnerRewardPinStyleEnum>[
    moss,
    sunset,
    aurora,
  ];

  static GroupAchievementsDtoInnerRewardPinStyleEnum? fromJson(dynamic value) => GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer().decode(value);

  static List<GroupAchievementsDtoInnerRewardPinStyleEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupAchievementsDtoInnerRewardPinStyleEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupAchievementsDtoInnerRewardPinStyleEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupAchievementsDtoInnerRewardPinStyleEnum] to String,
/// and [decode] dynamic data back to [GroupAchievementsDtoInnerRewardPinStyleEnum].
class GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer {
  factory GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer() => _instance ??= const GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer._();

  const GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer._();

  String encode(GroupAchievementsDtoInnerRewardPinStyleEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupAchievementsDtoInnerRewardPinStyleEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupAchievementsDtoInnerRewardPinStyleEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'moss': return GroupAchievementsDtoInnerRewardPinStyleEnum.moss;
        case r'sunset': return GroupAchievementsDtoInnerRewardPinStyleEnum.sunset;
        case r'aurora': return GroupAchievementsDtoInnerRewardPinStyleEnum.aurora;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer] instance.
  static GroupAchievementsDtoInnerRewardPinStyleEnumTypeTransformer? _instance;
}
