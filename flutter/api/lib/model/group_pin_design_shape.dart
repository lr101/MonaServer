//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class GroupPinDesignShape {
  /// Instantiate a new enum with the provided [value].
  const GroupPinDesignShape._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const teardrop = GroupPinDesignShape._(r'teardrop');
  static const circle = GroupPinDesignShape._(r'circle');
  static const shield = GroupPinDesignShape._(r'shield');

  /// List of all possible values in this [enum][GroupPinDesignShape].
  static const values = <GroupPinDesignShape>[
    teardrop,
    circle,
    shield,
  ];

  static GroupPinDesignShape? fromJson(dynamic value) => GroupPinDesignShapeTypeTransformer().decode(value);

  static List<GroupPinDesignShape> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <GroupPinDesignShape>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GroupPinDesignShape.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [GroupPinDesignShape] to String,
/// and [decode] dynamic data back to [GroupPinDesignShape].
class GroupPinDesignShapeTypeTransformer {
  factory GroupPinDesignShapeTypeTransformer() => _instance ??= const GroupPinDesignShapeTypeTransformer._();

  const GroupPinDesignShapeTypeTransformer._();

  String encode(GroupPinDesignShape data) => data.value;

  /// Decodes a [dynamic value][data] to a GroupPinDesignShape.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  GroupPinDesignShape? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'teardrop': return GroupPinDesignShape.teardrop;
        case r'circle': return GroupPinDesignShape.circle;
        case r'shield': return GroupPinDesignShape.shield;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [GroupPinDesignShapeTypeTransformer] instance.
  static GroupPinDesignShapeTypeTransformer? _instance;
}
