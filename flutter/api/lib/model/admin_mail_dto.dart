//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminMailDto {
  /// Returns a new [AdminMailDto] instance.
  AdminMailDto({
    this.mails = const [],
    required this.subject,
    required this.message,
    this.messageHtml,
  });

  /// List of emails when null all users will get this mail
  List<String>? mails;

  String subject;

  /// Plaintext message
  String message;

  /// Html message
  String? messageHtml;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminMailDto &&
    _deepEquality.equals(other.mails, mails) &&
    other.subject == subject &&
    other.message == message &&
    other.messageHtml == messageHtml;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (mails == null ? 0 : mails!.hashCode) +
    (subject.hashCode) +
    (message.hashCode) +
    (messageHtml == null ? 0 : messageHtml!.hashCode);

  @override
  String toString() => 'AdminMailDto[mails=$mails, subject=$subject, message=$message, messageHtml=$messageHtml]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.mails != null) {
      json[r'mails'] = this.mails;
    } else {
      json[r'mails'] = null;
    }
      json[r'subject'] = this.subject;
      json[r'message'] = this.message;
    if (this.messageHtml != null) {
      json[r'messageHtml'] = this.messageHtml;
    } else {
      json[r'messageHtml'] = null;
    }
    return json;
  }

  /// Returns a new [AdminMailDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminMailDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminMailDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminMailDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminMailDto(
        mails: json[r'mails'] is Iterable
            ? (json[r'mails'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        subject: mapValueOfType<String>(json, r'subject')!,
        message: mapValueOfType<String>(json, r'message')!,
        messageHtml: mapValueOfType<String>(json, r'messageHtml'),
      );
    }
    return null;
  }

  static List<AdminMailDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminMailDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminMailDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminMailDto> mapFromJson(dynamic json) {
    final map = <String, AdminMailDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminMailDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminMailDto-objects as value to a dart map
  static Map<String, List<AdminMailDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminMailDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminMailDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'mails',
    'subject',
    'message',
  };
}

