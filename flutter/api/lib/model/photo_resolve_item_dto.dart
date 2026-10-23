//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PhotoResolveItemDto {
  /// Returns a new [PhotoResolveItemDto] instance.
  PhotoResolveItemDto({
    required this.photoId,
    required this.status,
    this.photo,
  });

  String photoId;

  int status;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  PinPhotoDto? photo;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoResolveItemDto &&
          other.photoId == photoId &&
          other.status == status &&
          other.photo == photo;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (photoId.hashCode) +
      (status.hashCode) +
      (photo == null ? 0 : photo!.hashCode);

  @override
  String toString() =>
      'PhotoResolveItemDto[photoId=$photoId, status=$status, photo=$photo]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'photoId'] = this.photoId;
    json[r'status'] = this.status;
    if (this.photo != null) {
      json[r'photo'] = this.photo;
    } else {
      json[r'photo'] = null;
    }
    return json;
  }

  /// Returns a new [PhotoResolveItemDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhotoResolveItemDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "PhotoResolveItemDto[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "PhotoResolveItemDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PhotoResolveItemDto(
        photoId: mapValueOfType<String>(json, r'photoId')!,
        status: mapValueOfType<int>(json, r'status')!,
        photo: PinPhotoDto.fromJson(json[r'photo']),
      );
    }
    return null;
  }

  static List<PhotoResolveItemDto> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <PhotoResolveItemDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhotoResolveItemDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhotoResolveItemDto> mapFromJson(dynamic json) {
    final map = <String, PhotoResolveItemDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhotoResolveItemDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhotoResolveItemDto-objects as value to a dart map
  static Map<String, List<PhotoResolveItemDto>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<PhotoResolveItemDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhotoResolveItemDto.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'photoId',
    'status',
  };
}
