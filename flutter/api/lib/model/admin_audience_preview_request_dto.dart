//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudiencePreviewRequestDto {
  /// Returns a new [AdminAudiencePreviewRequestDto] instance.
  AdminAudiencePreviewRequestDto({
    required this.action,
    required this.audience,
  });

  AdminAction action;

  AdminAudience audience;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudiencePreviewRequestDto &&
    other.action == action &&
    other.audience == audience;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (audience.hashCode);

  @override
  String toString() => 'AdminAudiencePreviewRequestDto[action=$action, audience=$audience]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'audience'] = this.audience;
    return json;
  }

  /// Returns a new [AdminAudiencePreviewRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudiencePreviewRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudiencePreviewRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudiencePreviewRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudiencePreviewRequestDto(
        action: AdminAction.fromJson(json[r'action'])!,
        audience: AdminAudience.fromJson(json[r'audience'])!,
      );
    }
    return null;
  }

  static List<AdminAudiencePreviewRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudiencePreviewRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudiencePreviewRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudiencePreviewRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudiencePreviewRequestDto-objects as value to a dart map
  static Map<String, List<AdminAudiencePreviewRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudiencePreviewRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudiencePreviewRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'audience',
  };
}

