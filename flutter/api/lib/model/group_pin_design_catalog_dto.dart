//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupPinDesignCatalogDto {
  /// Returns a new [GroupPinDesignCatalogDto] instance.
  GroupPinDesignCatalogDto({
    this.designs = const [],
    required this.revision,
  });

  List<GroupPinDesignDto> designs;

  /// Minimum value: 1
  int revision;

  @override
  bool operator ==(Object other) => identical(this, other) || other is GroupPinDesignCatalogDto &&
    _deepEquality.equals(other.designs, designs) &&
    other.revision == revision;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (designs.hashCode) +
    (revision.hashCode);

  @override
  String toString() => 'GroupPinDesignCatalogDto[designs=$designs, revision=$revision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'designs'] = this.designs;
      json[r'revision'] = this.revision;
    return json;
  }

  /// Returns a new [GroupPinDesignCatalogDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GroupPinDesignCatalogDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "GroupPinDesignCatalogDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "GroupPinDesignCatalogDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return GroupPinDesignCatalogDto(
        designs: GroupPinDesignDto.listFromJson(json[r'designs']),
        revision: mapValueOfType<int>(json, r'revision')!,
      );
    }
    return null;
  }

  static List<GroupPinDesignCatalogDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupPinDesignCatalogDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupPinDesignCatalogDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GroupPinDesignCatalogDto> mapFromJson(dynamic json) {
    final map = <String, GroupPinDesignCatalogDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GroupPinDesignCatalogDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GroupPinDesignCatalogDto-objects as value to a dart map
  static Map<String, List<GroupPinDesignCatalogDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<GroupPinDesignCatalogDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GroupPinDesignCatalogDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'designs',
    'revision',
  };
}
