//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminJobCreateRequestDto {
  /// Returns a new [AdminJobCreateRequestDto] instance.
  AdminJobCreateRequestDto({
    required this.action,
    required this.payloadHash,
    required this.snapshotId,
  });

  AdminAction action;

  String payloadHash;

  String snapshotId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminJobCreateRequestDto &&
    other.action == action &&
    other.payloadHash == payloadHash &&
    other.snapshotId == snapshotId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (payloadHash.hashCode) +
    (snapshotId.hashCode);

  @override
  String toString() => 'AdminJobCreateRequestDto[action=$action, payloadHash=$payloadHash, snapshotId=$snapshotId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'payloadHash'] = this.payloadHash;
      json[r'snapshotId'] = this.snapshotId;
    return json;
  }

  /// Returns a new [AdminJobCreateRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminJobCreateRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminJobCreateRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminJobCreateRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminJobCreateRequestDto(
        action: AdminAction.fromJson(json[r'action'])!,
        payloadHash: mapValueOfType<String>(json, r'payloadHash')!,
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
      );
    }
    return null;
  }

  static List<AdminJobCreateRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminJobCreateRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminJobCreateRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminJobCreateRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminJobCreateRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminJobCreateRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminJobCreateRequestDto-objects as value to a dart map
  static Map<String, List<AdminJobCreateRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminJobCreateRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminJobCreateRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'payloadHash',
    'snapshotId',
  };
}

