//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class GroupPinDesignStyle {
  /// Instantiate a new enum with the provided [value].
  const GroupPinDesignStyle._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const classic = GroupPinDesignStyle._(r'classic');
  static const moss = GroupPinDesignStyle._(r'moss');
  static const sunset = GroupPinDesignStyle._(r'sunset');
  static const aurora = GroupPinDesignStyle._(r'aurora');

  /// List of all possible values in this [enum][GroupPinDesignStyle].
  static const values = <GroupPinDesignStyle>[
    classic,
    moss,
    sunset,
    aurora,
  ];

  static GroupPinDesignStyle? fromJson(dynamic value) => GroupPinDesignStyleTypeTransformer().decode(value);

  static List<GroupPinDesignStyle> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupPinDesignStyle>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupPinDesignStyle.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupPinDesignStyle] to String,
/// and [decode] dynamic data back to [GroupPinDesignStyle].
class GroupPinDesignStyleTypeTransformer {
  factory GroupPinDesignStyleTypeTransformer() => _instance ??= const GroupPinDesignStyleTypeTransformer._();

  const GroupPinDesignStyleTypeTransformer._();

  String encode(GroupPinDesignStyle data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupPinDesignStyle.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupPinDesignStyle? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'classic': return GroupPinDesignStyle.classic;
        case r'moss': return GroupPinDesignStyle.moss;
        case r'sunset': return GroupPinDesignStyle.sunset;
        case r'aurora': return GroupPinDesignStyle.aurora;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupPinDesignStyleTypeTransformer] instance.
  static GroupPinDesignStyleTypeTransformer? _instance;
}
