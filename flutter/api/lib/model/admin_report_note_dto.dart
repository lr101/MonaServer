//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReportNoteDto {
  /// Returns a new [AdminReportNoteDto] instance.
  AdminReportNoteDto({
    required this.actorUserId,
    required this.createdAt,
    required this.id,
    required this.text,
  });

  String actorUserId;

  DateTime createdAt;

  String id;

  String text;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReportNoteDto &&
    other.actorUserId == actorUserId &&
    other.createdAt == createdAt &&
    other.id == id &&
    other.text == text;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (actorUserId.hashCode) +
    (createdAt.hashCode) +
    (id.hashCode) +
    (text.hashCode);

  @override
  String toString() => 'AdminReportNoteDto[actorUserId=$actorUserId, createdAt=$createdAt, id=$id, text=$text]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'actorUserId'] = this.actorUserId;
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
      json[r'id'] = this.id;
      json[r'text'] = this.text;
    return json;
  }

  /// Returns a new [AdminReportNoteDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReportNoteDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReportNoteDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReportNoteDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReportNoteDto(
        actorUserId: mapValueOfType<String>(json, r'actorUserId')!,
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        id: mapValueOfType<String>(json, r'id')!,
        text: mapValueOfType<String>(json, r'text')!,
      );
    }
    return null;
  }

  static List<AdminReportNoteDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportNoteDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportNoteDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReportNoteDto> mapFromJson(dynamic json) {
    final map = <String, AdminReportNoteDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReportNoteDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReportNoteDto-objects as value to a dart map
  static Map<String, List<AdminReportNoteDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReportNoteDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReportNoteDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'actorUserId',
    'createdAt',
    'id',
    'text',
  };
}

