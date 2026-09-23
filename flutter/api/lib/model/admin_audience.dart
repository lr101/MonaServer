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

  AdminAudienceFilter? filter;

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
    switch (this.kind.value) {
      case 'selected':
        if (this.ids.isEmpty) {
          throw const FormatException('AdminAudience[selected] requires ids.');
        }
        if (this.filter != null) {
          throw const FormatException('Filter is not valid for selected audiences.');
        }
        break;
      case 'filter':
        if (this.filter == null) {
          throw const FormatException('AdminAudience[filter] requires filter.');
        }
        if (this.ids.isNotEmpty) {
          throw const FormatException('IDs are not valid for filter audiences.');
        }
        if (this.filter!.resource != this.resource) {
          throw const FormatException('Audience and filter resources must match.');
        }
        break;
      case 'all':
        if (this.ids.isNotEmpty || this.filter != null) {
          throw const FormatException('All audiences cannot include filter or ids.');
        }
        break;
      default:
        throw FormatException('Unknown AdminAudience kind: ${this.kind.value}');
    }
    final json = <String, dynamic>{};
    json[r'kind'] = this.kind;
    json[r'resource'] = this.resource;
    if (this.kind.value == 'selected') {
      json[r'ids'] = this.ids;
    }
    if (this.kind.value == 'filter' && this.filter != null) {
      json[r'filter'] = this.filter;
    }
    return json;
  }

  /// Returns a new [AdminAudience] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudience? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();
      final kind = AudienceKind.fromJson(json[r'kind']);
      final resource = AudienceResourceKind.fromJson(json[r'resource']);
      if (kind == null) {
        throw const FormatException('AdminAudience requires a valid kind.');
      }
      if (resource == null) {
        throw const FormatException('AdminAudience requires a valid resource.');
      }
      final allowedKeys = <String>{'kind', 'resource'};
      switch (kind.value) {
        case 'selected':
          allowedKeys.add('ids');
          break;
        case 'filter':
          allowedKeys.add('filter');
          break;
        case 'all':
          break;
        default:
          throw FormatException('Unknown AdminAudience kind: ${kind.value}');
      }
      for (final key in json.keys) {
        if (!allowedKeys.contains(key)) {
          throw FormatException('Field "$key" is not valid for ${kind.value} audiences.');
        }
      }
      switch (kind.value) {
        case 'selected':
          final ids = json[r'ids'];
          if (ids is! Iterable || ids.isEmpty ||
              ids.any((id) => id is! String || id.isEmpty)) {
            throw const FormatException('AdminAudience[selected] requires ids.');
          }
          if (json.containsKey(r'filter')) {
            throw const FormatException('Filter is not valid for selected audiences.');
          }
          break;
        case 'filter':
          if (json[r'filter'] is! Map) {
            throw const FormatException('AdminAudience[filter] requires filter.');
          }
          final filter = AdminAudienceFilter.fromJson(json[r'filter']);
          if (filter == null || filter.resource != resource) {
            throw const FormatException('Audience and filter resources must match.');
          }
          break;
        case 'all':
          if (json.containsKey(r'filter') || json.containsKey(r'ids')) {
            throw const FormatException('All audiences cannot include filter or ids.');
          }
          break;
        default:
          throw FormatException('Unknown AdminAudience kind: ${kind.value}');
      }
      return AdminAudience(
        kind: kind,
        ids: json[r'ids'] is Iterable
            ? (json[r'ids'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        resource: resource,
        filter: AdminAudienceFilter.fromJson(json[r'filter']),
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

  static const requiredKeys = <String>{
    'kind',
    'resource',
  };
}
