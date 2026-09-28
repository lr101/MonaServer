//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAuditPageDto {
  /// Returns a new [AdminAuditPageDto] instance.
  AdminAuditPageDto({
    this.items = const [],
    this.nextCursor,
  });

  List<AdminAuditEventDto> items;

  String? nextCursor;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAuditPageDto &&
    _deepEquality.equals(other.items, items) &&
    other.nextCursor == nextCursor;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode);

  @override
  String toString() => 'AdminAuditPageDto[items=$items, nextCursor=$nextCursor]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    if (this.nextCursor != null) {
      json[r'nextCursor'] = this.nextCursor;
    } else {
      json[r'nextCursor'] = null;
    }
    return json;
  }

  /// Returns a new [AdminAuditPageDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAuditPageDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAuditPageDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAuditPageDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAuditPageDto(
        items: AdminAuditEventDto.listFromJson(json[r'items']),
        nextCursor: mapValueOfType<String>(json, r'nextCursor'),
      );
    }
    return null;
  }

  static List<AdminAuditPageDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAuditPageDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAuditPageDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAuditPageDto> mapFromJson(dynamic json) {
    final map = <String, AdminAuditPageDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAuditPageDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAuditPageDto-objects as value to a dart map
  static Map<String, List<AdminAuditPageDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAuditPageDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAuditPageDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
  };
}

