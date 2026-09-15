//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminAction {
  /// Returns a new [AdminAction] instance.
  AdminAction({
    required this.action,
    this.body,
    this.messageHtml,
    this.subject,
    this.reason,
    this.title,
    this.note,
  });

  AdminActionKind action;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? body;

  /// Optional server-sanitized preview input; scripts and admin DOM access are rejected.
  String? messageHtml;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? subject;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? reason;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? title;

  String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminAction &&
    other.action == action &&
    other.body == body &&
    other.messageHtml == messageHtml &&
    other.subject == subject &&
    other.reason == reason &&
    other.title == title &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (body == null ? 0 : body!.hashCode) +
    (messageHtml == null ? 0 : messageHtml!.hashCode) +
    (subject == null ? 0 : subject!.hashCode) +
    (reason == null ? 0 : reason!.hashCode) +
    (title == null ? 0 : title!.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'AdminAction[action=$action, body=$body, messageHtml=$messageHtml, subject=$subject, reason=$reason, title=$title, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.body != null) {
      json[r'body'] = this.body;
    } else {
      json[r'body'] = null;
    }
    if (this.messageHtml != null) {
      json[r'messageHtml'] = this.messageHtml;
    } else {
      json[r'messageHtml'] = null;
    }
    if (this.subject != null) {
      json[r'subject'] = this.subject;
    } else {
      json[r'subject'] = null;
    }
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    if (this.title != null) {
      json[r'title'] = this.title;
    } else {
      json[r'title'] = null;
    }
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Returns a new [AdminAction] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAction? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminAction[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminAction[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminAction(
        action: AdminActionKind.fromJson(json[r'action'])!,
        body: mapValueOfType<String>(json, r'body'),
        messageHtml: mapValueOfType<String>(json, r'messageHtml'),
        subject: mapValueOfType<String>(json, r'subject'),
        reason: mapValueOfType<String>(json, r'reason'),
        title: mapValueOfType<String>(json, r'title'),
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<AdminAction> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminAction>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminAction.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminAction> mapFromJson(dynamic json) {
    final map = <String, AdminAction>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminAction.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminAction-objects as value to a dart map
  static Map<String, List<AdminAction>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminAction>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminAction.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
  };
}

