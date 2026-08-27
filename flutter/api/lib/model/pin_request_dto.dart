//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinRequestDto {
  /// Returns a new [PinRequestDto] instance.
  PinRequestDto({
    required this.image,
    required this.latitude,
    required this.longitude,
    required this.userId,
    required this.groupId,
    this.creationDate,
    this.description,
  });

  String image;

  /// Minimum value: -90
  /// Maximum value: 90
  num latitude;

  /// Minimum value: -180
  /// Maximum value: 180
  num longitude;

  String userId;

  String groupId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? creationDate;

  String? description;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinRequestDto &&
    other.image == image &&
    other.latitude == latitude &&
    other.longitude == longitude &&
    other.userId == userId &&
    other.groupId == groupId &&
    other.creationDate == creationDate &&
    other.description == description;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (image.hashCode) +
    (latitude.hashCode) +
    (longitude.hashCode) +
    (userId.hashCode) +
    (groupId.hashCode) +
    (creationDate == null ? 0 : creationDate!.hashCode) +
    (description == null ? 0 : description!.hashCode);

  @override
  String toString() => 'PinRequestDto[image=$image, latitude=$latitude, longitude=$longitude, userId=$userId, groupId=$groupId, creationDate=$creationDate, description=$description]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'image'] = this.image;
      json[r'latitude'] = this.latitude;
      json[r'longitude'] = this.longitude;
      json[r'userId'] = this.userId;
      json[r'groupId'] = this.groupId;
    if (this.creationDate != null) {
      json[r'creationDate'] = this.creationDate!.toUtc().toIso8601String();
    } else {
      json[r'creationDate'] = null;
    }
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    return json;
  }

  /// Returns a new [PinRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinRequestDto(
        image: mapValueOfType<String>(json, r'image')!,
        latitude: num.parse('${json[r'latitude']}'),
        longitude: num.parse('${json[r'longitude']}'),
        userId: mapValueOfType<String>(json, r'userId')!,
        groupId: mapValueOfType<String>(json, r'groupId')!,
        creationDate: mapDateTime(json, r'creationDate', r''),
        description: mapValueOfType<String>(json, r'description'),
      );
    }
    return null;
  }

  static List<PinRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinRequestDto> mapFromJson(dynamic json) {
    final map = <String, PinRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinRequestDto-objects as value to a dart map
  static Map<String, List<PinRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'image',
    'latitude',
    'longitude',
    'userId',
    'groupId',
  };
}

