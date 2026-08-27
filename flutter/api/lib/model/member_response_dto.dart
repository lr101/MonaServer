//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MemberResponseDto {
  /// Returns a new [MemberResponseDto] instance.
  MemberResponseDto({
    required this.userId,
    required this.username,
    required this.ranking,
    this.profileImageSmall,
    this.selectedBatch,
  });

  String userId;

  String username;

  int ranking;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImageSmall;

  int? selectedBatch;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MemberResponseDto &&
    other.userId == userId &&
    other.username == username &&
    other.ranking == ranking &&
    other.profileImageSmall == profileImageSmall &&
    other.selectedBatch == selectedBatch;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (username.hashCode) +
    (ranking.hashCode) +
    (profileImageSmall == null ? 0 : profileImageSmall!.hashCode) +
    (selectedBatch == null ? 0 : selectedBatch!.hashCode);

  @override
  String toString() => 'MemberResponseDto[userId=$userId, username=$username, ranking=$ranking, profileImageSmall=$profileImageSmall, selectedBatch=$selectedBatch]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'userId'] = this.userId;
      json[r'username'] = this.username;
      json[r'ranking'] = this.ranking;
    if (this.profileImageSmall != null) {
      json[r'profile_image_small'] = this.profileImageSmall;
    } else {
      json[r'profile_image_small'] = null;
    }
    if (this.selectedBatch != null) {
      json[r'selectedBatch'] = this.selectedBatch;
    } else {
      json[r'selectedBatch'] = null;
    }
    return json;
  }

  /// Returns a new [MemberResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MemberResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "MemberResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "MemberResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return MemberResponseDto(
        userId: mapValueOfType<String>(json, r'userId')!,
        username: mapValueOfType<String>(json, r'username')!,
        ranking: mapValueOfType<int>(json, r'ranking')!,
        profileImageSmall: mapValueOfType<String>(json, r'profile_image_small'),
        selectedBatch: mapValueOfType<int>(json, r'selectedBatch'),
      );
    }
    return null;
  }

  static List<MemberResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MemberResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MemberResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MemberResponseDto> mapFromJson(dynamic json) {
    final map = <String, MemberResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MemberResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MemberResponseDto-objects as value to a dart map
  static Map<String, List<MemberResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MemberResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MemberResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'userId',
    'username',
    'ranking',
  };
}

