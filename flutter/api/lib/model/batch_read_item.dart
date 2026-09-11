//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BatchReadItem {
  /// Returns a new [BatchReadItem] instance.
  BatchReadItem({
    required this.kind,
    required this.id,
  });

  BatchReadItemKindEnum kind;

  String id;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BatchReadItem &&
    other.kind == kind &&
    other.id == id;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode);

  @override
  String toString() => 'BatchReadItem[kind=$kind, id=$id]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
    return json;
  }

  /// Returns a new [BatchReadItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BatchReadItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "BatchReadItem[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "BatchReadItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return BatchReadItem(
        kind: BatchReadItemKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
      );
    }
    return null;
  }

  static List<BatchReadItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BatchReadItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BatchReadItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BatchReadItem> mapFromJson(dynamic json) {
    final map = <String, BatchReadItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BatchReadItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BatchReadItem-objects as value to a dart map
  static Map<String, List<BatchReadItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BatchReadItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BatchReadItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
  };
}


class BatchReadItemKindEnum {
  /// Instantiate a new enum with the provided [value].
  const BatchReadItemKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pinImage = BatchReadItemKindEnum._(r'pinImage');
  static const userImageSmall = BatchReadItemKindEnum._(r'userImageSmall');
  static const userImage = BatchReadItemKindEnum._(r'userImage');
  static const groupImageSmall = BatchReadItemKindEnum._(r'groupImageSmall');
  static const groupImage = BatchReadItemKindEnum._(r'groupImage');
  static const groupPinImage = BatchReadItemKindEnum._(r'groupPinImage');
  static const user = BatchReadItemKindEnum._(r'user');
  static const pinLikes = BatchReadItemKindEnum._(r'pinLikes');

  /// List of all possible values in this [enum][BatchReadItemKindEnum].
  static const values = <BatchReadItemKindEnum>[
    pinImage,
    userImageSmall,
    userImage,
    groupImageSmall,
    groupImage,
    groupPinImage,
    user,
    pinLikes,
  ];

  static BatchReadItemKindEnum? fromJson(dynamic value) => BatchReadItemKindEnumTypeTransformer().decode(value);

  static List<BatchReadItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BatchReadItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BatchReadItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [BatchReadItemKindEnum] to String,
/// and [decode] dynamic data back to [BatchReadItemKindEnum].
class BatchReadItemKindEnumTypeTransformer {
  factory BatchReadItemKindEnumTypeTransformer() => _instance ??= const BatchReadItemKindEnumTypeTransformer._();

  const BatchReadItemKindEnumTypeTransformer._();

  String encode(BatchReadItemKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a BatchReadItemKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  BatchReadItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pinImage': return BatchReadItemKindEnum.pinImage;
        case r'userImageSmall': return BatchReadItemKindEnum.userImageSmall;
        case r'userImage': return BatchReadItemKindEnum.userImage;
        case r'groupImageSmall': return BatchReadItemKindEnum.groupImageSmall;
        case r'groupImage': return BatchReadItemKindEnum.groupImage;
        case r'groupPinImage': return BatchReadItemKindEnum.groupPinImage;
        case r'user': return BatchReadItemKindEnum.user;
        case r'pinLikes': return BatchReadItemKindEnum.pinLikes;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [BatchReadItemKindEnumTypeTransformer] instance.
  static BatchReadItemKindEnumTypeTransformer? _instance;
}


