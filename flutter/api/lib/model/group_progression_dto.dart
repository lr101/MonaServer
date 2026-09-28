//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupProgressionDto {
  /// Returns a new [GroupProgressionDto] instance.
  GroupProgressionDto({
    required this.groupId,
    required this.totalXp,
    required this.currentLevel,
    required this.currentLevelXp,
    required this.nextLevelXp,
  });

  String groupId;

  /// Minimum value: 0
  int totalXp;

  /// Minimum value: 1
  int currentLevel;

  /// Minimum value: 0
  int currentLevelXp;

  /// Minimum value: 0
  int nextLevelXp;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupProgressionDto &&
    other.groupId == groupId &&
    other.totalXp == totalXp &&
    other.currentLevel == currentLevel &&
    other.currentLevelXp == currentLevelXp &&
    other.nextLevelXp == nextLevelXp;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (groupId.hashCode) +
    (totalXp.hashCode) +
    (currentLevel.hashCode) +
    (currentLevelXp.hashCode) +
    (nextLevelXp.hashCode);

  @override
  String toString() => 'GroupProgressionDto[groupId=$groupId, totalXp=$totalXp, currentLevel=$currentLevel, currentLevelXp=$currentLevelXp, nextLevelXp=$nextLevelXp]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'groupId'] = this.groupId;
      json[r'totalXp'] = this.totalXp;
      json[r'currentLevel'] = this.currentLevel;
      json[r'currentLevelXp'] = this.currentLevelXp;
      json[r'nextLevelXp'] = this.nextLevelXp;
    return json;
  }

  /// Returns a new [GroupProgressionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupProgressionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupProgressionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupProgressionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupProgressionDto(
        groupId: mapValueOfType<String>(json, r'groupId')!,
        totalXp: mapValueOfType<int>(json, r'totalXp')!,
        currentLevel: mapValueOfType<int>(json, r'currentLevel')!,
        currentLevelXp: mapValueOfType<int>(json, r'currentLevelXp')!,
        nextLevelXp: mapValueOfType<int>(json, r'nextLevelXp')!,
      );
    }
    return null;
  }

  static List<GroupProgressionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupProgressionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupProgressionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupProgressionDto> mapFromJson(dynamic json) {
    final map = <String, GroupProgressionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupProgressionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupProgressionDto-objects as value to a dart map
  static Map<String, List<GroupProgressionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupProgressionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupProgressionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'groupId',
    'totalXp',
    'currentLevel',
    'currentLevelXp',
    'nextLevelXp',
  };
}
