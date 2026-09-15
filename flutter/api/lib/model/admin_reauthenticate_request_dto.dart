//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReauthenticateRequestDto {
  /// Returns a new [AdminReauthenticateRequestDto] instance.
  AdminReauthenticateRequestDto({
    required this.action,
    required this.code,
  });

  AdminActionKind action;

  String code;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReauthenticateRequestDto &&
    other.action == action &&
    other.code == code;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (code.hashCode);

  @override
  String toString() => 'AdminReauthenticateRequestDto[action=$action, code=$code]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'code'] = this.code;
    return json;
  }

  /// Returns a new [AdminReauthenticateRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReauthenticateRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReauthenticateRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReauthenticateRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReauthenticateRequestDto(
        action: AdminActionKind.fromJson(json[r'action'])!,
        code: mapValueOfType<String>(json, r'code')!,
      );
    }
    return null;
  }

  static List<AdminReauthenticateRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReauthenticateRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReauthenticateRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReauthenticateRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminReauthenticateRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReauthenticateRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReauthenticateRequestDto-objects as value to a dart map
  static Map<String, List<AdminReauthenticateRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReauthenticateRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReauthenticateRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'code',
  };
}

