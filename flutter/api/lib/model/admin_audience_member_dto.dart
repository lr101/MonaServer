//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudienceMemberDto {
  /// Returns a new [AdminAudienceMemberDto] instance.
  AdminAudienceMemberDto({
    required this.eligible,
    required this.id,
    this.reason,
    required this.resource,
  });

  bool eligible;

  String id;

  String? reason;

  AudienceResourceKind resource;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudienceMemberDto &&
    other.eligible == eligible &&
    other.id == id &&
    other.reason == reason &&
    other.resource == resource;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (eligible.hashCode) +
    (id.hashCode) +
    (reason == null ? 0 : reason!.hashCode) +
    (resource.hashCode);

  @override
  String toString() => 'AdminAudienceMemberDto[eligible=$eligible, id=$id, reason=$reason, resource=$resource]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'eligible'] = this.eligible;
      json[r'id'] = this.id;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
      json[r'resource'] = this.resource;
    return json;
  }

  /// Returns a new [AdminAudienceMemberDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudienceMemberDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudienceMemberDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudienceMemberDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudienceMemberDto(
        eligible: mapValueOfType<bool>(json, r'eligible')!,
        id: mapValueOfType<String>(json, r'id')!,
        reason: mapValueOfType<String>(json, r'reason'),
        resource: AudienceResourceKind.fromJson(json[r'resource'])!,
      );
    }
    return null;
  }

  static List<AdminAudienceMemberDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudienceMemberDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudienceMemberDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudienceMemberDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudienceMemberDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudienceMemberDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudienceMemberDto-objects as value to a dart map
  static Map<String, List<AdminAudienceMemberDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudienceMemberDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudienceMemberDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'eligible',
    'id',
    'resource',
  };
}

