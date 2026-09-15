//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AudienceKind {
  /// Instantiate a new enum with the provided [value].
  const AudienceKind._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const selected = AudienceKind._(r'selected');
  static const filter = AudienceKind._(r'filter');
  static const all = AudienceKind._(r'all');

  /// List of all possible values in this [enum][AudienceKind].
  static const values = <AudienceKind>[
    selected,
    filter,
    all,
  ];

  static AudienceKind? fromJson(dynamic value) => AudienceKindTypeTransformer().decode(value);

  static List<AudienceKind> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AudienceKind>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AudienceKind.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AudienceKind] to String,
/// and [decode] dynamic data back to [AudienceKind].
class AudienceKindTypeTransformer {
  factory AudienceKindTypeTransformer() => _instance ??= const AudienceKindTypeTransformer._();

  const AudienceKindTypeTransformer._();

  String encode(AudienceKind data) => data.value;

  /// Decodes a [dynamic value][data] to a AudienceKind.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AudienceKind? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'selected': return AudienceKind.selected;
        case r'filter': return AudienceKind.filter;
        case r'all': return AudienceKind.all;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AudienceKindTypeTransformer] instance.
  static AudienceKindTypeTransformer? _instance;
}

