//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionBootstrapDto {
  /// Returns a new [AdminSessionBootstrapDto] instance.
  AdminSessionBootstrapDto({
    required this.csrfToken,
    required this.expiresAt,
    required this.sessionState,
  });

  String csrfToken;

  DateTime expiresAt;

  AdminSessionState sessionState;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionBootstrapDto &&
    other.csrfToken == csrfToken &&
    other.expiresAt == expiresAt &&
    other.sessionState == sessionState;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (csrfToken.hashCode) +
    (expiresAt.hashCode) +
    (sessionState.hashCode);

  @override
  String toString() => 'AdminSessionBootstrapDto[csrfToken=$csrfToken, expiresAt=$expiresAt, sessionState=$sessionState]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'csrfToken'] = this.csrfToken;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'sessionState'] = this.sessionState;
    return json;
  }

  /// Returns a new [AdminSessionBootstrapDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionBootstrapDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionBootstrapDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionBootstrapDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionBootstrapDto(
        csrfToken: mapValueOfType<String>(json, r'csrfToken')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        sessionState: AdminSessionState.fromJson(json[r'sessionState'])!,
      );
    }
    return null;
  }

  static List<AdminSessionBootstrapDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionBootstrapDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionBootstrapDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionBootstrapDto> mapFromJson(dynamic json) {
    final map = <String, AdminSessionBootstrapDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionBootstrapDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionBootstrapDto-objects as value to a dart map
  static Map<String, List<AdminSessionBootstrapDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionBootstrapDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionBootstrapDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'csrfToken',
    'expiresAt',
    'sessionState',
  };
}

