//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AudienceResourceKind {
  /// Instantiate a new enum with the provided [value].
  const AudienceResourceKind._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const accounts = AudienceResourceKind._(r'accounts');
  static const reports = AudienceResourceKind._(r'reports');

  /// List of all possible values in this [enum][AudienceResourceKind].
  static const values = <AudienceResourceKind>[
    accounts,
    reports,
  ];

  static AudienceResourceKind? fromJson(dynamic value) => AudienceResourceKindTypeTransformer().decode(value);

  static List<AudienceResourceKind> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AudienceResourceKind>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AudienceResourceKind.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AudienceResourceKind] to String,
/// and [decode] dynamic data back to [AudienceResourceKind].
class AudienceResourceKindTypeTransformer {
  factory AudienceResourceKindTypeTransformer() => _instance ??= const AudienceResourceKindTypeTransformer._();

  const AudienceResourceKindTypeTransformer._();

  String encode(AudienceResourceKind data) => data.value;

  /// Decodes a [dynamic value][data] to a AudienceResourceKind.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AudienceResourceKind? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'accounts': return AudienceResourceKind.accounts;
        case r'reports': return AudienceResourceKind.reports;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AudienceResourceKindTypeTransformer] instance.
  static AudienceResourceKindTypeTransformer? _instance;
}

