//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminSecurityState {
  /// Instantiate a new enum with the provided [value].
  const AdminSecurityState._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const normal = AdminSecurityState._(r'normal');
  static const passwordDisabled = AdminSecurityState._(r'password_disabled');
  static const compromised = AdminSecurityState._(r'compromised');
  static const securedManualRecoveryRequired = AdminSecurityState._(r'secured_manual_recovery_required');
  static const deleted = AdminSecurityState._(r'deleted');

  /// List of all possible values in this [enum][AdminSecurityState].
  static const values = <AdminSecurityState>[
    normal,
    passwordDisabled,
    compromised,
    securedManualRecoveryRequired,
    deleted,
  ];

  static AdminSecurityState? fromJson(dynamic value) => AdminSecurityStateTypeTransformer().decode(value);

  static List<AdminSecurityState> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSecurityState>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSecurityState.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSecurityState] to String,
/// and [decode] dynamic data back to [AdminSecurityState].
class AdminSecurityStateTypeTransformer {
  factory AdminSecurityStateTypeTransformer() => _instance ??= const AdminSecurityStateTypeTransformer._();

  const AdminSecurityStateTypeTransformer._();

  String encode(AdminSecurityState data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSecurityState.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSecurityState? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'normal': return AdminSecurityState.normal;
        case r'password_disabled': return AdminSecurityState.passwordDisabled;
        case r'compromised': return AdminSecurityState.compromised;
        case r'secured_manual_recovery_required': return AdminSecurityState.securedManualRecoveryRequired;
        case r'deleted': return AdminSecurityState.deleted;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSecurityStateTypeTransformer] instance.
  static AdminSecurityStateTypeTransformer? _instance;
}

