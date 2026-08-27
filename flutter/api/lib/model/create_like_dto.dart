//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CreateLikeDto {
  /// Returns a new [CreateLikeDto] instance.
  CreateLikeDto({
    this.like,
    this.likeLocation,
    this.likePhotography,
    this.likeArt,
    required this.userId,
  });

  bool? like;

  bool? likeLocation;

  bool? likePhotography;

  bool? likeArt;

  String userId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateLikeDto &&
    other.like == like &&
    other.likeLocation == likeLocation &&
    other.likePhotography == likePhotography &&
    other.likeArt == likeArt &&
    other.userId == userId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (like == null ? 0 : like!.hashCode) +
    (likeLocation == null ? 0 : likeLocation!.hashCode) +
    (likePhotography == null ? 0 : likePhotography!.hashCode) +
    (likeArt == null ? 0 : likeArt!.hashCode) +
    (userId.hashCode);

  @override
  String toString() => 'CreateLikeDto[like=$like, likeLocation=$likeLocation, likePhotography=$likePhotography, likeArt=$likeArt, userId=$userId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.like != null) {
      json[r'like'] = this.like;
    } else {
      json[r'like'] = null;
    }
    if (this.likeLocation != null) {
      json[r'likeLocation'] = this.likeLocation;
    } else {
      json[r'likeLocation'] = null;
    }
    if (this.likePhotography != null) {
      json[r'likePhotography'] = this.likePhotography;
    } else {
      json[r'likePhotography'] = null;
    }
    if (this.likeArt != null) {
      json[r'likeArt'] = this.likeArt;
    } else {
      json[r'likeArt'] = null;
    }
      json[r'userId'] = this.userId;
    return json;
  }

  /// Returns a new [CreateLikeDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateLikeDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateLikeDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateLikeDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateLikeDto(
        like: mapValueOfType<bool>(json, r'like'),
        likeLocation: mapValueOfType<bool>(json, r'likeLocation'),
        likePhotography: mapValueOfType<bool>(json, r'likePhotography'),
        likeArt: mapValueOfType<bool>(json, r'likeArt'),
        userId: mapValueOfType<String>(json, r'userId')!,
      );
    }
    return null;
  }

  static List<CreateLikeDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateLikeDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateLikeDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateLikeDto> mapFromJson(dynamic json) {
    final map = <String, CreateLikeDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateLikeDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateLikeDto-objects as value to a dart map
  static Map<String, List<CreateLikeDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateLikeDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateLikeDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'userId',
  };
}

