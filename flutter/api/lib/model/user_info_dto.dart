//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserInfoDto {
  /// Returns a new [UserInfoDto] instance.
  UserInfoDto({
    required this.username,
    required this.userId,
    this.description,
    this.selectedBatch,
    this.bestSeason,
    this.isMessagingRegistered,
  });

  String username;

  String userId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? description;

  int? selectedBatch;

  SeasonItemDto? bestSeason;

  /// Flag for whether the user registered to receive push messages. Only set for the current user.
  bool? isMessagingRegistered;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserInfoDto &&
    other.username == username &&
    other.userId == userId &&
    other.description == description &&
    other.selectedBatch == selectedBatch &&
    other.bestSeason == bestSeason &&
    other.isMessagingRegistered == isMessagingRegistered;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (username.hashCode) +
    (userId.hashCode) +
    (description == null ? 0 : description!.hashCode) +
    (selectedBatch == null ? 0 : selectedBatch!.hashCode) +
    (bestSeason == null ? 0 : bestSeason!.hashCode) +
    (isMessagingRegistered == null ? 0 : isMessagingRegistered!.hashCode);

  @override
  String toString() => 'UserInfoDto[username=$username, userId=$userId, description=$description, selectedBatch=$selectedBatch, bestSeason=$bestSeason, isMessagingRegistered=$isMessagingRegistered]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'username'] = this.username;
      json[r'userId'] = this.userId;
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
    }
    if (this.selectedBatch != null) {
      json[r'selectedBatch'] = this.selectedBatch;
    } else {
      json[r'selectedBatch'] = null;
    }
    if (this.bestSeason != null) {
      json[r'bestSeason'] = this.bestSeason;
    } else {
      json[r'bestSeason'] = null;
    }
    if (this.isMessagingRegistered != null) {
      json[r'isMessagingRegistered'] = this.isMessagingRegistered;
    } else {
      json[r'isMessagingRegistered'] = null;
    }
    return json;
  }

  /// Returns a new [UserInfoDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserInfoDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserInfoDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserInfoDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserInfoDto(
        username: mapValueOfType<String>(json, r'username')!,
        userId: mapValueOfType<String>(json, r'userId')!,
        description: mapValueOfType<String>(json, r'description'),
        selectedBatch: mapValueOfType<int>(json, r'selectedBatch'),
        bestSeason: SeasonItemDto.fromJson(json[r'bestSeason']),
        isMessagingRegistered: mapValueOfType<bool>(json, r'isMessagingRegistered'),
      );
    }
    return null;
  }

  static List<UserInfoDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserInfoDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserInfoDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserInfoDto> mapFromJson(dynamic json) {
    final map = <String, UserInfoDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserInfoDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserInfoDto-objects as value to a dart map
  static Map<String, List<UserInfoDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserInfoDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserInfoDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'username',
    'userId',
  };
}

