//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class NearbyPinDto {
  /// Returns a new [NearbyPinDto] instance.
  NearbyPinDto({
    required this.pin,
    required this.distanceMeters,
    required this.groupName,
  });

  PinWithOptionalImageDto pin;

  /// Minimum value: 0
  int distanceMeters;

  String groupName;

  @override
  bool operator ==(Object other) => identical(this, other) || other is NearbyPinDto &&
    other.pin == pin &&
    other.distanceMeters == distanceMeters &&
    other.groupName == groupName;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (pin.hashCode) +
    (distanceMeters.hashCode) +
    (groupName.hashCode);

  @override
  String toString() => 'NearbyPinDto[pin=$pin, distanceMeters=$distanceMeters, groupName=$groupName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'pin'] = this.pin;
      json[r'distanceMeters'] = this.distanceMeters;
      json[r'groupName'] = this.groupName;
    return json;
  }

  /// Returns a new [NearbyPinDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static NearbyPinDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "NearbyPinDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "NearbyPinDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return NearbyPinDto(
        pin: PinWithOptionalImageDto.fromJson(json[r'pin'])!,
        distanceMeters: mapValueOfType<int>(json, r'distanceMeters')!,
        groupName: mapValueOfType<String>(json, r'groupName')!,
      );
    }
    return null;
  }

  static List<NearbyPinDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <NearbyPinDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = NearbyPinDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, NearbyPinDto> mapFromJson(dynamic json) {
    final map = <String, NearbyPinDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = NearbyPinDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of NearbyPinDto-objects as value to a dart map
  static Map<String, List<NearbyPinDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<NearbyPinDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = NearbyPinDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'pin',
    'distanceMeters',
    'groupName',
  };
}
