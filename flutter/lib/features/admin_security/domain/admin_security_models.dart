import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';

enum AdminSecurityActionKind { revokeSessions, compromise, recoveryResend }

final class AdminSecurityRequest {
  const AdminSecurityRequest._({
    required this.kind,
    required this.reason,
    this.includeAdministrators = false,
  });

  const AdminSecurityRequest.revoke({
    required String reason,
    bool includeAdministrators = false,
  }) : this._(
         kind: AdminSecurityActionKind.revokeSessions,
         reason: reason,
         includeAdministrators: includeAdministrators,
       );

  const AdminSecurityRequest.compromise({
    required String reason,
    bool includeAdministrators = false,
  }) : this._(
         kind: AdminSecurityActionKind.compromise,
         reason: reason,
         includeAdministrators: includeAdministrators,
       );

  const AdminSecurityRequest.recoveryResend({
    required String reason,
    bool includeAdministrators = false,
  }) : this._(
         kind: AdminSecurityActionKind.recoveryResend,
         reason: reason,
         includeAdministrators: includeAdministrators,
       );

  final AdminSecurityActionKind kind;
  final String reason;
  final bool includeAdministrators;

  bool get isValid => reason.trim().isNotEmpty;

  AdminAudienceAction get action => AdminAudienceAction(
    kind: switch (kind) {
      AdminSecurityActionKind.revokeSessions =>
        AdminAudienceActionKind.revokeSessions,
      AdminSecurityActionKind.compromise =>
        AdminAudienceActionKind.markCompromised,
      AdminSecurityActionKind.recoveryResend =>
        AdminAudienceActionKind.recoveryResend,
    },
    reason: reason.trim(),
  );
}

/// One contract is used for selected, filter, and all-account security work.
final class AdminSecurityActionRequest {
  const AdminSecurityActionRequest({
    required this.audience,
    required this.request,
    required this.administratorInclusionAcknowledged,
    required this.idempotencyKey,
  });

  final AdminAudienceSelection audience;
  final AdminSecurityRequest request;
  final bool administratorInclusionAcknowledged;
  final String idempotencyKey;

  bool get isValid =>
      audience.isActionable &&
      request.isValid &&
      (!request.includeAdministrators || administratorInclusionAcknowledged);
}

enum AdminSecurityOutcome {
  queued,
  secured,
  securedManualRecoveryRequired,
  recoveryQueued,
}

final class AdminSecurityResult {
  const AdminSecurityResult({required this.jobId, required this.outcome});

  final String jobId;
  final AdminSecurityOutcome outcome;

  bool get manualRecoveryRequired =>
      outcome == AdminSecurityOutcome.securedManualRecoveryRequired;

  /// Security containment never offers a normal sign-in route.
  bool get ordinarySignInAvailable => false;
}

final class AdminSecurityTransportException implements Exception {
  const AdminSecurityTransportException(this.statusCode);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin security request failed ($statusCode)';
}
