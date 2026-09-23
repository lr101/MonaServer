//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudiencePageDto {
  /// Returns a new [AdminAudiencePageDto] instance.
  AdminAudiencePageDto({
    required this.counts,
    this.exclusions = const [],
    required this.expiresAt,
    this.items = const [],
    this.nextCursor,
    required this.snapshotId,
    required this.status,
  });

  AdminAudienceCountsDto counts;

  List<AdminAudienceExclusionDto> exclusions;

  DateTime expiresAt;

  List<AdminAudienceMemberDto> items;

  String? nextCursor;

  String snapshotId;

  AdminAudiencePageDtoStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudiencePageDto &&
    other.counts == counts &&
    _deepEquality.equals(other.exclusions, exclusions) &&
    other.expiresAt == expiresAt &&
    _deepEquality.equals(other.items, items) &&
    other.nextCursor == nextCursor &&
    other.snapshotId == snapshotId &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (counts.hashCode) +
    (exclusions.hashCode) +
    (expiresAt.hashCode) +
    (items.hashCode) +
    (nextCursor == null ? 0 : nextCursor!.hashCode) +
    (snapshotId.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'AdminAudiencePageDto[counts=$counts, exclusions=$exclusions, expiresAt=$expiresAt, items=$items, nextCursor=$nextCursor, snapshotId=$snapshotId, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'counts'] = this.counts;
      json[r'exclusions'] = this.exclusions;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'items'] = this.items;
    if (this.nextCursor != null) {
      json[r'nextCursor'] = this.nextCursor;
    } else {
      json[r'nextCursor'] = null;
    }
      json[r'snapshotId'] = this.snapshotId;
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AdminAudiencePageDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudiencePageDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudiencePageDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudiencePageDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudiencePageDto(
        counts: AdminAudienceCountsDto.fromJson(json[r'counts'])!,
        exclusions: AdminAudienceExclusionDto.listFromJson(json[r'exclusions']),
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        items: AdminAudienceMemberDto.listFromJson(json[r'items']),
        nextCursor: mapValueOfType<String>(json, r'nextCursor'),
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
        status: AdminAudiencePageDtoStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AdminAudiencePageDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePageDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePageDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudiencePageDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudiencePageDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudiencePageDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudiencePageDto-objects as value to a dart map
  static Map<String, List<AdminAudiencePageDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudiencePageDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudiencePageDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'counts',
    'exclusions',
    'expiresAt',
    'items',
    'snapshotId',
    'status',
  };
}


class AdminAudiencePageDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminAudiencePageDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AdminAudiencePageDtoStatusEnum._(r'pending');
  static const ready = AdminAudiencePageDtoStatusEnum._(r'ready');
  static const expired = AdminAudiencePageDtoStatusEnum._(r'expired');
  static const failed = AdminAudiencePageDtoStatusEnum._(r'failed');

  /// List of all possible values in this [enum][AdminAudiencePageDtoStatusEnum].
  static const values = <AdminAudiencePageDtoStatusEnum>[
    pending,
    ready,
    expired,
    failed,
  ];

  static AdminAudiencePageDtoStatusEnum? fromJson(dynamic value) => AdminAudiencePageDtoStatusEnumTypeTransformer().decode(value);

  static List<AdminAudiencePageDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePageDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePageDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminAudiencePageDtoStatusEnum] to String,
/// and [decode] dynamic data back to [AdminAudiencePageDtoStatusEnum].
class AdminAudiencePageDtoStatusEnumTypeTransformer {
  factory AdminAudiencePageDtoStatusEnumTypeTransformer() => _instance ??= const AdminAudiencePageDtoStatusEnumTypeTransformer._();

  const AdminAudiencePageDtoStatusEnumTypeTransformer._();

  String encode(AdminAudiencePageDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminAudiencePageDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminAudiencePageDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AdminAudiencePageDtoStatusEnum.pending;
        case r'ready': return AdminAudiencePageDtoStatusEnum.ready;
        case r'expired': return AdminAudiencePageDtoStatusEnum.expired;
        case r'failed': return AdminAudiencePageDtoStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminAudiencePageDtoStatusEnumTypeTransformer] instance.
  static AdminAudiencePageDtoStatusEnumTypeTransformer? _instance;
}


