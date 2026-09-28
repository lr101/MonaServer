//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminMfaRequestDto {
  /// Returns a new [AdminMfaRequestDto] instance.
  AdminMfaRequestDto({
    required this.challengeId,
    required this.code,
  });

  String challengeId;

  String code;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminMfaRequestDto &&
    other.challengeId == challengeId &&
    other.code == code;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (challengeId.hashCode) +
    (code.hashCode);

  @override
  String toString() => 'AdminMfaRequestDto[challengeId=$challengeId, code=$code]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'challengeId'] = this.challengeId;
      json[r'code'] = this.code;
    return json;
  }

  /// Returns a new [AdminMfaRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminMfaRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminMfaRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminMfaRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminMfaRequestDto(
        challengeId: mapValueOfType<String>(json, r'challengeId')!,
        code: mapValueOfType<String>(json, r'code')!,
      );
    }
    return null;
  }

  static List<AdminMfaRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminMfaRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminMfaRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminMfaRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminMfaRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminMfaRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminMfaRequestDto-objects as value to a dart map
  static Map<String, List<AdminMfaRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminMfaRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminMfaRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'challengeId',
    'code',
  };
}

