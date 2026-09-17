enum AdminSecurityStatus {
  normal,
  passwordDisabled,
  compromised,
  securedManualRecoveryRequired,
  deleted,
}

final class AdminUsersTransportException implements Exception {
  const AdminUsersTransportException(this.statusCode);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin users request failed ($statusCode)';
}

class AdminUserRecord {
  AdminUserRecord({
    required this.id,
    required this.username,
    required this.email,
    required this.emailVerified,
    required this.securityStatus,
    required this.createdAt,
    required this.isAdmin,
    required this.passwordDisabled,
    required this.passwordResetRequired,
    required this.authGeneration,
    required List<String> eligibilityReasons,
  }) : eligibilityReasons = List.unmodifiable(eligibilityReasons);

  final String id;
  final String username;
  final String? email;
  final bool emailVerified;
  final AdminSecurityStatus securityStatus;
  final DateTime createdAt;
  final bool isAdmin;
  final bool passwordDisabled;
  final bool passwordResetRequired;
  final int authGeneration;
  final List<String> eligibilityReasons;

  @override
  String toString() =>
      'AdminUserRecord(id: $id, username: $username, securityStatus: $securityStatus)';
}

final class AdminUserDetails extends AdminUserRecord {
  AdminUserDetails({
    required super.id,
    required super.username,
    required super.email,
    required super.emailVerified,
    required super.securityStatus,
    required super.createdAt,
    required super.isAdmin,
    required super.passwordDisabled,
    required super.passwordResetRequired,
    required super.authGeneration,
    required super.eligibilityReasons,
    required this.communicationOptOut,
    required this.registeredDeviceCount,
    this.compromisedAt,
  });

  final bool communicationOptOut;
  final int registeredDeviceCount;
  final DateTime? compromisedAt;
}

final class AdminUserPage {
  AdminUserPage({required List<AdminUserRecord> items, this.nextCursor})
    : items = List.unmodifiable(items);

  final List<AdminUserRecord> items;
  final String? nextCursor;
}

final class AdminUserQuery {
  const AdminUserQuery({this.search = '', this.cursor, this.limit = 25});

  final String search;
  final String? cursor;
  final int limit;

  @override
  String toString() =>
      'AdminUserQuery(search: $search, cursor: $cursor, limit: $limit)';
}
