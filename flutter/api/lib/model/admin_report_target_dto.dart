//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminReportTargetDto {
  /// Returns a new [AdminReportTargetDto] instance.
  AdminReportTargetDto({
    required this.deleted,
    this.userId,
    this.username,
  });

  bool deleted;

  String? userId;

  String? username;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminReportTargetDto &&
    other.deleted == deleted &&
    other.userId == userId &&
    other.username == username;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (deleted.hashCode) +
    (userId == null ? 0 : userId!.hashCode) +
    (username == null ? 0 : username!.hashCode);

  @override
  String toString() => 'AdminReportTargetDto[deleted=$deleted, userId=$userId, username=$username]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'deleted'] = this.deleted;
    if (this.userId != null) {
      json[r'userId'] = this.userId;
    } else {
      json[r'userId'] = null;
    }
    if (this.username != null) {
      json[r'username'] = this.username;
    } else {
      json[r'username'] = null;
    }
    return json;
  }

  /// Returns a new [AdminReportTargetDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminReportTargetDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminReportTargetDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminReportTargetDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminReportTargetDto(
        deleted: mapValueOfType<bool>(json, r'deleted')!,
        userId: mapValueOfType<String>(json, r'userId'),
        username: mapValueOfType<String>(json, r'username'),
      );
    }
    return null;
  }

  static List<AdminReportTargetDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminReportTargetDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminReportTargetDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminReportTargetDto> mapFromJson(dynamic json) {
    final map = <String, AdminReportTargetDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminReportTargetDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminReportTargetDto-objects as value to a dart map
  static Map<String, List<AdminReportTargetDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminReportTargetDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminReportTargetDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'deleted',
  };
}

