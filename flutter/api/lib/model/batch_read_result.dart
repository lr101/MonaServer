//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BatchReadResult {
  /// Returns a new [BatchReadResult] instance.
  BatchReadResult({
    required this.kind,
    required this.id,
    required this.status,
    this.imageUrl,
    this.user,
    this.likes,
  });

  BatchReadResultKindEnum kind;

  String id;

  int status;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? imageUrl;

  UserInfoDto? user;

  PinLikeDto? likes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BatchReadResult &&
    other.kind == kind &&
    other.id == id &&
    other.status == status &&
    other.imageUrl == imageUrl &&
    other.user == user &&
    other.likes == likes;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode) +
    (status.hashCode) +
    (imageUrl == null ? 0 : imageUrl!.hashCode) +
    (user == null ? 0 : user!.hashCode) +
    (likes == null ? 0 : likes!.hashCode);

  @override
  String toString() => 'BatchReadResult[kind=$kind, id=$id, status=$status, imageUrl=$imageUrl, user=$user, likes=$likes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
      json[r'status'] = this.status;
    if (this.imageUrl != null) {
      json[r'imageUrl'] = this.imageUrl;
    } else {
      json[r'imageUrl'] = null;
    }
    if (this.user != null) {
      json[r'user'] = this.user;
    } else {
      json[r'user'] = null;
    }
    if (this.likes != null) {
      json[r'likes'] = this.likes;
    } else {
      json[r'likes'] = null;
    }
    return json;
  }

  /// Returns a new [BatchReadResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BatchReadResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "BatchReadResult[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "BatchReadResult[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return BatchReadResult(
        kind: BatchReadResultKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
        status: mapValueOfType<int>(json, r'status')!,
        imageUrl: mapValueOfType<String>(json, r'imageUrl'),
        user: UserInfoDto.fromJson(json[r'user']),
        likes: PinLikeDto.fromJson(json[r'likes']),
      );
    }
    return null;
  }

  static List<BatchReadResult> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BatchReadResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BatchReadResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BatchReadResult> mapFromJson(dynamic json) {
    final map = <String, BatchReadResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BatchReadResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BatchReadResult-objects as value to a dart map
  static Map<String, List<BatchReadResult>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BatchReadResult>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BatchReadResult.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
    'status',
  };
}


class BatchReadResultKindEnum {
  /// Instantiate a new enum with the provided [value].
  const BatchReadResultKindEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pinImage = BatchReadResultKindEnum._(r'pinImage');
  static const userImageSmall = BatchReadResultKindEnum._(r'userImageSmall');
  static const userImage = BatchReadResultKindEnum._(r'userImage');
  static const groupImageSmall = BatchReadResultKindEnum._(r'groupImageSmall');
  static const groupImage = BatchReadResultKindEnum._(r'groupImage');
  static const groupPinImage = BatchReadResultKindEnum._(r'groupPinImage');
  static const user = BatchReadResultKindEnum._(r'user');
  static const pinLikes = BatchReadResultKindEnum._(r'pinLikes');

  /// List of all possible values in this [enum][BatchReadResultKindEnum].
  static const values = <BatchReadResultKindEnum>[
    pinImage,
    userImageSmall,
    userImage,
    groupImageSmall,
    groupImage,
    groupPinImage,
    user,
    pinLikes,
  ];

  static BatchReadResultKindEnum? fromJson(dynamic value) => BatchReadResultKindEnumTypeTransformer().decode(value);

  static List<BatchReadResultKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BatchReadResultKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BatchReadResultKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [BatchReadResultKindEnum] to String,
/// and [decode] dynamic data back to [BatchReadResultKindEnum].
class BatchReadResultKindEnumTypeTransformer {
  factory BatchReadResultKindEnumTypeTransformer() => _instance ??= const BatchReadResultKindEnumTypeTransformer._();

  const BatchReadResultKindEnumTypeTransformer._();

  String encode(BatchReadResultKindEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a BatchReadResultKindEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  BatchReadResultKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pinImage': return BatchReadResultKindEnum.pinImage;
        case r'userImageSmall': return BatchReadResultKindEnum.userImageSmall;
        case r'userImage': return BatchReadResultKindEnum.userImage;
        case r'groupImageSmall': return BatchReadResultKindEnum.groupImageSmall;
        case r'groupImage': return BatchReadResultKindEnum.groupImage;
        case r'groupPinImage': return BatchReadResultKindEnum.groupPinImage;
        case r'user': return BatchReadResultKindEnum.user;
        case r'pinLikes': return BatchReadResultKindEnum.pinLikes;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [BatchReadResultKindEnumTypeTransformer] instance.
  static BatchReadResultKindEnumTypeTransformer? _instance;
}


