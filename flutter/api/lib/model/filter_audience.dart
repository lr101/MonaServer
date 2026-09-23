//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FilterAudience {
  /// Returns a new [FilterAudience] instance.
  FilterAudience({
    required this.filter,
    required this.kind,
    required this.resource,
  });

  AdminAudienceFilter filter;

  FilterAudienceKindEnum kind;

  AudienceResourceKind resource;

  @override
  bool operator ==(Object other) => identical(this, other) || other is FilterAudience &&
    other.filter == filter &&
    other.kind == kind &&
    other.resource == resource;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (filter.hashCode) +
    (kind.hashCode) +
    (resource.hashCode);

  @override
  String toString() => 'FilterAudience[filter=$filter, kind=$kind, resource=$resource]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'filter'] = this.filter;
      json[r'kind'] = this.kind;
      json[r'resource'] = this.resource;
    return json;
  }

  /// Returns a new [FilterAudience] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FilterAudience? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "FilterAudience[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "FilterAudience[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return FilterAudience(
        filter: AdminAudienceFilter.fromJson(json[r'filter'])!,
        kind: FilterAudienceKindEnum.fromJson(json[r'kind'])!,
        resource: AudienceResourceKind.fromJson(json[r'resource'])!,
      );
    }
    return null;
  }

  static List<FilterAudience> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FilterAudience>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FilterAudience.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FilterAudience> mapFromJson(dynamic json) {
    final map = <String, FilterAudience>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FilterAudience.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FilterAudience-objects as value to a dart map
  static Map<String, List<FilterAudience>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<FilterAudience>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FilterAudience.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'filter',
    'kind',
    'resource',
  };
}


class FilterAudienceKindEnum {
  /// Instantiate a new enum with the provided [value].
  const FilterAudienceKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const filter = FilterAudienceKindEnum._(r'filter');

  /// List of all possible values in this [enum][FilterAudienceKindEnum].
  static const values = <FilterAudienceKindEnum>[
    filter,
  ];

  static FilterAudienceKindEnum? fromJson(dynamic value) => FilterAudienceKindEnumTypeTransformer().decode(value);

  static List<FilterAudienceKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FilterAudienceKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FilterAudienceKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FilterAudienceKindEnum] to String,
/// and [decode] dynamic data back to [FilterAudienceKindEnum].
class FilterAudienceKindEnumTypeTransformer {
  factory FilterAudienceKindEnumTypeTransformer() => _instance ??= const FilterAudienceKindEnumTypeTransformer._();

  const FilterAudienceKindEnumTypeTransformer._();

  String encode(FilterAudienceKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a FilterAudienceKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FilterAudienceKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'filter': return FilterAudienceKindEnum.filter;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [FilterAudienceKindEnumTypeTransformer] instance.
  static FilterAudienceKindEnumTypeTransformer? _instance;
}
