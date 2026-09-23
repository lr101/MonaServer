//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudiencePreviewDto {
  /// Returns a new [AdminAudiencePreviewDto] instance.
  AdminAudiencePreviewDto({
    required this.action,
    required this.actorUserId,
    required this.counts,
    required this.expiresAt,
    this.exclusions = const [],
    required this.payloadHash,
    required this.resource,
    required this.snapshotId,
    required this.status,
  });

  AdminAction action;

  String actorUserId;

  AdminAudienceCountsDto counts;

  DateTime expiresAt;

  List<AdminAudienceExclusionDto> exclusions;

  String payloadHash;

  AudienceResourceKind resource;

  String snapshotId;

  AdminAudiencePreviewDtoStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudiencePreviewDto &&
    other.action == action &&
    other.actorUserId == actorUserId &&
    other.counts == counts &&
    other.expiresAt == expiresAt &&
    _deepEquality.equals(other.exclusions, exclusions) &&
    other.payloadHash == payloadHash &&
    other.resource == resource &&
    other.snapshotId == snapshotId &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (actorUserId.hashCode) +
    (counts.hashCode) +
    (expiresAt.hashCode) +
    (exclusions.hashCode) +
    (payloadHash.hashCode) +
    (resource.hashCode) +
    (snapshotId.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'AdminAudiencePreviewDto[action=$action, actorUserId=$actorUserId, counts=$counts, expiresAt=$expiresAt, exclusions=$exclusions, payloadHash=$payloadHash, resource=$resource, snapshotId=$snapshotId, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'actorUserId'] = this.actorUserId;
      json[r'counts'] = this.counts;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'exclusions'] = this.exclusions;
      json[r'payloadHash'] = this.payloadHash;
      json[r'resource'] = this.resource;
      json[r'snapshotId'] = this.snapshotId;
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AdminAudiencePreviewDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudiencePreviewDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudiencePreviewDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudiencePreviewDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudiencePreviewDto(
        action: AdminAction.fromJson(json[r'action'])!,
        actorUserId: mapValueOfType<String>(json, r'actorUserId')!,
        counts: AdminAudienceCountsDto.fromJson(json[r'counts'])!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        exclusions: AdminAudienceExclusionDto.listFromJson(json[r'exclusions']),
        payloadHash: mapValueOfType<String>(json, r'payloadHash')!,
        resource: AudienceResourceKind.fromJson(json[r'resource'])!,
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
        status: AdminAudiencePreviewDtoStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AdminAudiencePreviewDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudiencePreviewDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudiencePreviewDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudiencePreviewDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudiencePreviewDto-objects as value to a dart map
  static Map<String, List<AdminAudiencePreviewDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudiencePreviewDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudiencePreviewDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'actorUserId',
    'counts',
    'expiresAt',
    'exclusions',
    'payloadHash',
    'resource',
    'snapshotId',
    'status',
  };
}


class AdminAudiencePreviewDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminAudiencePreviewDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AdminAudiencePreviewDtoStatusEnum._(r'pending');
  static const ready = AdminAudiencePreviewDtoStatusEnum._(r'ready');
  static const expired = AdminAudiencePreviewDtoStatusEnum._(r'expired');
  static const failed = AdminAudiencePreviewDtoStatusEnum._(r'failed');

  /// List of all possible values in this [enum][AdminAudiencePreviewDtoStatusEnum].
  static const values = <AdminAudiencePreviewDtoStatusEnum>[
    pending,
    ready,
    expired,
    failed,
  ];

  static AdminAudiencePreviewDtoStatusEnum? fromJson(dynamic value) => AdminAudiencePreviewDtoStatusEnumTypeTransformer().decode(value);

  static List<AdminAudiencePreviewDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminAudiencePreviewDtoStatusEnum] to String,
/// and [decode] dynamic data back to [AdminAudiencePreviewDtoStatusEnum].
class AdminAudiencePreviewDtoStatusEnumTypeTransformer {
  factory AdminAudiencePreviewDtoStatusEnumTypeTransformer() => _instance ??= const AdminAudiencePreviewDtoStatusEnumTypeTransformer._();

  const AdminAudiencePreviewDtoStatusEnumTypeTransformer._();

  String encode(AdminAudiencePreviewDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminAudiencePreviewDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminAudiencePreviewDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AdminAudiencePreviewDtoStatusEnum.pending;
        case r'ready': return AdminAudiencePreviewDtoStatusEnum.ready;
        case r'expired': return AdminAudiencePreviewDtoStatusEnum.expired;
        case r'failed': return AdminAudiencePreviewDtoStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminAudiencePreviewDtoStatusEnumTypeTransformer] instance.
  static AdminAudiencePreviewDtoStatusEnumTypeTransformer? _instance;
}


