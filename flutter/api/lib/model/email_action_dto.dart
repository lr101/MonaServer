//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class EmailActionDto {
  /// Returns a new [EmailActionDto] instance.
  EmailActionDto({
    required this.action,
    this.body,
    this.messageHtml,
    this.subject,
  });

  EmailActionDtoActionEnum action;

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

  @override
  bool operator ==(Object other) => identical(this, other) || other is EmailActionDto &&
    other.action == action &&
    other.body == body &&
    other.messageHtml == messageHtml &&
    other.subject == subject;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (body == null ? 0 : body!.hashCode) +
    (messageHtml == null ? 0 : messageHtml!.hashCode) +
    (subject == null ? 0 : subject!.hashCode);

  @override
  String toString() => 'EmailActionDto[action=$action, body=$body, messageHtml=$messageHtml, subject=$subject]';

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
    return json;
  }

  /// Returns a new [EmailActionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static EmailActionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "EmailActionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "EmailActionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return EmailActionDto(
        action: EmailActionDtoActionEnum.fromJson(json[r'action'])!,
        body: mapValueOfType<String>(json, r'body'),
        messageHtml: mapValueOfType<String>(json, r'messageHtml'),
        subject: mapValueOfType<String>(json, r'subject'),
      );
    }
    return null;
  }

  static List<EmailActionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <EmailActionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EmailActionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, EmailActionDto> mapFromJson(dynamic json) {
    final map = <String, EmailActionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = EmailActionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of EmailActionDto-objects as value to a dart map
  static Map<String, List<EmailActionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<EmailActionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = EmailActionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
  };
}


class EmailActionDtoActionEnum {
  /// Instantiate a new enum with the provided [value].
  const EmailActionDtoActionEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const email = EmailActionDtoActionEnum._(r'email');

  /// List of all possible values in this [enum][EmailActionDtoActionEnum].
  static const values = <EmailActionDtoActionEnum>[
    email,
  ];

  static EmailActionDtoActionEnum? fromJson(dynamic value) => EmailActionDtoActionEnumTypeTransformer().decode(value);

  static List<EmailActionDtoActionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <EmailActionDtoActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EmailActionDtoActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [EmailActionDtoActionEnum] to String,
/// and [decode] dynamic data back to [EmailActionDtoActionEnum].
class EmailActionDtoActionEnumTypeTransformer {
  factory EmailActionDtoActionEnumTypeTransformer() => _instance ??= const EmailActionDtoActionEnumTypeTransformer._();

  const EmailActionDtoActionEnumTypeTransformer._();

  String encode(EmailActionDtoActionEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a EmailActionDtoActionEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  EmailActionDtoActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'email': return EmailActionDtoActionEnum.email;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [EmailActionDtoActionEnumTypeTransformer] instance.
  static EmailActionDtoActionEnumTypeTransformer? _instance;
}


