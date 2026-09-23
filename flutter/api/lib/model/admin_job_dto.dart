//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminJobDto {
  /// Returns a new [AdminJobDto] instance.
  AdminJobDto({
    required this.action,
    required this.actorUserId,
    required this.cancellationRequested,
    required this.counts,
    required this.createdAt,
    required this.jobId,
    required this.snapshotId,
    required this.status,
    required this.updatedAt,
  });

  AdminAction action;

  String actorUserId;

  bool cancellationRequested;

  AdminAudienceCountsDto counts;

  DateTime createdAt;

  String jobId;

  String snapshotId;

  AdminJobStatus status;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminJobDto &&
    other.action == action &&
    other.actorUserId == actorUserId &&
    other.cancellationRequested == cancellationRequested &&
    other.counts == counts &&
    other.createdAt == createdAt &&
    other.jobId == jobId &&
    other.snapshotId == snapshotId &&
    other.status == status &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (actorUserId.hashCode) +
    (cancellationRequested.hashCode) +
    (counts.hashCode) +
    (createdAt.hashCode) +
    (jobId.hashCode) +
    (snapshotId.hashCode) +
    (status.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'AdminJobDto[action=$action, actorUserId=$actorUserId, cancellationRequested=$cancellationRequested, counts=$counts, createdAt=$createdAt, jobId=$jobId, snapshotId=$snapshotId, status=$status, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
      json[r'actorUserId'] = this.actorUserId;
      json[r'cancellationRequested'] = this.cancellationRequested;
      json[r'counts'] = this.counts;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
      json[r'jobId'] = this.jobId;
      json[r'snapshotId'] = this.snapshotId;
      json[r'status'] = this.status;
      json[r'updatedAt'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [AdminJobDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminJobDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminJobDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminJobDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminJobDto(
        action: AdminAction.fromJson(json[r'action'])!,
        actorUserId: mapValueOfType<String>(json, r'actorUserId')!,
        cancellationRequested: mapValueOfType<bool>(json, r'cancellationRequested')!,
        counts: AdminAudienceCountsDto.fromJson(json[r'counts'])!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        jobId: mapValueOfType<String>(json, r'jobId')!,
        snapshotId: mapValueOfType<String>(json, r'snapshotId')!,
        status: AdminJobStatus.fromJson(json[r'status'])!,
        updatedAt: mapDateTime(json, r'updatedAt', r'')!,
      );
    }
    return null;
  }

  static List<AdminJobDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminJobDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminJobDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminJobDto> mapFromJson(dynamic json) {
    final map = <String, AdminJobDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminJobDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminJobDto-objects as value to a dart map
  static Map<String, List<AdminJobDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminJobDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminJobDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'actorUserId',
    'cancellationRequested',
    'counts',
    'createdAt',
    'jobId',
    'snapshotId',
    'status',
    'updatedAt',
  };
}

