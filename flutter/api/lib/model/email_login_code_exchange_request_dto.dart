//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class EmailLoginCodeExchangeRequestDto {
  /// Returns a new [EmailLoginCodeExchangeRequestDto] instance.
  EmailLoginCodeExchangeRequestDto({
    required this.code,
    required this.email,
    this.identifierType,
  });

  String code;

  String email;

  /// Explicit identifier kind. Defaults to email for older clients.
  EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum? identifierType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailLoginCodeExchangeRequestDto &&
          other.code == code &&
          other.email == email &&
          other.identifierType == identifierType;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (code.hashCode) +
      (email.hashCode) +
      (identifierType == null ? 0 : identifierType!.hashCode);

  @override
  String toString() =>
      'EmailLoginCodeExchangeRequestDto[code=[redacted], email=$email, identifierType=$identifierType]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'code'] = this.code;
    json[r'email'] = this.email;
    if (this.identifierType != null) {
      json[r'identifierType'] = this.identifierType;
    } else {
      json[r'identifierType'] = null;
    }
    return json;
  }

  /// Returns a new [EmailLoginCodeExchangeRequestDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static EmailLoginCodeExchangeRequestDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "EmailLoginCodeExchangeRequestDto[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "EmailLoginCodeExchangeRequestDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return EmailLoginCodeExchangeRequestDto(
        code: mapValueOfType<String>(json, r'code')!,
        email: mapValueOfType<String>(json, r'email')!,
        identifierType:
            EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum.fromJson(
                json[r'identifierType']),
      );
    }
    return null;
  }

  static List<EmailLoginCodeExchangeRequestDto> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <EmailLoginCodeExchangeRequestDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EmailLoginCodeExchangeRequestDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, EmailLoginCodeExchangeRequestDto> mapFromJson(
      dynamic json) {
    final map = <String, EmailLoginCodeExchangeRequestDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = EmailLoginCodeExchangeRequestDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of EmailLoginCodeExchangeRequestDto-objects as value to a dart map
  static Map<String, List<EmailLoginCodeExchangeRequestDto>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<EmailLoginCodeExchangeRequestDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = EmailLoginCodeExchangeRequestDto.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'email',
  };
}

/// Explicit identifier kind. Defaults to email for older clients.
class EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum {
  /// Instantiate a new enum with the provided [value].
  const EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const email =
      EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum._(r'email');
  static const username =
      EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum._(r'username');

  /// List of all possible values in this [enum][EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum].
  static const values = <EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum>[
    email,
    username,
  ];

  static EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum? fromJson(
          dynamic value) =>
      EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer()
          .decode(value);

  static List<EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value =
            EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum] to String,
/// and [decode] dynamic data back to [EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum].
class EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer {
  factory EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer() =>
      _instance ??=
          const EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer
              ._();

  const EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer._();

  String encode(EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum data) =>
      data.value;

  /// Decodes a [dynamic value][data] to a EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'email':
          return EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum.email;
        case r'username':
          return EmailLoginCodeExchangeRequestDtoIdentifierTypeEnum.username;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer] instance.
  static EmailLoginCodeExchangeRequestDtoIdentifierTypeEnumTypeTransformer?
      _instance;
}
