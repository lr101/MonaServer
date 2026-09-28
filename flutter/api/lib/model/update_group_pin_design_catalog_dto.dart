//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UpdateGroupPinDesignCatalogDto {
  /// Returns a new [UpdateGroupPinDesignCatalogDto] instance.
  UpdateGroupPinDesignCatalogDto({
    required this.design,
    required this.expectedRevision,
  });

  GroupPinDesignDto design;

  /// Minimum value: 1
  int expectedRevision;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UpdateGroupPinDesignCatalogDto &&
    other.design == design &&
    other.expectedRevision == expectedRevision;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (design.hashCode) +
    (expectedRevision.hashCode);

  @override
  String toString() => 'UpdateGroupPinDesignCatalogDto[design=$design, expectedRevision=$expectedRevision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'design'] = this.design;
      json[r'expectedRevision'] = this.expectedRevision;
    return json;
  }

  /// Returns a new [UpdateGroupPinDesignCatalogDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UpdateGroupPinDesignCatalogDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "UpdateGroupPinDesignCatalogDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "UpdateGroupPinDesignCatalogDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return UpdateGroupPinDesignCatalogDto(
        design: GroupPinDesignDto.fromJson(json[r'design'])!,
        expectedRevision: mapValueOfType<int>(json, r'expectedRevision')!,
      );
    }
    return null;
  }

  static List<UpdateGroupPinDesignCatalogDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateGroupPinDesignCatalogDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateGroupPinDesignCatalogDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UpdateGroupPinDesignCatalogDto> mapFromJson(dynamic json) {
    final map = <String, UpdateGroupPinDesignCatalogDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UpdateGroupPinDesignCatalogDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UpdateGroupPinDesignCatalogDto-objects as value to a dart map
  static Map<String, List<UpdateGroupPinDesignCatalogDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UpdateGroupPinDesignCatalogDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UpdateGroupPinDesignCatalogDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'design',
    'expectedRevision',
  };
}
