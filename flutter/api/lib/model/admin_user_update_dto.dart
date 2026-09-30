//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminUserUpdateDto {
  /// Returns a new [AdminUserUpdateDto] instance.
  AdminUserUpdateDto({
    this.communicationOptOut,
    required this.expectedAuthGeneration,
    this.email,
    this.passwordDisabled,
    this.passwordResetRequired,
    this.pushOptedOut,
    this.securityState,
    this.username,
  });

  bool? communicationOptOut;

  /// Auth generation from the displayed user details. Rejects edits based on stale security state.
  ///
  /// Minimum value: 0
  int? expectedAuthGeneration;

  String? email;

  bool? passwordDisabled;

  bool? passwordResetRequired;

  bool? pushOptedOut;

  AdminUserUpdateDtoSecurityStateEnum? securityState;

  String? username;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUserUpdateDto &&
          other.communicationOptOut == communicationOptOut &&
          other.expectedAuthGeneration == expectedAuthGeneration &&
          other.email == email &&
          other.passwordDisabled == passwordDisabled &&
          other.passwordResetRequired == passwordResetRequired &&
          other.pushOptedOut == pushOptedOut &&
          other.securityState == securityState &&
          other.username == username;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (communicationOptOut == null ? 0 : communicationOptOut!.hashCode) +
      (expectedAuthGeneration == null ? 0 : expectedAuthGeneration!.hashCode) +
      (email == null ? 0 : email!.hashCode) +
      (passwordDisabled == null ? 0 : passwordDisabled!.hashCode) +
      (passwordResetRequired == null ? 0 : passwordResetRequired!.hashCode) +
      (pushOptedOut == null ? 0 : pushOptedOut!.hashCode) +
      (securityState == null ? 0 : securityState!.hashCode) +
      (username == null ? 0 : username!.hashCode);

  @override
  String toString() =>
      'AdminUserUpdateDto[communicationOptOut=$communicationOptOut, expectedAuthGeneration=$expectedAuthGeneration, email=$email, passwordDisabled=$passwordDisabled, passwordResetRequired=$passwordResetRequired, pushOptedOut=$pushOptedOut, securityState=$securityState, username=$username]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.communicationOptOut != null) {
      json[r'communicationOptOut'] = this.communicationOptOut;
    } else {
      json[r'communicationOptOut'] = null;
    }
    if (this.expectedAuthGeneration != null) {
      json[r'expectedAuthGeneration'] = this.expectedAuthGeneration;
    } else {
      json[r'expectedAuthGeneration'] = null;
    }
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    if (this.passwordDisabled != null) {
      json[r'passwordDisabled'] = this.passwordDisabled;
    } else {
      json[r'passwordDisabled'] = null;
    }
    if (this.passwordResetRequired != null) {
      json[r'passwordResetRequired'] = this.passwordResetRequired;
    } else {
      json[r'passwordResetRequired'] = null;
    }
    if (this.pushOptedOut != null) {
      json[r'pushOptedOut'] = this.pushOptedOut;
    } else {
      json[r'pushOptedOut'] = null;
    }
    if (this.securityState != null) {
      json[r'securityState'] = this.securityState;
    } else {
      json[r'securityState'] = null;
    }
    if (this.username != null) {
      json[r'username'] = this.username;
    } else {
      json[r'username'] = null;
    }
    return json;
  }

  /// Returns a new [AdminUserUpdateDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminUserUpdateDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "AdminUserUpdateDto[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "AdminUserUpdateDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminUserUpdateDto(
        communicationOptOut: mapValueOfType<bool>(json, r'communicationOptOut'),
        expectedAuthGeneration:
            mapValueOfType<int>(json, r'expectedAuthGeneration'),
        email: mapValueOfType<String>(json, r'email'),
        passwordDisabled: mapValueOfType<bool>(json, r'passwordDisabled'),
        passwordResetRequired:
            mapValueOfType<bool>(json, r'passwordResetRequired'),
        pushOptedOut: mapValueOfType<bool>(json, r'pushOptedOut'),
        securityState: AdminUserUpdateDtoSecurityStateEnum.fromJson(
            json[r'securityState']),
        username: mapValueOfType<String>(json, r'username'),
      );
    }
    return null;
  }

  static List<AdminUserUpdateDto> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AdminUserUpdateDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserUpdateDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminUserUpdateDto> mapFromJson(dynamic json) {
    final map = <String, AdminUserUpdateDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminUserUpdateDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminUserUpdateDto-objects as value to a dart map
  static Map<String, List<AdminUserUpdateDto>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AdminUserUpdateDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminUserUpdateDto.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expectedAuthGeneration',
  };
}

class AdminUserUpdateDtoSecurityStateEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminUserUpdateDtoSecurityStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const normal = AdminUserUpdateDtoSecurityStateEnum._(r'normal');
  static const passwordDisabled =
      AdminUserUpdateDtoSecurityStateEnum._(r'password_disabled');
  static const compromised =
      AdminUserUpdateDtoSecurityStateEnum._(r'compromised');
  static const securedManualRecoveryRequired =
      AdminUserUpdateDtoSecurityStateEnum._(
          r'secured_manual_recovery_required');

  /// List of all possible values in this [enum][AdminUserUpdateDtoSecurityStateEnum].
  static const values = <AdminUserUpdateDtoSecurityStateEnum>[
    normal,
    passwordDisabled,
    compromised,
    securedManualRecoveryRequired,
  ];

  static AdminUserUpdateDtoSecurityStateEnum? fromJson(dynamic value) =>
      AdminUserUpdateDtoSecurityStateEnumTypeTransformer().decode(value);

  static List<AdminUserUpdateDtoSecurityStateEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AdminUserUpdateDtoSecurityStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserUpdateDtoSecurityStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminUserUpdateDtoSecurityStateEnum] to String,
/// and [decode] dynamic data back to [AdminUserUpdateDtoSecurityStateEnum].
class AdminUserUpdateDtoSecurityStateEnumTypeTransformer {
  factory AdminUserUpdateDtoSecurityStateEnumTypeTransformer() => _instance ??=
      const AdminUserUpdateDtoSecurityStateEnumTypeTransformer._();

  const AdminUserUpdateDtoSecurityStateEnumTypeTransformer._();

  String encode(AdminUserUpdateDtoSecurityStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminUserUpdateDtoSecurityStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminUserUpdateDtoSecurityStateEnum? decode(dynamic data,
      {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'normal':
          return AdminUserUpdateDtoSecurityStateEnum.normal;
        case r'password_disabled':
          return AdminUserUpdateDtoSecurityStateEnum.passwordDisabled;
        case r'compromised':
          return AdminUserUpdateDtoSecurityStateEnum.compromised;
        case r'secured_manual_recovery_required':
          return AdminUserUpdateDtoSecurityStateEnum
              .securedManualRecoveryRequired;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminUserUpdateDtoSecurityStateEnumTypeTransformer] instance.
  static AdminUserUpdateDtoSecurityStateEnumTypeTransformer? _instance;
}
