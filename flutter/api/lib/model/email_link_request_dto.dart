//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class EmailLinkRequestDto {
  /// Returns a new [EmailLinkRequestDto] instance.
  EmailLinkRequestDto({
    required this.email,
    this.identifierType,
  });

  String email;

  /// Explicit identifier kind. Defaults to email when omitted.
  EmailLinkRequestDtoIdentifierTypeEnum? identifierType;

  @override
  bool operator ==(Object other) => identical(this, other) || other is EmailLinkRequestDto &&
    other.email == email &&
    other.identifierType == identifierType;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (email.hashCode) +
    (identifierType == null ? 0 : identifierType!.hashCode);

  @override
  String toString() => 'EmailLinkRequestDto[email=$email, identifierType=$identifierType]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'email'] = this.email;
    if (this.identifierType != null) {
      json[r'identifierType'] = this.identifierType;
    } else {
      json[r'identifierType'] = null;
    }
    return json;
  }

  /// Returns a new [EmailLinkRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static EmailLinkRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "EmailLinkRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "EmailLinkRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return EmailLinkRequestDto(
        email: mapValueOfType<String>(json, r'email')!,
        identifierType: EmailLinkRequestDtoIdentifierTypeEnum.fromJson(json[r'identifierType']),
      );
    }
    return null;
  }

  static List<EmailLinkRequestDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <EmailLinkRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EmailLinkRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, EmailLinkRequestDto> mapFromJson(dynamic json) {
    final map = <String, EmailLinkRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = EmailLinkRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of EmailLinkRequestDto-objects as value to a dart map
  static Map<String, List<EmailLinkRequestDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<EmailLinkRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = EmailLinkRequestDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'email',
  };
}

/// Explicit identifier kind. Defaults to email when omitted.
class EmailLinkRequestDtoIdentifierTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const EmailLinkRequestDtoIdentifierTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const email = EmailLinkRequestDtoIdentifierTypeEnum._(r'email');
  static const username = EmailLinkRequestDtoIdentifierTypeEnum._(r'username');

  /// List of all possible values in this [enum][EmailLinkRequestDtoIdentifierTypeEnum].
  static const values = <EmailLinkRequestDtoIdentifierTypeEnum>[
    email,
    username,
  ];

  static EmailLinkRequestDtoIdentifierTypeEnum? fromJson(dynamic value) => EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer().decode(value);

  static List<EmailLinkRequestDtoIdentifierTypeEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <EmailLinkRequestDtoIdentifierTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EmailLinkRequestDtoIdentifierTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [EmailLinkRequestDtoIdentifierTypeEnum] to String,
/// and [decode] dynamic data back to [EmailLinkRequestDtoIdentifierTypeEnum].
class EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer {
  factory EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer() => _instance ??= const EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer._();

  const EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer._();

  String encode(EmailLinkRequestDtoIdentifierTypeEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a EmailLinkRequestDtoIdentifierTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  EmailLinkRequestDtoIdentifierTypeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'email': return EmailLinkRequestDtoIdentifierTypeEnum.email;
        case r'username': return EmailLinkRequestDtoIdentifierTypeEnum.username;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer] instance.
  static EmailLinkRequestDtoIdentifierTypeEnumTypeTransformer? _instance;
}
