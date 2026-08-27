//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncDto {
  /// Returns a new [SyncDto] instance.
  SyncDto({
    this.deletedPins = const [],
    this.groupUpdates = const [],
  });

  /// List of ids of deleted pins (unspecific of group)
  List<String> deletedPins;

  /// List of groups and their respective pin changes.
  List<SyncDtoGroupUpdatesInner> groupUpdates;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncDto &&
    _deepEquality.equals(other.deletedPins, deletedPins) &&
    _deepEquality.equals(other.groupUpdates, groupUpdates);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (deletedPins.hashCode) +
    (groupUpdates.hashCode);

  @override
  String toString() => 'SyncDto[deletedPins=$deletedPins, groupUpdates=$groupUpdates]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'deletedPins'] = this.deletedPins;
      json[r'groupUpdates'] = this.groupUpdates;
    return json;
  }

  /// Returns a new [SyncDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncDto(
        deletedPins: json[r'deletedPins'] is Iterable
            ? (json[r'deletedPins'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        groupUpdates: SyncDtoGroupUpdatesInner.listFromJson(json[r'groupUpdates']),
      );
    }
    return null;
  }

  static List<SyncDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncDto> mapFromJson(dynamic json) {
    final map = <String, SyncDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncDto-objects as value to a dart map
  static Map<String, List<SyncDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'deletedPins',
    'groupUpdates',
  };
}

