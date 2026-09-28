//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class GroupPinDesignBadge {
  /// Instantiate a new enum with the provided [value].
  const GroupPinDesignBadge._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const none = GroupPinDesignBadge._(r'none');
  static const star = GroupPinDesignBadge._(r'star');
  static const leaf = GroupPinDesignBadge._(r'leaf');
  static const sun = GroupPinDesignBadge._(r'sun');
  static const spark = GroupPinDesignBadge._(r'spark');

  /// List of all possible values in this [enum][GroupPinDesignBadge].
  static const values = <GroupPinDesignBadge>[
    none,
    star,
    leaf,
    sun,
    spark,
  ];

  static GroupPinDesignBadge? fromJson(dynamic value) => GroupPinDesignBadgeTypeTransformer().decode(value);

  static List<GroupPinDesignBadge> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupPinDesignBadge>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupPinDesignBadge.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupPinDesignBadge] to String,
/// and [decode] dynamic data back to [GroupPinDesignBadge].
class GroupPinDesignBadgeTypeTransformer {
  factory GroupPinDesignBadgeTypeTransformer() => _instance ??= const GroupPinDesignBadgeTypeTransformer._();

  const GroupPinDesignBadgeTypeTransformer._();

  String encode(GroupPinDesignBadge data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupPinDesignBadge.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupPinDesignBadge? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'none': return GroupPinDesignBadge.none;
        case r'star': return GroupPinDesignBadge.star;
        case r'leaf': return GroupPinDesignBadge.leaf;
        case r'sun': return GroupPinDesignBadge.sun;
        case r'spark': return GroupPinDesignBadge.spark;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupPinDesignBadgeTypeTransformer] instance.
  static GroupPinDesignBadgeTypeTransformer? _instance;
}
