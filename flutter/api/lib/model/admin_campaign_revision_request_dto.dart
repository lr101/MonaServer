//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminCampaignRevisionRequestDto {
  /// Returns a new [AdminCampaignRevisionRequestDto] instance.
  AdminCampaignRevisionRequestDto({
    required this.expectedRevision,
  });

  /// Minimum value: 1
  int expectedRevision;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminCampaignRevisionRequestDto &&
    other.expectedRevision == expectedRevision;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode);

  @override
  String toString() => 'AdminCampaignRevisionRequestDto[expectedRevision=$expectedRevision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expectedRevision'] = this.expectedRevision;
    return json;
  }

  /// Returns a new [AdminCampaignRevisionRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminCampaignRevisionRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminCampaignRevisionRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminCampaignRevisionRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminCampaignRevisionRequestDto(
        expectedRevision: mapValueOfType<int>(json, r'expectedRevision')!,
      );
    }
    return null;
  }

  static List<AdminCampaignRevisionRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminCampaignRevisionRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminCampaignRevisionRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminCampaignRevisionRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminCampaignRevisionRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminCampaignRevisionRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminCampaignRevisionRequestDto-objects as value to a dart map
  static Map<String, List<AdminCampaignRevisionRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminCampaignRevisionRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminCampaignRevisionRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedRevision',
  };
}
