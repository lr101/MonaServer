//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinLikeDto {
  /// Returns a new [PinLikeDto] instance.
  PinLikeDto({
    this.likeCount,
    this.likeArtCount,
    this.likeLocationCount,
    this.likePhotographyCount,
    this.likedByUser,
    this.likedArtByUser,
    this.likedLocationByUser,
    this.likedPhotographyByUser,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? likeCount;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? likeArtCount;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? likeLocationCount;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? likePhotographyCount;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? likedByUser;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? likedArtByUser;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? likedLocationByUser;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? likedPhotographyByUser;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinLikeDto &&
    other.likeCount == likeCount &&
    other.likeArtCount == likeArtCount &&
    other.likeLocationCount == likeLocationCount &&
    other.likePhotographyCount == likePhotographyCount &&
    other.likedByUser == likedByUser &&
    other.likedArtByUser == likedArtByUser &&
    other.likedLocationByUser == likedLocationByUser &&
    other.likedPhotographyByUser == likedPhotographyByUser;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (likeCount == null ? 0 : likeCount!.hashCode) +
    (likeArtCount == null ? 0 : likeArtCount!.hashCode) +
    (likeLocationCount == null ? 0 : likeLocationCount!.hashCode) +
    (likePhotographyCount == null ? 0 : likePhotographyCount!.hashCode) +
    (likedByUser == null ? 0 : likedByUser!.hashCode) +
    (likedArtByUser == null ? 0 : likedArtByUser!.hashCode) +
    (likedLocationByUser == null ? 0 : likedLocationByUser!.hashCode) +
    (likedPhotographyByUser == null ? 0 : likedPhotographyByUser!.hashCode);

  @override
  String toString() => 'PinLikeDto[likeCount=$likeCount, likeArtCount=$likeArtCount, likeLocationCount=$likeLocationCount, likePhotographyCount=$likePhotographyCount, likedByUser=$likedByUser, likedArtByUser=$likedArtByUser, likedLocationByUser=$likedLocationByUser, likedPhotographyByUser=$likedPhotographyByUser]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.likeCount != null) {
      json[r'likeCount'] = this.likeCount;
    } else {
      json[r'likeCount'] = null;
    }
    if (this.likeArtCount != null) {
      json[r'likeArtCount'] = this.likeArtCount;
    } else {
      json[r'likeArtCount'] = null;
    }
    if (this.likeLocationCount != null) {
      json[r'likeLocationCount'] = this.likeLocationCount;
    } else {
      json[r'likeLocationCount'] = null;
    }
    if (this.likePhotographyCount != null) {
      json[r'likePhotographyCount'] = this.likePhotographyCount;
    } else {
      json[r'likePhotographyCount'] = null;
    }
    if (this.likedByUser != null) {
      json[r'likedByUser'] = this.likedByUser;
    } else {
      json[r'likedByUser'] = null;
    }
    if (this.likedArtByUser != null) {
      json[r'likedArtByUser'] = this.likedArtByUser;
    } else {
      json[r'likedArtByUser'] = null;
    }
    if (this.likedLocationByUser != null) {
      json[r'likedLocationByUser'] = this.likedLocationByUser;
    } else {
      json[r'likedLocationByUser'] = null;
    }
    if (this.likedPhotographyByUser != null) {
      json[r'likedPhotographyByUser'] = this.likedPhotographyByUser;
    } else {
      json[r'likedPhotographyByUser'] = null;
    }
    return json;
  }

  /// Returns a new [PinLikeDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinLikeDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinLikeDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinLikeDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinLikeDto(
        likeCount: mapValueOfType<int>(json, r'likeCount'),
        likeArtCount: mapValueOfType<int>(json, r'likeArtCount'),
        likeLocationCount: mapValueOfType<int>(json, r'likeLocationCount'),
        likePhotographyCount: mapValueOfType<int>(json, r'likePhotographyCount'),
        likedByUser: mapValueOfType<bool>(json, r'likedByUser'),
        likedArtByUser: mapValueOfType<bool>(json, r'likedArtByUser'),
        likedLocationByUser: mapValueOfType<bool>(json, r'likedLocationByUser'),
        likedPhotographyByUser: mapValueOfType<bool>(json, r'likedPhotographyByUser'),
      );
    }
    return null;
  }

  static List<PinLikeDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinLikeDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinLikeDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinLikeDto> mapFromJson(dynamic json) {
    final map = <String, PinLikeDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinLikeDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinLikeDto-objects as value to a dart map
  static Map<String, List<PinLikeDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinLikeDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinLikeDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

