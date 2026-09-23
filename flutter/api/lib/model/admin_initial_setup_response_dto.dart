//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminInitialSetupResponseDto {
  /// Returns a new [AdminInitialSetupResponseDto] instance.
  AdminInitialSetupResponseDto({
    required this.userId,
    required this.totpSecret,
  });

  String userId;

  String totpSecret;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminInitialSetupResponseDto &&
    other.userId == userId &&
    other.totpSecret == totpSecret;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (totpSecret.hashCode);

  @override
  String toString() => 'AdminInitialSetupResponseDto[userId=$userId, totpSecret=$totpSecret]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'userId'] = this.userId;
      json[r'totpSecret'] = this.totpSecret;
    return json;
  }

  /// Returns a new [AdminInitialSetupResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminInitialSetupResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminInitialSetupResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminInitialSetupResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminInitialSetupResponseDto(
        userId: mapValueOfType<String>(json, r'userId')!,
        totpSecret: mapValueOfType<String>(json, r'totpSecret')!,
      );
    }
    return null;
  }

  static List<AdminInitialSetupResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminInitialSetupResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminInitialSetupResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminInitialSetupResponseDto> mapFromJson(dynamic json) {
    final map = <String, AdminInitialSetupResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminInitialSetupResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminInitialSetupResponseDto-objects as value to a dart map
  static Map<String, List<AdminInitialSetupResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminInitialSetupResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminInitialSetupResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'userId',
    'totpSecret',
  };
}
