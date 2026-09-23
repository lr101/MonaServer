//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


class AdminActionKind {
  /// Instantiate a new enum with the provided [value].
  const AdminActionKind._(this.value);

  /// The underlying value of this enum member.
  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static const email = AdminActionKind._(r'email');
  static const loginLink = AdminActionKind._(r'login_link');
  static const push = AdminActionKind._(r'push');
  static const revokeSessions = AdminActionKind._(r'revoke_sessions');
  static const markCompromised = AdminActionKind._(r'mark_compromised');
  static const recoveryResend = AdminActionKind._(r'recovery_resend');
  static const reportResolve = AdminActionKind._(r'report_resolve');
  static const reportDismiss = AdminActionKind._(r'report_dismiss');
  static const jobsPeriodControl = AdminActionKind._(r'jobs.control');
  static const messagesPeriodTest = AdminActionKind._(r'messages.test');
  static const reportsPeriodReview = AdminActionKind._(r'reports.review');
  static const campaignsPeriodWrite = AdminActionKind._(r'campaigns.write');

  /// List of all possible values in this [enum][AdminActionKind].
  static const values = <AdminActionKind>[
    email,
    loginLink,
    push,
    revokeSessions,
    markCompromised,
    recoveryResend,
    reportResolve,
    reportDismiss,
    jobsPeriodControl,
    messagesPeriodTest,
    reportsPeriodReview,
    campaignsPeriodWrite,
  ];

  static AdminActionKind? fromJson(dynamic value) => AdminActionKindTypeTransformer().decode(value);

  static List<AdminActionKind> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AdminActionKind>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AdminActionKind.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AdminActionKind] to String,
/// and [decode] dynamic data back to [AdminActionKind].
class AdminActionKindTypeTransformer {
  factory AdminActionKindTypeTransformer() => _instance ??= const AdminActionKindTypeTransformer._();

  const AdminActionKindTypeTransformer._();

  String encode(AdminActionKind data) => data.value;

  /// Decodes a [dynamic value][data] to a AdminActionKind.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AdminActionKind? decode(dynamic data, {bool allowNull = true}) {
    if (data != null) {
      switch (data) {
        case r'email': return AdminActionKind.email;
        case r'login_link': return AdminActionKind.loginLink;
        case r'push': return AdminActionKind.push;
        case r'revoke_sessions': return AdminActionKind.revokeSessions;
        case r'mark_compromised': return AdminActionKind.markCompromised;
        case r'recovery_resend': return AdminActionKind.recoveryResend;
        case r'report_resolve': return AdminActionKind.reportResolve;
        case r'report_dismiss': return AdminActionKind.reportDismiss;
        case r'jobs.control': return AdminActionKind.jobsPeriodControl;
        case r'messages.test': return AdminActionKind.messagesPeriodTest;
        case r'reports.review': return AdminActionKind.reportsPeriodReview;
        case r'campaigns.write': return AdminActionKind.campaignsPeriodWrite;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// Singleton [AdminActionKindTypeTransformer] instance.
  static AdminActionKindTypeTransformer? _instance;
}
