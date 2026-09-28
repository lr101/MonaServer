//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinPhotoRequestDto {
  /// Returns a new [PinPhotoRequestDto] instance.
  PinPhotoRequestDto({
    required this.image,
    required this.idempotencyKey,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.caption,
  });

  /// Base64-encoded JPEG or PNG image.
  String image;

  /// Unique request ID reused when retrying this upload.
  String idempotencyKey;

  /// Minimum value: -90
  /// Maximum value: 90
  num latitude;

  /// Minimum value: -180
  /// Maximum value: 180
  num longitude;

  /// Reported horizontal location accuracy; updates require 50 m or better.
  ///
  /// Minimum value: 0
  /// Maximum value: 50
  num accuracyMeters;

  String? caption;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinPhotoRequestDto &&
    other.image == image &&
    other.idempotencyKey == idempotencyKey &&
    other.latitude == latitude &&
    other.longitude == longitude &&
    other.accuracyMeters == accuracyMeters &&
    other.caption == caption;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (image.hashCode) +
    (idempotencyKey.hashCode) +
    (latitude.hashCode) +
    (longitude.hashCode) +
    (accuracyMeters.hashCode) +
    (caption == null ? 0 : caption!.hashCode);

  @override
  String toString() => 'PinPhotoRequestDto[image=$image, idempotencyKey=$idempotencyKey, latitude=$latitude, longitude=$longitude, accuracyMeters=$accuracyMeters, caption=$caption]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'image'] = this.image;
      json[r'idempotencyKey'] = this.idempotencyKey;
      json[r'latitude'] = this.latitude;
      json[r'longitude'] = this.longitude;
      json[r'accuracyMeters'] = this.accuracyMeters;
    if (this.caption != null) {
      json[r'caption'] = this.caption;
    } else {
      json[r'caption'] = null;
    }
    return json;
  }

  /// Returns a new [PinPhotoRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinPhotoRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinPhotoRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinPhotoRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinPhotoRequestDto(
        image: mapValueOfType<String>(json, r'image')!,
        idempotencyKey: mapValueOfType<String>(json, r'idempotencyKey')!,
        latitude: num.parse('${json[r'latitude']}'),
        longitude: num.parse('${json[r'longitude']}'),
        accuracyMeters: num.parse('${json[r'accuracyMeters']}'),
        caption: mapValueOfType<String>(json, r'caption'),
      );
    }
    return null;
  }

  static List<PinPhotoRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinPhotoRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinPhotoRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinPhotoRequestDto> mapFromJson(dynamic json) {
    final map = <String, PinPhotoRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinPhotoRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinPhotoRequestDto-objects as value to a dart map
  static Map<String, List<PinPhotoRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinPhotoRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinPhotoRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'image',
    'idempotencyKey',
    'latitude',
    'longitude',
    'accuracyMeters',
  };
}
