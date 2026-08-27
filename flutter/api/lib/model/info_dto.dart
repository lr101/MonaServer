//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class InfoDto {
  /// Returns a new [InfoDto] instance.
  InfoDto({
    required this.numUsers,
    required this.numGroups,
    required this.numPins,
  });

  num numUsers;

  num numGroups;

  num numPins;

  @override
  bool operator ==(Object other) => identical(this, other) || other is InfoDto &&
    other.numUsers == numUsers &&
    other.numGroups == numGroups &&
    other.numPins == numPins;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (numUsers.hashCode) +
    (numGroups.hashCode) +
    (numPins.hashCode);

  @override
  String toString() => 'InfoDto[numUsers=$numUsers, numGroups=$numGroups, numPins=$numPins]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'num-users'] = this.numUsers;
      json[r'num-groups'] = this.numGroups;
      json[r'num-pins'] = this.numPins;
    return json;
  }

  /// Returns a new [InfoDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static InfoDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "InfoDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "InfoDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return InfoDto(
        numUsers: num.parse('${json[r'num-users']}'),
        numGroups: num.parse('${json[r'num-groups']}'),
        numPins: num.parse('${json[r'num-pins']}'),
      );
    }
    return null;
  }

  static List<InfoDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <InfoDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = InfoDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, InfoDto> mapFromJson(dynamic json) {
    final map = <String, InfoDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = InfoDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of InfoDto-objects as value to a dart map
  static Map<String, List<InfoDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<InfoDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = InfoDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'num-users',
    'num-groups',
    'num-pins',
  };
}

