//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudiencePreviewResponseDto {
  /// Returns a new [AdminAudiencePreviewResponseDto] instance.
  AdminAudiencePreviewResponseDto({
    this.action,
    this.actorUserId,
    this.counts,
    this.expiresAt,
    this.exclusions = const [],
    this.jobId,
    this.payloadHash,
    this.resource,
    required this.snapshotId,
    required this.status,
  });

  AdminAction? action;

  String? actorUserId;

  AdminAudienceCountsDto? counts;

  DateTime? expiresAt;

  List<AdminAudienceExclusionDto>? exclusions;

  String? jobId;

  String? payloadHash;

  AudienceResourceKind? resource;

  String snapshotId;

  AdminAudiencePreviewResponseDtoStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudiencePreviewResponseDto &&
    other.action == action &&
    other.actorUserId == actorUserId &&
    other.counts == counts &&
    other.expiresAt == expiresAt &&
    _deepEquality.equals(other.exclusions, exclusions) &&
    other.jobId == jobId &&
    other.payloadHash == payloadHash &&
    other.resource == resource &&
    other.snapshotId == snapshotId &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action == null ? 0 : action!.hashCode) +
    (actorUserId == null ? 0 : actorUserId!.hashCode) +
    (counts == null ? 0 : counts!.hashCode) +
    (expiresAt == null ? 0 : expiresAt!.hashCode) +
    (exclusions == null ? 0 : exclusions!.hashCode) +
    (jobId == null ? 0 : jobId!.hashCode) +
    (payloadHash == null ? 0 : payloadHash!.hashCode) +
    (resource == null ? 0 : resource!.hashCode) +
    (snapshotId.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'AdminAudiencePreviewResponseDto[action=$action, actorUserId=$actorUserId, counts=$counts, expiresAt=$expiresAt, exclusions=$exclusions, jobId=$jobId, payloadHash=$payloadHash, resource=$resource, snapshotId=$snapshotId, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.action != null) {
      json[r'action'] = this.action;
    } else {
      json[r'action'] = null;
    }
    if (this.actorUserId != null) {
      json[r'actorUserId'] = this.actorUserId;
    } else {
      json[r'actorUserId'] = null;
    }
    if (this.counts != null) {
      json[r'counts'] = this.counts;
    } else {
      json[r'counts'] = null;
    }
    if (this.expiresAt != null) {
      json[r'expiresAt'] = this.expiresAt!.toUtc().toIso8601String();
    } else {
      json[r'expiresAt'] = null;
    }
    if (this.exclusions != null) {
      json[r'exclusions'] = this.exclusions;
    } else {
      json[r'exclusions'] = null;
    }
    if (this.jobId != null) {
      json[r'jobId'] = this.jobId;
    } else {
      json[r'jobId'] = null;
    }
    if (this.payloadHash != null) {
      json[r'payloadHash'] = this.payloadHash;
    } else {
      json[r'payloadHash'] = null;
    }
    if (this.resource != null) {
      json[r'resource'] = this.resource;
    } else {
      json[r'resource'] = null;
    }
      json[r'snapshotId'] = this.snapshotId;
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AdminAudiencePreviewResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudiencePreviewResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudiencePreviewResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudiencePreviewResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudiencePreviewResponseDto(
        action: AdminAction.fromJson(json[r'action']),
        actorUserId: mapValueOfType<String>(json, r'actorUserId'),
        counts: AdminAudienceCountsDto.fromJson(json[r'counts']),
        expiresAt: mapDateTime(json, r'expiresAt', r''),
        exclusions: AdminAudienceExclusionDto.listFromJson(json[r'exclusions']),
        jobId: mapValueOfType<String>(json, r'jobId'),
        payloadHash: mapValueOfType<String>(json, r'payloadHash'),
        resource: AudienceResourceKind.fromJson(json[r'resource']),
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
        status: AdminAudiencePreviewResponseDtoStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AdminAudiencePreviewResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudiencePreviewResponseDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudiencePreviewResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudiencePreviewResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudiencePreviewResponseDto-objects as value to a dart map
  static Map<String, List<AdminAudiencePreviewResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudiencePreviewResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudiencePreviewResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'snapshotId',
    'status',
  };
}


class AdminAudiencePreviewResponseDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminAudiencePreviewResponseDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AdminAudiencePreviewResponseDtoStatusEnum._(r'pending');
  static const ready = AdminAudiencePreviewResponseDtoStatusEnum._(r'ready');
  static const expired = AdminAudiencePreviewResponseDtoStatusEnum._(r'expired');
  static const failed = AdminAudiencePreviewResponseDtoStatusEnum._(r'failed');

  /// List of all possible values in this [enum][AdminAudiencePreviewResponseDtoStatusEnum].
  static const values = <AdminAudiencePreviewResponseDtoStatusEnum>[
    pending,
    ready,
    expired,
    failed,
  ];

  static AdminAudiencePreviewResponseDtoStatusEnum? fromJson(dynamic value) => AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer().decode(value);

  static List<AdminAudiencePreviewResponseDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewResponseDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewResponseDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminAudiencePreviewResponseDtoStatusEnum] to String,
/// and [decode] dynamic data back to [AdminAudiencePreviewResponseDtoStatusEnum].
class AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer {
  factory AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer() => _instance ??= const AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer._();

  const AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer._();

  String encode(AdminAudiencePreviewResponseDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminAudiencePreviewResponseDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminAudiencePreviewResponseDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AdminAudiencePreviewResponseDtoStatusEnum.pending;
        case r'ready': return AdminAudiencePreviewResponseDtoStatusEnum.ready;
        case r'expired': return AdminAudiencePreviewResponseDtoStatusEnum.expired;
        case r'failed': return AdminAudiencePreviewResponseDtoStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer] instance.
  static AdminAudiencePreviewResponseDtoStatusEnumTypeTransformer? _instance;
}
