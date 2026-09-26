//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ProfileProgressionDto {
  /// Returns a new [ProfileProgressionDto] instance.
  ProfileProgressionDto({
    required this.level,
    required this.fraction,
  });

  /// Minimum value: 1
  int level;

  /// Fraction of XP progress through the current level, from 0 to 1.
  ///
  /// Minimum value: 0
  /// Maximum value: 1
  double fraction;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProfileProgressionDto &&
    other.level == level &&
    other.fraction == fraction;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (level.hashCode) +
    (fraction.hashCode);

  @override
  String toString() => 'ProfileProgressionDto[level=$level, fraction=$fraction]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'level'] = this.level;
      json[r'fraction'] = this.fraction;
    return json;
  }

  /// Returns a new [ProfileProgressionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ProfileProgressionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ProfileProgressionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ProfileProgressionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ProfileProgressionDto(
        level: mapValueOfType<int>(json, r'level')!,
        fraction: mapValueOfType<double>(json, r'fraction')!,
      );
    }
    return null;
  }

  static List<ProfileProgressionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ProfileProgressionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ProfileProgressionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ProfileProgressionDto> mapFromJson(dynamic json) {
    final map = <String, ProfileProgressionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ProfileProgressionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ProfileProgressionDto-objects as value to a dart map
  static Map<String, List<ProfileProgressionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ProfileProgressionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ProfileProgressionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'level',
    'fraction',
  };
}

