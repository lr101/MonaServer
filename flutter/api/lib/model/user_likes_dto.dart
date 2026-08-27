//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserLikesDto {
  /// Returns a new [UserLikesDto] instance.
  UserLikesDto({
    required this.likeCount,
    required this.likeArtCount,
    required this.likeLocationCount,
    required this.likePhotographyCount,
  });

  int likeCount;

  int likeArtCount;

  int likeLocationCount;

  int likePhotographyCount;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserLikesDto &&
    other.likeCount == likeCount &&
    other.likeArtCount == likeArtCount &&
    other.likeLocationCount == likeLocationCount &&
    other.likePhotographyCount == likePhotographyCount;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (likeCount.hashCode) +
    (likeArtCount.hashCode) +
    (likeLocationCount.hashCode) +
    (likePhotographyCount.hashCode);

  @override
  String toString() => 'UserLikesDto[likeCount=$likeCount, likeArtCount=$likeArtCount, likeLocationCount=$likeLocationCount, likePhotographyCount=$likePhotographyCount]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'likeCount'] = this.likeCount;
      json[r'likeArtCount'] = this.likeArtCount;
      json[r'likeLocationCount'] = this.likeLocationCount;
      json[r'likePhotographyCount'] = this.likePhotographyCount;
    return json;
  }

  /// Returns a new [UserLikesDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserLikesDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserLikesDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserLikesDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserLikesDto(
        likeCount: mapValueOfType<int>(json, r'likeCount')!,
        likeArtCount: mapValueOfType<int>(json, r'likeArtCount')!,
        likeLocationCount: mapValueOfType<int>(json, r'likeLocationCount')!,
        likePhotographyCount: mapValueOfType<int>(json, r'likePhotographyCount')!,
      );
    }
    return null;
  }

  static List<UserLikesDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserLikesDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserLikesDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserLikesDto> mapFromJson(dynamic json) {
    final map = <String, UserLikesDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserLikesDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserLikesDto-objects as value to a dart map
  static Map<String, List<UserLikesDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserLikesDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserLikesDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'likeCount',
    'likeArtCount',
    'likeLocationCount',
    'likePhotographyCount',
  };
}

