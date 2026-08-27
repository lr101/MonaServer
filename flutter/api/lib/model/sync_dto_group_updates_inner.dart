//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncDtoGroupUpdatesInner {
  /// Returns a new [SyncDtoGroupUpdatesInner] instance.
  SyncDtoGroupUpdatesInner({
    required this.group,
    this.pinsAdded = const [],
  });

  GroupDto group;

  List<PinWithOptionalImageDto> pinsAdded;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncDtoGroupUpdatesInner &&
    other.group == group &&
    _deepEquality.equals(other.pinsAdded, pinsAdded);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (group.hashCode) +
    (pinsAdded.hashCode);

  @override
  String toString() => 'SyncDtoGroupUpdatesInner[group=$group, pinsAdded=$pinsAdded]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'group'] = this.group;
      json[r'pinsAdded'] = this.pinsAdded;
    return json;
  }

  /// Returns a new [SyncDtoGroupUpdatesInner] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncDtoGroupUpdatesInner? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SyncDtoGroupUpdatesInner[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SyncDtoGroupUpdatesInner[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SyncDtoGroupUpdatesInner(
        group: GroupDto.fromJson(json[r'group'])!,
        pinsAdded: PinWithOptionalImageDto.listFromJson(json[r'pinsAdded']),
      );
    }
    return null;
  }

  static List<SyncDtoGroupUpdatesInner> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncDtoGroupUpdatesInner>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncDtoGroupUpdatesInner.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncDtoGroupUpdatesInner> mapFromJson(dynamic json) {
    final map = <String, SyncDtoGroupUpdatesInner>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncDtoGroupUpdatesInner.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncDtoGroupUpdatesInner-objects as value to a dart map
  static Map<String, List<SyncDtoGroupUpdatesInner>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncDtoGroupUpdatesInner>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncDtoGroupUpdatesInner.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'group',
    'pinsAdded',
  };
}

