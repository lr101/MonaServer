//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PinsSyncDto {
  /// Returns a new [PinsSyncDto] instance.
  PinsSyncDto({
    this.syncCursor,
    this.items = const [],
    this.deleted = const [],
  });

  /// Server timestamp for incremental pin synchronization. Use as the next updatedAfter value.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? syncCursor;

  List<PinWithOptionalImageDto> items;

  List<String> deleted;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PinsSyncDto &&
    other.syncCursor == syncCursor &&
    _deepEquality.equals(other.items, items) &&
    _deepEquality.equals(other.deleted, deleted);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (syncCursor == null ? 0 : syncCursor!.hashCode) +
    (items.hashCode) +
    (deleted.hashCode);

  @override
  String toString() => 'PinsSyncDto[syncCursor=$syncCursor, items=$items, deleted=$deleted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.syncCursor != null) {
      json[r'syncCursor'] = this.syncCursor!.toUtc().toIso8601String();
    } else {
      json[r'syncCursor'] = null;
    }
      json[r'items'] = this.items;
      json[r'deleted'] = this.deleted;
    return json;
  }

  /// Returns a new [PinsSyncDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PinsSyncDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "PinsSyncDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "PinsSyncDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return PinsSyncDto(
        syncCursor: mapDateTime(json, r'syncCursor', r''),
        items: PinWithOptionalImageDto.listFromJson(json[r'items']),
        deleted: json[r'deleted'] is Iterable
            ? (json[r'deleted'] as Iterable).cast<String>().toList(growable: false)
            : const [],
      );
    }
    return null;
  }

  static List<PinsSyncDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PinsSyncDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PinsSyncDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PinsSyncDto> mapFromJson(dynamic json) {
    final map = <String, PinsSyncDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PinsSyncDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PinsSyncDto-objects as value to a dart map
  static Map<String, List<PinsSyncDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PinsSyncDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PinsSyncDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'deleted',
  };
}

