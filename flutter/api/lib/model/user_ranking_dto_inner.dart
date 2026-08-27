//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserRankingDtoInner {
  /// Returns a new [UserRankingDtoInner] instance.
  UserRankingDtoInner({
    this.userInfoDto,
    this.rankNr,
    this.points,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  UserInfoDto? userInfoDto;

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
  bool operator ==(Object other) => identical(this, other) || other is UserRankingDtoInner &&
    other.userInfoDto == userInfoDto &&
    other.rankNr == rankNr &&
    other.points == points;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userInfoDto == null ? 0 : userInfoDto!.hashCode) +
    (rankNr == null ? 0 : rankNr!.hashCode) +
    (points == null ? 0 : points!.hashCode);

  @override
  String toString() => 'UserRankingDtoInner[userInfoDto=$userInfoDto, rankNr=$rankNr, points=$points]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.userInfoDto != null) {
      json[r'userInfoDto'] = this.userInfoDto;
    } else {
      json[r'userInfoDto'] = null;
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

  /// Returns a new [UserRankingDtoInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserRankingDtoInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserRankingDtoInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserRankingDtoInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserRankingDtoInner(
        userInfoDto: UserInfoDto.fromJson(json[r'userInfoDto']),
        rankNr: mapValueOfType<int>(json, r'rankNr'),
        points: mapValueOfType<int>(json, r'points'),
      );
    }
    return null;
  }

  static List<UserRankingDtoInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserRankingDtoInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserRankingDtoInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserRankingDtoInner> mapFromJson(dynamic json) {
    final map = <String, UserRankingDtoInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserRankingDtoInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserRankingDtoInner-objects as value to a dart map
  static Map<String, List<UserRankingDtoInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserRankingDtoInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserRankingDtoInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

