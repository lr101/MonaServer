//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinPhotoDto {
  /// Returns a new [PinPhotoDto] instance.
  PinPhotoDto({
    required this.id,
    required this.pinId,
    this.contributorId,
    required this.contributorUsername,
    this.image,
    this.caption,
    required this.observedAt,
    required this.isOriginal,
  });

  String id;

  String pinId;

  String? contributorId;

  String contributorUsername;

  String? image;

  String? caption;

  DateTime observedAt;

  bool isOriginal;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinPhotoDto &&
    other.id == id &&
    other.pinId == pinId &&
    other.contributorId == contributorId &&
    other.contributorUsername == contributorUsername &&
    other.image == image &&
    other.caption == caption &&
    other.observedAt == observedAt &&
    other.isOriginal == isOriginal;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (pinId.hashCode) +
    (contributorId == null ? 0 : contributorId!.hashCode) +
    (contributorUsername.hashCode) +
    (image == null ? 0 : image!.hashCode) +
    (caption == null ? 0 : caption!.hashCode) +
    (observedAt.hashCode) +
    (isOriginal.hashCode);

  @override
  String toString() => 'PinPhotoDto[id=$id, pinId=$pinId, contributorId=$contributorId, contributorUsername=$contributorUsername, image=$image, caption=$caption, observedAt=$observedAt, isOriginal=$isOriginal]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'pinId'] = this.pinId;
    if (this.contributorId != null) {
      json[r'contributorId'] = this.contributorId;
    } else {
      json[r'contributorId'] = null;
    }
      json[r'contributorUsername'] = this.contributorUsername;
    if (this.image != null) {
      json[r'image'] = this.image;
    } else {
      json[r'image'] = null;
    }
    if (this.caption != null) {
      json[r'caption'] = this.caption;
    } else {
      json[r'caption'] = null;
    }
      json[r'observedAt'] = this.observedAt.toUtc().toIso8601String();
      json[r'isOriginal'] = this.isOriginal;
    return json;
  }

  /// Returns a new [PinPhotoDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinPhotoDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinPhotoDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinPhotoDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinPhotoDto(
        id: mapValueOfType<String>(json, r'id')!,
        pinId: mapValueOfType<String>(json, r'pinId')!,
        contributorId: mapValueOfType<String>(json, r'contributorId'),
        contributorUsername: mapValueOfType<String>(json, r'contributorUsername')!,
        image: mapValueOfType<String>(json, r'image'),
        caption: mapValueOfType<String>(json, r'caption'),
        observedAt: mapDateTime(json, r'observedAt', r'')!,
        isOriginal: mapValueOfType<bool>(json, r'isOriginal')!,
      );
    }
    return null;
  }

  static List<PinPhotoDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinPhotoDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinPhotoDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinPhotoDto> mapFromJson(dynamic json) {
    final map = <String, PinPhotoDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinPhotoDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinPhotoDto-objects as value to a dart map
  static Map<String, List<PinPhotoDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinPhotoDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinPhotoDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'pinId',
    'contributorUsername',
    'observedAt',
    'isOriginal',
  };
}
