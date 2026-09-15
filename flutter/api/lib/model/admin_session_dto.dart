//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionDto {
  /// Returns a new [AdminSessionDto] instance.
  AdminSessionDto({
    required this.authenticatedAt,
    this.capabilities = const [],
    required this.csrfToken,
    required this.idleExpiresAt,
    required this.lastActivityAt,
    this.permissions = const [],
    this.recentMfaAt,
    required this.sessionId,
    required this.sessionState,
    required this.userId,
    required this.username,
  });

  DateTime authenticatedAt;

  List<String> capabilities;

  String csrfToken;

  DateTime idleExpiresAt;

  DateTime lastActivityAt;

  List<String> permissions;

  DateTime? recentMfaAt;

  String sessionId;

  AdminSessionDtoSessionStateEnum sessionState;

  String userId;

  String username;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionDto &&
    other.authenticatedAt == authenticatedAt &&
    _deepEquality.equals(other.capabilities, capabilities) &&
    other.csrfToken == csrfToken &&
    other.idleExpiresAt == idleExpiresAt &&
    other.lastActivityAt == lastActivityAt &&
    _deepEquality.equals(other.permissions, permissions) &&
    other.recentMfaAt == recentMfaAt &&
    other.sessionId == sessionId &&
    other.sessionState == sessionState &&
    other.userId == userId &&
    other.username == username;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (authenticatedAt.hashCode) +
    (capabilities.hashCode) +
    (csrfToken.hashCode) +
    (idleExpiresAt.hashCode) +
    (lastActivityAt.hashCode) +
    (permissions.hashCode) +
    (recentMfaAt == null ? 0 : recentMfaAt!.hashCode) +
    (sessionId.hashCode) +
    (sessionState.hashCode) +
    (userId.hashCode) +
    (username.hashCode);

  @override
  String toString() => 'AdminSessionDto[authenticatedAt=$authenticatedAt, capabilities=$capabilities, csrfToken=$csrfToken, idleExpiresAt=$idleExpiresAt, lastActivityAt=$lastActivityAt, permissions=$permissions, recentMfaAt=$recentMfaAt, sessionId=$sessionId, sessionState=$sessionState, userId=$userId, username=$username]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'authenticatedAt'] = this.authenticatedAt.toUtc().toIso8601String();
      json[r'capabilities'] = this.capabilities;
      json[r'csrfToken'] = this.csrfToken;
      json[r'idleExpiresAt'] = this.idleExpiresAt.toUtc().toIso8601String();
      json[r'lastActivityAt'] = this.lastActivityAt.toUtc().toIso8601String();
      json[r'permissions'] = this.permissions;
    if (this.recentMfaAt != null) {
      json[r'recentMfaAt'] = this.recentMfaAt!.toUtc().toIso8601String();
    } else {
      json[r'recentMfaAt'] = null;
    }
      json[r'sessionId'] = this.sessionId;
      json[r'sessionState'] = this.sessionState;
      json[r'userId'] = this.userId;
      json[r'username'] = this.username;
    return json;
  }

  /// Returns a new [AdminSessionDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionDto(
        authenticatedAt: mapDateTime(json, r'authenticatedAt', r'')!,
        capabilities: json[r'capabilities'] is Iterable
            ? (json[r'capabilities'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        csrfToken: mapValueOfType<String>(json, r'csrfToken')!,
        idleExpiresAt: mapDateTime(json, r'idleExpiresAt', r'')!,
        lastActivityAt: mapDateTime(json, r'lastActivityAt', r'')!,
        permissions: json[r'permissions'] is Iterable
            ? (json[r'permissions'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        recentMfaAt: mapDateTime(json, r'recentMfaAt', r''),
        sessionId: mapValueOfType<String>(json, r'sessionId')!,
        sessionState: AdminSessionDtoSessionStateEnum.fromJson(json[r'sessionState'])!,
        userId: mapValueOfType<String>(json, r'userId')!,
        username: mapValueOfType<String>(json, r'username')!,
      );
    }
    return null;
  }

  static List<AdminSessionDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionDto> mapFromJson(dynamic json) {
    final map = <String, AdminSessionDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionDto-objects as value to a dart map
  static Map<String, List<AdminSessionDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'authenticatedAt',
    'capabilities',
    'csrfToken',
    'idleExpiresAt',
    'lastActivityAt',
    'permissions',
    'sessionId',
    'sessionState',
    'userId',
    'username',
  };
}


class AdminSessionDtoSessionStateEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionDtoSessionStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const authenticated = AdminSessionDtoSessionStateEnum._(r'authenticated');

  /// List of all possible values in this [enum][AdminSessionDtoSessionStateEnum].
  static const values = <AdminSessionDtoSessionStateEnum>[
    authenticated,
  ];

  static AdminSessionDtoSessionStateEnum? fromJson(dynamic value) => AdminSessionDtoSessionStateEnumTypeTransformer().decode(value);

  static List<AdminSessionDtoSessionStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionDtoSessionStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionDtoSessionStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionDtoSessionStateEnum] to String,
/// and [decode] dynamic data back to [AdminSessionDtoSessionStateEnum].
class AdminSessionDtoSessionStateEnumTypeTransformer {
  factory AdminSessionDtoSessionStateEnumTypeTransformer() => _instance ??= const AdminSessionDtoSessionStateEnumTypeTransformer._();

  const AdminSessionDtoSessionStateEnumTypeTransformer._();

  String encode(AdminSessionDtoSessionStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionDtoSessionStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionDtoSessionStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'authenticated': return AdminSessionDtoSessionStateEnum.authenticated;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionDtoSessionStateEnumTypeTransformer] instance.
  static AdminSessionDtoSessionStateEnumTypeTransformer? _instance;
}


