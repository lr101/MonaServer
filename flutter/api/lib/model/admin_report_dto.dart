//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReportDto {
  /// Returns a new [AdminReportDto] instance.
  AdminReportDto({
    this.assigneeUserId,
    required this.createdAt,
    required this.id,
    this.legacyMessage,
    this.notes = const [],
    required this.reporterUserId,
    this.reporterUsername,
    required this.revision,
    required this.status,
    required this.target,
    required this.text,
    required this.updatedAt,
  });

  String? assigneeUserId;

  DateTime createdAt;

  String id;

  String? legacyMessage;

  List<AdminReportNoteDto> notes;

  String reporterUserId;

  String? reporterUsername;

  /// Minimum value: 0
  int revision;

  AdminReportStatus status;

  AdminReportTargetDto target;

  String text;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReportDto &&
    other.assigneeUserId == assigneeUserId &&
    other.createdAt == createdAt &&
    other.id == id &&
    other.legacyMessage == legacyMessage &&
    _deepEquality.equals(other.notes, notes) &&
    other.reporterUserId == reporterUserId &&
    other.reporterUsername == reporterUsername &&
    other.revision == revision &&
    other.status == status &&
    other.target == target &&
    other.text == text &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (assigneeUserId == null ? 0 : assigneeUserId!.hashCode) +
    (createdAt.hashCode) +
    (id.hashCode) +
    (legacyMessage == null ? 0 : legacyMessage!.hashCode) +
    (notes.hashCode) +
    (reporterUserId.hashCode) +
    (reporterUsername == null ? 0 : reporterUsername!.hashCode) +
    (revision.hashCode) +
    (status.hashCode) +
    (target.hashCode) +
    (text.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'AdminReportDto[assigneeUserId=$assigneeUserId, createdAt=$createdAt, id=$id, legacyMessage=$legacyMessage, notes=$notes, reporterUserId=$reporterUserId, reporterUsername=$reporterUsername, revision=$revision, status=$status, target=$target, text=$text, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.assigneeUserId != null) {
      json[r'assigneeUserId'] = this.assigneeUserId;
    } else {
      json[r'assigneeUserId'] = null;
    }
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
      json[r'id'] = this.id;
    if (this.legacyMessage != null) {
      json[r'legacyMessage'] = this.legacyMessage;
    } else {
      json[r'legacyMessage'] = null;
    }
      json[r'notes'] = this.notes;
      json[r'reporterUserId'] = this.reporterUserId;
    if (this.reporterUsername != null) {
      json[r'reporterUsername'] = this.reporterUsername;
    } else {
      json[r'reporterUsername'] = null;
    }
      json[r'revision'] = this.revision;
      json[r'status'] = this.status;
      json[r'target'] = this.target;
      json[r'text'] = this.text;
      json[r'updatedAt'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [AdminReportDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReportDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReportDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReportDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReportDto(
        assigneeUserId: mapValueOfType<String>(json, r'assigneeUserId'),
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        id: mapValueOfType<String>(json, r'id')!,
        legacyMessage: mapValueOfType<String>(json, r'legacyMessage'),
        notes: AdminReportNoteDto.listFromJson(json[r'notes']),
        reporterUserId: mapValueOfType<String>(json, r'reporterUserId')!,
        reporterUsername: mapValueOfType<String>(json, r'reporterUsername'),
        revision: mapValueOfType<int>(json, r'revision')!,
        status: AdminReportStatus.fromJson(json[r'status'])!,
        target: AdminReportTargetDto.fromJson(json[r'target'])!,
        text: mapValueOfType<String>(json, r'text')!,
        updatedAt: mapDateTime(json, r'updatedAt', r'')!,
      );
    }
    return null;
  }

  static List<AdminReportDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReportDto> mapFromJson(dynamic json) {
    final map = <String, AdminReportDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReportDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReportDto-objects as value to a dart map
  static Map<String, List<AdminReportDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReportDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReportDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'createdAt',
    'id',
    'notes',
    'reporterUserId',
    'revision',
    'status',
    'target',
    'text',
    'updatedAt',
  };
}

