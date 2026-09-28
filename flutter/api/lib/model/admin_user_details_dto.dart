//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminUserDetailsDto {
  /// Returns a new [AdminUserDetailsDto] instance.
  AdminUserDetailsDto({
    required this.authGeneration,
    this.compromisedAt,
    required this.createdAt,
    this.email,
    required this.emailVerified,
    this.eligibilityReasons = const [],
    required this.id,
    required this.isAdmin,
    required this.passwordDisabled,
    required this.passwordResetRequired,
    required this.securityState,
    required this.username,
    required this.communicationOptOut,
    required this.registeredDeviceCount,
  });

  /// Minimum value: 0
  int authGeneration;

  DateTime? compromisedAt;

  DateTime createdAt;

  String? email;

  bool emailVerified;

  List<String> eligibilityReasons;

  String id;

  bool isAdmin;

  bool passwordDisabled;

  bool passwordResetRequired;

  AdminSecurityState securityState;

  String username;

  bool communicationOptOut;

  /// Minimum value: 0
  int registeredDeviceCount;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminUserDetailsDto &&
    other.authGeneration == authGeneration &&
    other.compromisedAt == compromisedAt &&
    other.createdAt == createdAt &&
    other.email == email &&
    other.emailVerified == emailVerified &&
    _deepEquality.equals(other.eligibilityReasons, eligibilityReasons) &&
    other.id == id &&
    other.isAdmin == isAdmin &&
    other.passwordDisabled == passwordDisabled &&
    other.passwordResetRequired == passwordResetRequired &&
    other.securityState == securityState &&
    other.username == username &&
    other.communicationOptOut == communicationOptOut &&
    other.registeredDeviceCount == registeredDeviceCount;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (authGeneration.hashCode) +
    (compromisedAt == null ? 0 : compromisedAt!.hashCode) +
    (createdAt.hashCode) +
    (email == null ? 0 : email!.hashCode) +
    (emailVerified.hashCode) +
    (eligibilityReasons.hashCode) +
    (id.hashCode) +
    (isAdmin.hashCode) +
    (passwordDisabled.hashCode) +
    (passwordResetRequired.hashCode) +
    (securityState.hashCode) +
    (username.hashCode) +
    (communicationOptOut.hashCode) +
    (registeredDeviceCount.hashCode);

  @override
  String toString() => 'AdminUserDetailsDto[authGeneration=$authGeneration, compromisedAt=$compromisedAt, createdAt=$createdAt, email=$email, emailVerified=$emailVerified, eligibilityReasons=$eligibilityReasons, id=$id, isAdmin=$isAdmin, passwordDisabled=$passwordDisabled, passwordResetRequired=$passwordResetRequired, securityState=$securityState, username=$username, communicationOptOut=$communicationOptOut, registeredDeviceCount=$registeredDeviceCount]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'authGeneration'] = this.authGeneration;
    if (this.compromisedAt != null) {
      json[r'compromisedAt'] = this.compromisedAt!.toUtc().toIso8601String();
    } else {
      json[r'compromisedAt'] = null;
    }
      json[r'createdAt'] = this.createdAt.toUtc().toIso8601String();
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
      json[r'emailVerified'] = this.emailVerified;
      json[r'eligibilityReasons'] = this.eligibilityReasons;
      json[r'id'] = this.id;
      json[r'isAdmin'] = this.isAdmin;
      json[r'passwordDisabled'] = this.passwordDisabled;
      json[r'passwordResetRequired'] = this.passwordResetRequired;
      json[r'securityState'] = this.securityState;
      json[r'username'] = this.username;
      json[r'communicationOptOut'] = this.communicationOptOut;
      json[r'registeredDeviceCount'] = this.registeredDeviceCount;
    return json;
  }

  /// Returns a new [AdminUserDetailsDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminUserDetailsDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminUserDetailsDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminUserDetailsDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminUserDetailsDto(
        authGeneration: mapValueOfType<int>(json, r'authGeneration')!,
        compromisedAt: mapDateTime(json, r'compromisedAt', r''),
        createdAt: mapDateTime(json, r'createdAt', r'')!,
        email: mapValueOfType<String>(json, r'email'),
        emailVerified: mapValueOfType<bool>(json, r'emailVerified')!,
        eligibilityReasons: json[r'eligibilityReasons'] is Iterable
            ? (json[r'eligibilityReasons'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        id: mapValueOfType<String>(json, r'id')!,
        isAdmin: mapValueOfType<bool>(json, r'isAdmin')!,
        passwordDisabled: mapValueOfType<bool>(json, r'passwordDisabled')!,
        passwordResetRequired: mapValueOfType<bool>(json, r'passwordResetRequired')!,
        securityState: AdminSecurityState.fromJson(json[r'securityState'])!,
        username: mapValueOfType<String>(json, r'username')!,
        communicationOptOut: mapValueOfType<bool>(json, r'communicationOptOut')!,
        registeredDeviceCount: mapValueOfType<int>(json, r'registeredDeviceCount')!,
      );
    }
    return null;
  }

  static List<AdminUserDetailsDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminUserDetailsDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminUserDetailsDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminUserDetailsDto> mapFromJson(dynamic json) {
    final map = <String, AdminUserDetailsDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminUserDetailsDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminUserDetailsDto-objects as value to a dart map
  static Map<String, List<AdminUserDetailsDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminUserDetailsDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminUserDetailsDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'authGeneration',
    'createdAt',
    'emailVerified',
    'eligibilityReasons',
    'id',
    'isAdmin',
    'passwordDisabled',
    'passwordResetRequired',
    'securityState',
    'username',
    'communicationOptOut',
    'registeredDeviceCount',
  };
}

