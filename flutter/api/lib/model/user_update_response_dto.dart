//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UserUpdateResponseDto {
  /// Returns a new [UserUpdateResponseDto] instance.
  UserUpdateResponseDto({
    this.userTokenDto,
    this.profileImageSmall,
    this.profileImage,
    this.userInfoDto,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  TokenResponseDto? userTokenDto;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImageSmall;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? profileImage;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  UserInfoDto? userInfoDto;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UserUpdateResponseDto &&
    other.userTokenDto == userTokenDto &&
    other.profileImageSmall == profileImageSmall &&
    other.profileImage == profileImage &&
    other.userInfoDto == userInfoDto;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userTokenDto == null ? 0 : userTokenDto!.hashCode) +
    (profileImageSmall == null ? 0 : profileImageSmall!.hashCode) +
    (profileImage == null ? 0 : profileImage!.hashCode) +
    (userInfoDto == null ? 0 : userInfoDto!.hashCode);

  @override
  String toString() => 'UserUpdateResponseDto[userTokenDto=$userTokenDto, profileImageSmall=$profileImageSmall, profileImage=$profileImage, userInfoDto=$userInfoDto]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.userTokenDto != null) {
      json[r'userTokenDto'] = this.userTokenDto;
    } else {
      json[r'userTokenDto'] = null;
    }
    if (this.profileImageSmall != null) {
      json[r'profileImageSmall'] = this.profileImageSmall;
    } else {
      json[r'profileImageSmall'] = null;
    }
    if (this.profileImage != null) {
      json[r'profileImage'] = this.profileImage;
    } else {
      json[r'profileImage'] = null;
    }
    if (this.userInfoDto != null) {
      json[r'userInfoDto'] = this.userInfoDto;
    } else {
      json[r'userInfoDto'] = null;
    }
    return json;
  }

  /// Returns a new [UserUpdateResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UserUpdateResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UserUpdateResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UserUpdateResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UserUpdateResponseDto(
        userTokenDto: TokenResponseDto.fromJson(json[r'userTokenDto']),
        profileImageSmall: mapValueOfType<String>(json, r'profileImageSmall'),
        profileImage: mapValueOfType<String>(json, r'profileImage'),
        userInfoDto: UserInfoDto.fromJson(json[r'userInfoDto']),
      );
    }
    return null;
  }

  static List<UserUpdateResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UserUpdateResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UserUpdateResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UserUpdateResponseDto> mapFromJson(dynamic json) {
    final map = <String, UserUpdateResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UserUpdateResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UserUpdateResponseDto-objects as value to a dart map
  static Map<String, List<UserUpdateResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UserUpdateResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UserUpdateResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

