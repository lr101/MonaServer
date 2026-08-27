//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MapInfoDto {
  /// Returns a new [MapInfoDto] instance.
  MapInfoDto({
    required this.id,
    required this.gid0,
    required this.name0,
    required this.gid1,
    this.name1,
    required this.gid2,
    required this.name2,
  });

  /// A unique identifier for each feature.
  String id;

  /// Country GID.
  String? gid0;

  /// Country name.
  String? name0;

  /// First-level administrative GID.
  String? gid1;

  /// First-level administrative name.
  String? name1;

  /// Second-level administrative GID.
  String? gid2;

  /// Second-level administrative name.
  String? name2;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MapInfoDto &&
    other.id == id &&
    other.gid0 == gid0 &&
    other.name0 == name0 &&
    other.gid1 == gid1 &&
    other.name1 == name1 &&
    other.gid2 == gid2 &&
    other.name2 == name2;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (gid0 == null ? 0 : gid0!.hashCode) +
    (name0 == null ? 0 : name0!.hashCode) +
    (gid1 == null ? 0 : gid1!.hashCode) +
    (name1 == null ? 0 : name1!.hashCode) +
    (gid2 == null ? 0 : gid2!.hashCode) +
    (name2 == null ? 0 : name2!.hashCode);

  @override
  String toString() => 'MapInfoDto[id=$id, gid0=$gid0, name0=$name0, gid1=$gid1, name1=$name1, gid2=$gid2, name2=$name2]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.gid0 != null) {
      json[r'gid0'] = this.gid0;
    } else {
      json[r'gid0'] = null;
    }
    if (this.name0 != null) {
      json[r'name0'] = this.name0;
    } else {
      json[r'name0'] = null;
    }
    if (this.gid1 != null) {
      json[r'gid1'] = this.gid1;
    } else {
      json[r'gid1'] = null;
    }
    if (this.name1 != null) {
      json[r'name1'] = this.name1;
    } else {
      json[r'name1'] = null;
    }
    if (this.gid2 != null) {
      json[r'gid2'] = this.gid2;
    } else {
      json[r'gid2'] = null;
    }
    if (this.name2 != null) {
      json[r'name2'] = this.name2;
    } else {
      json[r'name2'] = null;
    }
    return json;
  }

  /// Returns a new [MapInfoDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MapInfoDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MapInfoDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MapInfoDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MapInfoDto(
        id: mapValueOfType<String>(json, r'id')!,
        gid0: mapValueOfType<String>(json, r'gid0'),
        name0: mapValueOfType<String>(json, r'name0'),
        gid1: mapValueOfType<String>(json, r'gid1'),
        name1: mapValueOfType<String>(json, r'name1'),
        gid2: mapValueOfType<String>(json, r'gid2'),
        name2: mapValueOfType<String>(json, r'name2'),
      );
    }
    return null;
  }

  static List<MapInfoDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MapInfoDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MapInfoDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MapInfoDto> mapFromJson(dynamic json) {
    final map = <String, MapInfoDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MapInfoDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MapInfoDto-objects as value to a dart map
  static Map<String, List<MapInfoDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MapInfoDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MapInfoDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'gid0',
    'name0',
    'gid1',
    'gid2',
    'name2',
  };
}

