//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AdminSessionLoginResponseDto {
  /// Returns a new [AdminSessionLoginResponseDto] instance.
  AdminSessionLoginResponseDto({
    required this.challengeId,
    required this.csrfToken,
    required this.expiresAt,
    required this.sessionState,
  });

  String challengeId;

  String csrfToken;

  DateTime expiresAt;

  AdminSessionLoginResponseDtoSessionStateEnum sessionState;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AdminSessionLoginResponseDto &&
    other.challengeId == challengeId &&
    other.csrfToken == csrfToken &&
    other.expiresAt == expiresAt &&
    other.sessionState == sessionState;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (challengeId.hashCode) +
    (csrfToken.hashCode) +
    (expiresAt.hashCode) +
    (sessionState.hashCode);

  @override
  String toString() => 'AdminSessionLoginResponseDto[challengeId=$challengeId, csrfToken=$csrfToken, expiresAt=$expiresAt, sessionState=$sessionState]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'challengeId'] = this.challengeId;
      json[r'csrfToken'] = this.csrfToken;
      json[r'expiresAt'] = this.expiresAt.toUtc().toIso8601String();
      json[r'sessionState'] = this.sessionState;
    return json;
  }

  /// Returns a new [AdminSessionLoginResponseDto] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AdminSessionLoginResponseDto? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "AdminSessionLoginResponseDto[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "AdminSessionLoginResponseDto[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return AdminSessionLoginResponseDto(
        challengeId: mapValueOfType<String>(json, r'challengeId')!,
        csrfToken: mapValueOfType<String>(json, r'csrfToken')!,
        expiresAt: mapDateTime(json, r'expiresAt', r'')!,
        sessionState: AdminSessionLoginResponseDtoSessionStateEnum.fromJson(json[r'sessionState'])!,
      );
    }
    return null;
  }

  static List<AdminSessionLoginResponseDto> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionLoginResponseDto>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionLoginResponseDto.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AdminSessionLoginResponseDto> mapFromJson(dynamic json) {
    final map = <String, AdminSessionLoginResponseDto>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AdminSessionLoginResponseDto.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AdminSessionLoginResponseDto-objects as value to a dart map
  static Map<String, List<AdminSessionLoginResponseDto>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AdminSessionLoginResponseDto>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AdminSessionLoginResponseDto.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'challengeId',
    'csrfToken',
    'expiresAt',
    'sessionState',
  };
}


class AdminSessionLoginResponseDtoSessionStateEnum {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionLoginResponseDtoSessionStateEnum._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const mfaRequired = AdminSessionLoginResponseDtoSessionStateEnum._(r'mfa_required');

  /// List of all possible values in this [enum][AdminSessionLoginResponseDtoSessionStateEnum].
  static const values = <AdminSessionLoginResponseDtoSessionStateEnum>[
    mfaRequired,
  ];

  static AdminSessionLoginResponseDtoSessionStateEnum? fromJson(dynamic value) => AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer().decode(value);

  static List<AdminSessionLoginResponseDtoSessionStateEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionLoginResponseDtoSessionStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionLoginResponseDtoSessionStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionLoginResponseDtoSessionStateEnum] to String,
/// and [decode] dynamic data back to [AdminSessionLoginResponseDtoSessionStateEnum].
class AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer {
  factory AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer() => _instance ??= const AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer._();

  const AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer._();

  String encode(AdminSessionLoginResponseDtoSessionStateEnum data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionLoginResponseDtoSessionStateEnum.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionLoginResponseDtoSessionStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'mfa_required': return AdminSessionLoginResponseDtoSessionStateEnum.mfaRequired;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer] instance.
  static AdminSessionLoginResponseDtoSessionStateEnumTypeTransformer? _instance;
}


