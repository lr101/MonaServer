//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudience {
  /// Returns a new [AdminAudience] instance.
  AdminAudience({
    required this.kind,
    this.ids = const [],
    required this.resource,
    this.filter,
  });

  AudienceKind kind;

  List<String> ids;

  AudienceResourceKind resource;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  AdminUserFilterDto? filter;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudience &&
    other.kind == kind &&
    _deepEquality.equals(other.ids, ids) &&
    other.resource == resource &&
    other.filter == filter;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (ids.hashCode) +
    (resource.hashCode) +
    (filter == null ? 0 : filter!.hashCode);

  @override
  String toString() => 'AdminAudience[kind=$kind, ids=$ids, resource=$resource, filter=$filter]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'ids'] = this.ids;
      json[r'resource'] = this.resource;
    if (this.filter != null) {
      json[r'filter'] = this.filter;
    } else {
      json[r'filter'] = null;
    }
    return json;
  }

  /// Returns a new [AdminAudience] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudience? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudience[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudience[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudience(
        kind: AudienceKind.fromJson(json[r'kind'])!,
        ids: json[r'ids'] is Iterable
            ? (json[r'ids'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        resource: AudienceResourceKind.fromJson(json[r'resource'])!,
        filter: AdminUserFilterDto.fromJson(json[r'filter']),
      );
    }
    return null;
  }

  static List<AdminAudience> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudience>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudience.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudience> mapFromJson(dynamic json) {
    final map = <String, AdminAudience>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudience.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudience-objects as value to a dart map
  static Map<String, List<AdminAudience>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudience>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudience.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'resource',
  };
}

