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
    required this.claimed,
    required this.thresholdValue,
    required this.currentValue,
    required this.thresholdUp,
  });

  int achievementId;

  bool claimed;

  int thresholdValue;

  int currentValue;

  bool thresholdUp;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserAchievementsDtoInner &&
    other.achievementId == achievementId &&
    other.claimed == claimed &&
    other.thresholdValue == thresholdValue &&
    other.currentValue == currentValue &&
    other.thresholdUp == thresholdUp;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (achievementId.hashCode) +
    (claimed.hashCode) +
    (thresholdValue.hashCode) +
    (currentValue.hashCode) +
    (thresholdUp.hashCode);

  @override
  String toString() => 'UserAchievementsDtoInner[achievementId=$achievementId, claimed=$claimed, thresholdValue=$thresholdValue, currentValue=$currentValue, thresholdUp=$thresholdUp]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'achievementId'] = this.achievementId;
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

