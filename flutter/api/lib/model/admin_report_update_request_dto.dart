//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReportUpdateRequestDto {
  /// Returns a new [AdminReportUpdateRequestDto] instance.
  AdminReportUpdateRequestDto({
    this.assigneeUserId,
    required this.expectedRevision,
    this.note,
    required this.status,
  });

  String? assigneeUserId;

  /// Minimum value: 0
  int expectedRevision;

  String? note;

  AdminReportStatus status;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReportUpdateRequestDto &&
    other.assigneeUserId == assigneeUserId &&
    other.expectedRevision == expectedRevision &&
    other.note == note &&
    other.status == status;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (assigneeUserId == null ? 0 : assigneeUserId!.hashCode) +
    (expectedRevision.hashCode) +
    (note == null ? 0 : note!.hashCode) +
    (status.hashCode);

  @override
  String toString() => 'AdminReportUpdateRequestDto[assigneeUserId=$assigneeUserId, expectedRevision=$expectedRevision, note=$note, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.assigneeUserId != null) {
      json[r'assigneeUserId'] = this.assigneeUserId;
    } else {
      json[r'assigneeUserId'] = null;
    }
      json[r'expectedRevision'] = this.expectedRevision;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
      json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [AdminReportUpdateRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReportUpdateRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReportUpdateRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReportUpdateRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReportUpdateRequestDto(
        assigneeUserId: mapValueOfType<String>(json, r'assigneeUserId'),
        expectedRevision: mapValueOfType<int>(json, r'expectedRevision')!,
        note: mapValueOfType<String>(json, r'note'),
        status: AdminReportStatus.fromJson(json[r'status'])!,
      );
    }
    return null;
  }

  static List<AdminReportUpdateRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportUpdateRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportUpdateRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReportUpdateRequestDto> mapFromJson(dynamic json) {
    final map = <String, AdminReportUpdateRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReportUpdateRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReportUpdateRequestDto-objects as value to a dart map
  static Map<String, List<AdminReportUpdateRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReportUpdateRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReportUpdateRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedRevision',
    'status',
  };
}

