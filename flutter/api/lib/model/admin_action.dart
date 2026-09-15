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

  String? body;

  /// Optional server-sanitized preview input; scripts and admin DOM access are rejected.
  String? messageHtml;

  String? subject;

  String? reason;

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
    bool hasText(String? value) => value != null && value.isNotEmpty;
    switch (this.action.value) {
      case 'email':
        if (!hasText(this.body) || !hasText(this.subject)) {
          throw const FormatException('AdminAction[email] requires body and subject.');
        }
        break;
      case 'push':
        if (!hasText(this.body) || !hasText(this.title)) {
          throw const FormatException('AdminAction[push] requires body and title.');
        }
        break;
      case 'revoke_sessions':
      case 'mark_compromised':
      case 'recovery_resend':
        if (!hasText(this.reason)) {
          throw const FormatException('Security actions require reason.');
        }
        break;
      case 'login_link':
      case 'report_resolve':
      case 'report_dismiss':
        break;
      default:
        throw FormatException('Unknown AdminAction kind: ${this.action.value}');
    }
    final json = <String, dynamic>{};
    json[r'action'] = this.action;
    if (this.body != null) {
      json[r'body'] = this.body;
    }
    if (this.messageHtml != null) {
      json[r'messageHtml'] = this.messageHtml;
    }
    if (this.subject != null) {
      json[r'subject'] = this.subject;
    }
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    }
    if (this.title != null) {
      json[r'title'] = this.title;
    }
    if (this.note != null) {
      json[r'note'] = this.note;
    }
    return json;
  }

  /// Returns a new [AdminAction] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminAction? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();
      final action = AdminActionKind.fromJson(json[r'action']);
      if (action == null) {
        throw const FormatException('AdminAction requires a valid action.');
      }
      bool hasText(String key) => json[key] is String && (json[key] as String).isNotEmpty;
      switch (action.value) {
        case 'email':
          if (!hasText('body') || !hasText('subject')) {
            throw const FormatException('AdminAction[email] requires body and subject.');
          }
          break;
        case 'push':
          if (!hasText('body') || !hasText('title')) {
            throw const FormatException('AdminAction[push] requires body and title.');
          }
          break;
        case 'revoke_sessions':
        case 'mark_compromised':
        case 'recovery_resend':
          if (!hasText('reason')) {
            throw const FormatException('Security actions require reason.');
          }
          break;
        case 'login_link':
        case 'report_resolve':
        case 'report_dismiss':
          break;
        default:
          throw FormatException('Unknown AdminAction kind: ${action.value}');
      }
      return AdminAction(
        action: action,
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

  static const requiredKeys = <String>{
    'action',
  };
}
