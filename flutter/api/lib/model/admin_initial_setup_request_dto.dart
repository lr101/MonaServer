//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminInitialSetupRequestDto {
  /// Returns a new [AdminInitialSetupRequestDto] instance.
  AdminInitialSetupRequestDto({
    required this.username,
    required this.password,
    required this.setupToken,
  });

  String username;

  String password;

  String setupToken;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminInitialSetupRequestDto &&
    other.username == username &&
    other.password == password &&
    other.setupToken == setupToken;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (username.hashCode) +
    (password.hashCode) +
    (setupToken.hashCode);

  @override
  String toString() => 'AdminInitialSetupRequestDto[username=$username, password=$password, setupToken=$setupToken]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'username'] = this.username;
      json[r'password'] = this.password;
      json[r'setupToken'] = this.setupToken;
    return json;
  }

  /// Returns a new [AdminInitialSetupRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminInitialSetupRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminInitialSetupRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminInitialSetupRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminInitialSetupRequestDto(
        username: mapValueOfType<String>(json, r'username')!,
        password: mapValueOfType<String>(json, r'password')!,
        setupToken: mapValueOfType<String>(json, r'setupToken')!,
      );
    }
    return null;
  }

  static List<AdminInitialSetupRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminInitialSetupRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminInitialSetupRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminInitialSetupRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminInitialSetupRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminInitialSetupRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminInitialSetupRequestDto-objects as value to a dart map
  static Map<String, List<AdminInitialSetupRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminInitialSetupRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminInitialSetupRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'username',
    'password',
    'setupToken',
  };
}
