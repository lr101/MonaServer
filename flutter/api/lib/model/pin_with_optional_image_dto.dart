//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinWithOptionalImageDto {
  /// Returns a new [PinWithOptionalImageDto] instance.
  PinWithOptionalImageDto({
    required this.id,
    required this.creationDate,
    required this.latitude,
    required this.longitude,
    required this.creationUser,
    this.image,
    required this.groupId,
    this.description,
  });

  String id;

  DateTime creationDate;

  /// Minimum value: -90
  /// Maximum value: 90
  num latitude;

  /// Minimum value: -180
  /// Maximum value: 180
  num longitude;

  String creationUser;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? image;

  String groupId;

  String? description;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinWithOptionalImageDto &&
    other.id == id &&
    other.creationDate == creationDate &&
    other.latitude == latitude &&
    other.longitude == longitude &&
    other.creationUser == creationUser &&
    other.image == image &&
    other.groupId == groupId &&
    other.description == description;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (creationDate.hashCode) +
    (latitude.hashCode) +
    (longitude.hashCode) +
    (creationUser.hashCode) +
    (image == null ? 0 : image!.hashCode) +
    (groupId.hashCode) +
    (description == null ? 0 : description!.hashCode);

  @override
  String toString() => 'PinWithOptionalImageDto[id=$id, creationDate=$creationDate, latitude=$latitude, longitude=$longitude, creationUser=$creationUser, image=$image, groupId=$groupId, description=$description]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'creationDate'] = this.creationDate.toUtc().toIso8601String();
      json[r'latitude'] = this.latitude;
      json[r'longitude'] = this.longitude;
      json[r'creationUser'] = this.creationUser;
    if (this.image != null) {
      json[r'image'] = this.image;
    } else {
      json[r'image'] = null;
    }
      json[r'groupId'] = this.groupId;
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    return json;
  }

  /// Returns a new [PinWithOptionalImageDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinWithOptionalImageDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinWithOptionalImageDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinWithOptionalImageDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinWithOptionalImageDto(
        id: mapValueOfType<String>(json, r'id')!,
        creationDate: mapDateTime(json, r'creationDate', r'')!,
        latitude: num.parse('${json[r'latitude']}'),
        longitude: num.parse('${json[r'longitude']}'),
        creationUser: mapValueOfType<String>(json, r'creationUser')!,
        image: mapValueOfType<String>(json, r'image'),
        groupId: mapValueOfType<String>(json, r'groupId')!,
        description: mapValueOfType<String>(json, r'description'),
      );
    }
    return null;
  }

  static List<PinWithOptionalImageDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinWithOptionalImageDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinWithOptionalImageDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinWithOptionalImageDto> mapFromJson(dynamic json) {
    final map = <String, PinWithOptionalImageDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinWithOptionalImageDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinWithOptionalImageDto-objects as value to a dart map
  static Map<String, List<PinWithOptionalImageDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinWithOptionalImageDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinWithOptionalImageDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'creationDate',
    'latitude',
    'longitude',
    'creationUser',
    'groupId',
  };
}

