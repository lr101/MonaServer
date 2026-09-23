//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAudiencePreviewAcceptedDto {
  /// Returns a new [AdminAudiencePreviewAcceptedDto] instance.
  AdminAudiencePreviewAcceptedDto({
    required this.jobId,
    required this.snapshotId,
    required this.status,
  });

  String jobId;

  String snapshotId;

  AdminAudiencePreviewAcceptedDtoStatusEnum status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAudiencePreviewAcceptedDto &&
    other.jobId == jobId &&
    other.snapshotId == snapshotId &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (jobId.hashCode) +
    (snapshotId.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'AdminAudiencePreviewAcceptedDto[jobId=$jobId, snapshotId=$snapshotId, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'jobId'] = this.jobId;
      json[r'snapshotId'] = this.snapshotId;
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AdminAudiencePreviewAcceptedDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAudiencePreviewAcceptedDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAudiencePreviewAcceptedDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAudiencePreviewAcceptedDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAudiencePreviewAcceptedDto(
        jobId: mapValueOfType<String>(json, r'jobId')!,
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
        status: AdminAudiencePreviewAcceptedDtoStatusEnum.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AdminAudiencePreviewAcceptedDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewAcceptedDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewAcceptedDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAudiencePreviewAcceptedDto> mapFromJson(dynamic json) {
    final map = <String, AdminAudiencePreviewAcceptedDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAudiencePreviewAcceptedDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAudiencePreviewAcceptedDto-objects as value to a dart map
  static Map<String, List<AdminAudiencePreviewAcceptedDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAudiencePreviewAcceptedDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAudiencePreviewAcceptedDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'jobId',
    'snapshotId',
    'status',
  };
}


class AdminAudiencePreviewAcceptedDtoStatusEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminAudiencePreviewAcceptedDtoStatusEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const pending = AdminAudiencePreviewAcceptedDtoStatusEnum._(r'pending');

  /// List of all possible values in this [enum][AdminAudiencePreviewAcceptedDtoStatusEnum].
  static const values = <AdminAudiencePreviewAcceptedDtoStatusEnum>[
    pending,
  ];

  static AdminAudiencePreviewAcceptedDtoStatusEnum? fromJson(dynamic value) => AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer().decode(value);

  static List<AdminAudiencePreviewAcceptedDtoStatusEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAudiencePreviewAcceptedDtoStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAudiencePreviewAcceptedDtoStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminAudiencePreviewAcceptedDtoStatusEnum] to String,
/// and [decode] dynamic data back to [AdminAudiencePreviewAcceptedDtoStatusEnum].
class AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer {
  factory AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer() => _instance ??= const AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer._();

  const AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer._();

  String encode(AdminAudiencePreviewAcceptedDtoStatusEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminAudiencePreviewAcceptedDtoStatusEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminAudiencePreviewAcceptedDtoStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pending': return AdminAudiencePreviewAcceptedDtoStatusEnum.pending;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer] instance.
  static AdminAudiencePreviewAcceptedDtoStatusEnumTypeTransformer? _instance;
}


