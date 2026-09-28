//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportDto {
  /// Returns a new [ReportDto] instance.
  ReportDto({
    required this.userId,
    required this.report,
    required this.message,
    this.targetId,
    this.targetKind,
  });

  String userId;

  String report;

  String message;

  String? targetId;

  String? targetKind;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReportDto &&
    other.userId == userId &&
    other.report == report &&
    other.message == message &&
    other.targetId == targetId &&
    other.targetKind == targetKind;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (userId.hashCode) +
    (report.hashCode) +
    (message.hashCode) +
    (targetId == null ? 0 : targetId!.hashCode) +
    (targetKind == null ? 0 : targetKind!.hashCode);

  @override
  String toString() => 'ReportDto[userId=$userId, report=$report, message=$message, targetId=$targetId, targetKind=$targetKind]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'userId'] = this.userId;
      json[r'report'] = this.report;
      json[r'message'] = this.message;
    if (this.targetId != null) {
      json[r'targetId'] = this.targetId;
    } else {
      json[r'targetId'] = null;
    }
    if (this.targetKind != null) {
      json[r'targetKind'] = this.targetKind;
    } else {
      json[r'targetKind'] = null;
    }
    return json;
  }

  /// Returns a new [ReportDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ReportDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ReportDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportDto(
        userId: mapValueOfType<String>(json, r'userId')!,
        report: mapValueOfType<String>(json, r'report')!,
        message: mapValueOfType<String>(json, r'message')!,
        targetId: mapValueOfType<String>(json, r'targetId'),
        targetKind: mapValueOfType<String>(json, r'targetKind'),
      );
    }
    return null;
  }

  static List<ReportDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ReportDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportDto> mapFromJson(dynamic json) {
    final map = <String, ReportDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportDto-objects as value to a dart map
  static Map<String, List<ReportDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ReportDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'userId',
    'report',
    'message',
  };
}

