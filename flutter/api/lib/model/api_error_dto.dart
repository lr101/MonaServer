//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApiErrorDto {
  /// Returns a new [ApiErrorDto] instance.
  ApiErrorDto({
    required this.code,
    required this.message,
    this.retryAfterSeconds,
  });

  String code;

  String message;

  /// Minimum value: 0
  int? retryAfterSeconds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ApiErrorDto &&
    other.code == code &&
    other.message == message &&
    other.retryAfterSeconds == retryAfterSeconds;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (code.hashCode) +
    (message.hashCode) +
    (retryAfterSeconds == null ? 0 : retryAfterSeconds!.hashCode);

  @override
  String toString() => 'ApiErrorDto[code=$code, message=$message, retryAfterSeconds=$retryAfterSeconds]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'code'] = this.code;
      json[r'message'] = this.message;
    if (this.retryAfterSeconds != null) {
      json[r'retryAfterSeconds'] = this.retryAfterSeconds;
    } else {
      json[r'retryAfterSeconds'] = null;
    }
    return json;
  }

  /// Returns a new [ApiErrorDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ApiErrorDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "ApiErrorDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "ApiErrorDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ApiErrorDto(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
        retryAfterSeconds: mapValueOfType<int>(json, r'retryAfterSeconds'),
      );
    }
    return null;
  }

  static List<ApiErrorDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ApiErrorDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ApiErrorDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ApiErrorDto> mapFromJson(dynamic json) {
    final map = <String, ApiErrorDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ApiErrorDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ApiErrorDto-objects as value to a dart map
  static Map<String, List<ApiErrorDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ApiErrorDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ApiErrorDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'message',
  };
}

