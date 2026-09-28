//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LoginLinkActionDto {
  /// Returns a new [LoginLinkActionDto] instance.
  LoginLinkActionDto({
    required this.action,
    this.reason,
  });

  LoginLinkActionDtoActionEnum action;

  String? reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LoginLinkActionDto &&
    other.action == action &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (action.hashCode) +
    (reason == null ? 0 : reason!.hashCode);

  @override
  String toString() => 'LoginLinkActionDto[action=$action, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'action'] = this.action;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    return json;
  }

  /// Returns a new [LoginLinkActionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LoginLinkActionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "LoginLinkActionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "LoginLinkActionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return LoginLinkActionDto(
        action: LoginLinkActionDtoActionEnum.fromJson(json[r'action'])!,
        reason: mapValueOfType<String>(json, r'reason'),
      );
    }
    return null;
  }

  static List<LoginLinkActionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LoginLinkActionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LoginLinkActionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LoginLinkActionDto> mapFromJson(dynamic json) {
    final map = <String, LoginLinkActionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LoginLinkActionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LoginLinkActionDto-objects as value to a dart map
  static Map<String, List<LoginLinkActionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LoginLinkActionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LoginLinkActionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
  };
}


class LoginLinkActionDtoActionEnum {
  /// Instantiate a new enum with the provided [value].
  const LoginLinkActionDtoActionEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const loginLink = LoginLinkActionDtoActionEnum._(r'login_link');

  /// List of all possible values in this [enum][LoginLinkActionDtoActionEnum].
  static const values = <LoginLinkActionDtoActionEnum>[
    loginLink,
  ];

  static LoginLinkActionDtoActionEnum? fromJson(dynamic value) => LoginLinkActionDtoActionEnumTypeTransformer().decode(value);

  static List<LoginLinkActionDtoActionEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LoginLinkActionDtoActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LoginLinkActionDtoActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [LoginLinkActionDtoActionEnum] to String,
/// and [decode] dynamic data back to [LoginLinkActionDtoActionEnum].
class LoginLinkActionDtoActionEnumTypeTransformer {
  factory LoginLinkActionDtoActionEnumTypeTransformer() => _instance ??= const LoginLinkActionDtoActionEnumTypeTransformer._();

  const LoginLinkActionDtoActionEnumTypeTransformer._();

  String encode(LoginLinkActionDtoActionEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a LoginLinkActionDtoActionEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  LoginLinkActionDtoActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'login_link': return LoginLinkActionDtoActionEnum.loginLink;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [LoginLinkActionDtoActionEnumTypeTransformer] instance.
  static LoginLinkActionDtoActionEnumTypeTransformer? _instance;
}


