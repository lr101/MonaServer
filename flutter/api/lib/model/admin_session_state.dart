//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminSessionState {
  /// Instantiate a new enum with the provided [value].
  const AdminSessionState._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const preAuthentication = AdminSessionState._(r'pre_authentication');
  static const mfaRequired = AdminSessionState._(r'mfa_required');
  static const authenticated = AdminSessionState._(r'authenticated');

  /// List of all possible values in this [enum][AdminSessionState].
  static const values = <AdminSessionState>[
    preAuthentication,
    mfaRequired,
    authenticated,
  ];

  static AdminSessionState? fromJson(dynamic value) => AdminSessionStateTypeTransformer().decode(value);

  static List<AdminSessionState> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminSessionState>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminSessionState.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminSessionState] to String,
/// and [decode] dynamic data back to [AdminSessionState].
class AdminSessionStateTypeTransformer {
  factory AdminSessionStateTypeTransformer() => _instance ??= const AdminSessionStateTypeTransformer._();

  const AdminSessionStateTypeTransformer._();

  String encode(AdminSessionState data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminSessionState.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminSessionState? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'pre_authentication': return AdminSessionState.preAuthentication;
        case r'mfa_required': return AdminSessionState.mfaRequired;
        case r'authenticated': return AdminSessionState.authenticated;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminSessionStateTypeTransformer] instance.
  static AdminSessionStateTypeTransformer? _instance;
}

