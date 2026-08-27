//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RankingSearchDtoInner {
  /// Returns a new [RankingSearchDtoInner] instance.
  RankingSearchDtoInner({
    required this.adminLevel,
    required this.name,
    required this.gid,
  });

  /// 0: Country, 1: State, 2: County/City
  ///
  /// Minimum value: 0
  /// Maximum value: 2
  int adminLevel;

  /// Name of the country, state or county
  String name;

  /// ID of the country, state or county
  String gid;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RankingSearchDtoInner &&
    other.adminLevel == adminLevel &&
    other.name == name &&
    other.gid == gid;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (adminLevel.hashCode) +
    (name.hashCode) +
    (gid.hashCode);

  @override
  String toString() => 'RankingSearchDtoInner[adminLevel=$adminLevel, name=$name, gid=$gid]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'adminLevel'] = this.adminLevel;
      json[r'name'] = this.name;
      json[r'gid'] = this.gid;
    return json;
  }

  /// Returns a new [RankingSearchDtoInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RankingSearchDtoInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "RankingSearchDtoInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "RankingSearchDtoInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return RankingSearchDtoInner(
        adminLevel: mapValueOfType<int>(json, r'adminLevel')!,
        name: mapValueOfType<String>(json, r'name')!,
        gid: mapValueOfType<String>(json, r'gid')!,
      );
    }
    return null;
  }

  static List<RankingSearchDtoInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RankingSearchDtoInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RankingSearchDtoInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RankingSearchDtoInner> mapFromJson(dynamic json) {
    final map = <String, RankingSearchDtoInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RankingSearchDtoInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RankingSearchDtoInner-objects as value to a dart map
  static Map<String, List<RankingSearchDtoInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RankingSearchDtoInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RankingSearchDtoInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'adminLevel',
    'name',
    'gid',
  };
}

