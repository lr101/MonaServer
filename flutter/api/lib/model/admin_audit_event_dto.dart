//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAuditEventDto {
  /// Returns a new [AdminAuditEventDto] instance.
  AdminAuditEventDto({
    required this.action,
    this.actorUserId,
    this.details = const {},
    required this.id,
    required this.occurredAt,
    required this.outcome,
    this.reason,
    this.targetUserId,
  });

  AdminActionKind action;

  String? actorUserId;

  Map<String, String> details;

  String id;

  DateTime occurredAt;

  String outcome;

  String? reason;

  String? targetUserId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAuditEventDto &&
    other.action == action &&
    other.actorUserId == actorUserId &&
    _deepEquality.equals(other.details, details) &&
    other.id == id &&
    other.occurredAt == occurredAt &&
    other.outcome == outcome &&
    other.reason == reason &&
    other.targetUserId == targetUserId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (actorUserId == null ? 0 : actorUserId!.hashCode) +
    (details.hashCode) +
    (id.hashCode) +
    (occurredAt.hashCode) +
    (outcome.hashCode) +
    (reason == null ? 0 : reason!.hashCode) +
    (targetUserId == null ? 0 : targetUserId!.hashCode);

  @override
  String toString() => 'AdminAuditEventDto[action=$action, actorUserId=$actorUserId, details=$details, id=$id, occurredAt=$occurredAt, outcome=$outcome, reason=$reason, targetUserId=$targetUserId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.actorUserId != null) {
      json[r'actorUserId'] = this.actorUserId;
    } else {
      json[r'actorUserId'] = null;
    }
      json[r'details'] = this.details;
      json[r'id'] = this.id;
      json[r'occurredAt'] = this.occurredAt.toUtc().toIso8601String();
      json[r'outcome'] = this.outcome;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    if (this.targetUserId != null) {
      json[r'targetUserId'] = this.targetUserId;
    } else {
      json[r'targetUserId'] = null;
    }
    return json;
  }

  /// Returns a new [AdminAuditEventDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAuditEventDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAuditEventDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAuditEventDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAuditEventDto(
        action: AdminActionKind.fromJson(json[r'action'])!,
        actorUserId: mapValueOfType<String>(json, r'actorUserId'),
        details: mapCastOfType<String, String>(json, r'details')!,
        id: mapValueOfType<String>(json, r'id')!,
        occurredAt: mapDateTime(json, r'occurredAt', r'')!,
        outcome: mapValueOfType<String>(json, r'outcome')!,
        reason: mapValueOfType<String>(json, r'reason'),
        targetUserId: mapValueOfType<String>(json, r'targetUserId'),
      );
    }
    return null;
  }

  static List<AdminAuditEventDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAuditEventDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAuditEventDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAuditEventDto> mapFromJson(dynamic json) {
    final map = <String, AdminAuditEventDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAuditEventDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAuditEventDto-objects as value to a dart map
  static Map<String, List<AdminAuditEventDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAuditEventDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAuditEventDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'details',
    'id',
    'occurredAt',
    'outcome',
  };
}

