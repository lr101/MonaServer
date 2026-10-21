//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PhotoResolveRequestDto {
  /// Returns a new [PhotoResolveRequestDto] instance.
  PhotoResolveRequestDto({
    this.photoIds = const [],
  });

  List<String> photoIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoResolveRequestDto &&
          _deepEquality.equals(other.photoIds, photoIds);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (photoIds.hashCode);

  @override
  String toString() => 'PhotoResolveRequestDto[photoIds=$photoIds]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'photoIds'] = this.photoIds;
    return json;
  }

  /// Returns a new [PhotoResolveRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhotoResolveRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "PhotoResolveRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "PhotoResolveRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PhotoResolveRequestDto(
        photoIds: json[r'photoIds'] is Iterable
            ? (json[r'photoIds'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<PhotoResolveRequestDto> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <PhotoResolveRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhotoResolveRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhotoResolveRequestDto> mapFromJson(dynamic json) {
    final map = <String, PhotoResolveRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhotoResolveRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhotoResolveRequestDto-objects as value to a dart map
  static Map<String, List<PhotoResolveRequestDto>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<PhotoResolveRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhotoResolveRequestDto.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'photoIds',
  };
}
