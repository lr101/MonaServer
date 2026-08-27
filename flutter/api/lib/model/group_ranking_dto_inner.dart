//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupRankingDtoInner {
  /// Returns a new [GroupRankingDtoInner] instance.
  GroupRankingDtoInner({
    this.groupInfoDto,
    this.rankNr,
    this.points,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  GroupDto? groupInfoDto;

  /// Minimum value: 0
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? rankNr;

  /// Minimum value: 0
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? points;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupRankingDtoInner &&
    other.groupInfoDto == groupInfoDto &&
    other.rankNr == rankNr &&
    other.points == points;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (groupInfoDto == null ? 0 : groupInfoDto!.hashCode) +
    (rankNr == null ? 0 : rankNr!.hashCode) +
    (points == null ? 0 : points!.hashCode);

  @override
  String toString() => 'GroupRankingDtoInner[groupInfoDto=$groupInfoDto, rankNr=$rankNr, points=$points]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.groupInfoDto != null) {
      json[r'groupInfoDto'] = this.groupInfoDto;
    } else {
      json[r'groupInfoDto'] = null;
    }
    if (this.rankNr != null) {
      json[r'rankNr'] = this.rankNr;
    } else {
      json[r'rankNr'] = null;
    }
    if (this.points != null) {
      json[r'points'] = this.points;
    } else {
      json[r'points'] = null;
    }
    return json;
  }

  /// Returns a new [GroupRankingDtoInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupRankingDtoInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupRankingDtoInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupRankingDtoInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupRankingDtoInner(
        groupInfoDto: GroupDto.fromJson(json[r'groupInfoDto']),
        rankNr: mapValueOfType<int>(json, r'rankNr'),
        points: mapValueOfType<int>(json, r'points'),
      );
    }
    return null;
  }

  static List<GroupRankingDtoInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupRankingDtoInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupRankingDtoInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupRankingDtoInner> mapFromJson(dynamic json) {
    final map = <String, GroupRankingDtoInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupRankingDtoInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupRankingDtoInner-objects as value to a dart map
  static Map<String, List<GroupRankingDtoInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupRankingDtoInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupRankingDtoInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

