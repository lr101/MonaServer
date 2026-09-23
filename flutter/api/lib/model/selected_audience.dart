//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SelectedAudience {
  /// Returns a new [SelectedAudience] instance.
  SelectedAudience({
    this.ids = const [],
    required this.kind,
    required this.resource,
  });

  List<String> ids;

  SelectedAudienceKindEnum kind;

  AudienceResourceKind resource;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SelectedAudience &&
    _deepEquality.equals(other.ids, ids) &&
    other.kind == kind &&
    other.resource == resource;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (ids.hashCode) +
    (kind.hashCode) +
    (resource.hashCode);

  @override
  String toString() => 'SelectedAudience[ids=$ids, kind=$kind, resource=$resource]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'ids'] = this.ids;
      json[r'kind'] = this.kind;
      json[r'resource'] = this.resource;
    return json;
  }

  /// Returns a new [SelectedAudience] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SelectedAudience? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "SelectedAudience[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "SelectedAudience[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return SelectedAudience(
        ids: json[r'ids'] is Iterable
            ? (json[r'ids'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        kind: SelectedAudienceKindEnum.fromJson(json[r'kind'])!,
        resource: AudienceResourceKind.fromJson(json[r'resource'])!,
      );
    }
    return null;
  }

  static List<SelectedAudience> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SelectedAudience>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SelectedAudience.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SelectedAudience> mapFromJson(dynamic json) {
    final map = <String, SelectedAudience>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SelectedAudience.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SelectedAudience-objects as value to a dart map
  static Map<String, List<SelectedAudience>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SelectedAudience>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SelectedAudience.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'ids',
    'kind',
    'resource',
  };
}


class SelectedAudienceKindEnum {
  /// Instantiate a new enum with the provided [value].
  const SelectedAudienceKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const selected = SelectedAudienceKindEnum._(r'selected');

  /// List of all possible values in this [enum][SelectedAudienceKindEnum].
  static const values = <SelectedAudienceKindEnum>[
    selected,
  ];

  static SelectedAudienceKindEnum? fromJson(dynamic value) => SelectedAudienceKindEnumTypeTransformer().decode(value);

  static List<SelectedAudienceKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SelectedAudienceKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SelectedAudienceKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SelectedAudienceKindEnum] to String,
/// and [decode] dynamic data back to [SelectedAudienceKindEnum].
class SelectedAudienceKindEnumTypeTransformer {
  factory SelectedAudienceKindEnumTypeTransformer() => _instance ??= const SelectedAudienceKindEnumTypeTransformer._();

  const SelectedAudienceKindEnumTypeTransformer._();

  String encode(SelectedAudienceKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a SelectedAudienceKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SelectedAudienceKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'selected': return SelectedAudienceKindEnum.selected;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [SelectedAudienceKindEnumTypeTransformer] instance.
  static SelectedAudienceKindEnumTypeTransformer? _instance;
}
