//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminTestMessageAcceptedDto {
  /// Returns a new [AdminTestMessageAcceptedDto] instance.
  AdminTestMessageAcceptedDto({
    required this.accepted,
    this.jobId,
  });

  bool accepted;

  String? jobId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminTestMessageAcceptedDto &&
    other.accepted == accepted &&
    other.jobId == jobId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (accepted.hashCode) +
    (jobId == null ? 0 : jobId!.hashCode);

  @override
  String toString() => 'AdminTestMessageAcceptedDto[accepted=$accepted, jobId=$jobId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'accepted'] = this.accepted;
    if (this.jobId != null) {
      json[r'jobId'] = this.jobId;
    } else {
      json[r'jobId'] = null;
    }
    return json;
  }

  /// Returns a new [AdminTestMessageAcceptedDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminTestMessageAcceptedDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminTestMessageAcceptedDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminTestMessageAcceptedDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminTestMessageAcceptedDto(
        accepted: mapValueOfType<bool>(json, r'accepted')!,
        jobId: mapValueOfType<String>(json, r'jobId'),
      );
    }
    return null;
  }

  static List<AdminTestMessageAcceptedDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminTestMessageAcceptedDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminTestMessageAcceptedDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminTestMessageAcceptedDto> mapFromJson(dynamic json) {
    final map = <String, AdminTestMessageAcceptedDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminTestMessageAcceptedDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminTestMessageAcceptedDto-objects as value to a dart map
  static Map<String, List<AdminTestMessageAcceptedDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminTestMessageAcceptedDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminTestMessageAcceptedDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'accepted',
  };
}

