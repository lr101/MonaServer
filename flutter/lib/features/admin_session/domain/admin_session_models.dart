/// The states an administrator can be in while the independent admin entry
/// point restores or changes its cookie session.
enum AdminSessionPhase {
  restoring,
  signedOut,
  mfaRequired,
  signedIn,
  expired,
  unavailable,
}

/// A safe, status-only transport failure. Response bodies are deliberately
/// discarded by the adapter so server details never become UI diagnostics.
final class AdminTransportException implements Exception {
  const AdminTransportException(this.statusCode);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin transport request failed ($statusCode)';
}

final class AdminBootstrap {
  const AdminBootstrap({required this.csrfToken, required this.expiresAt});

  final String csrfToken;
  final DateTime expiresAt;

  @override
  String toString() =>
      'AdminBootstrap(expiresAt: $expiresAt, csrfToken: [redacted])';
}

final class AdminLoginChallenge {
  const AdminLoginChallenge({
    required this.challengeId,
    required this.expiresAt,
  });

  final String challengeId;
  final DateTime expiresAt;

  @override
  String toString() =>
      'AdminLoginChallenge(expiresAt: $expiresAt, challengeId: [redacted])';
}

/// Authenticated admin session metadata. Cookie and CSRF values stay in
/// memory for the lifetime of the adapter/controller and are never persisted.
final class AdminSessionSnapshot {
  AdminSessionSnapshot({
    required this.sessionId,
    required this.userId,
    required this.username,
    required this.csrfToken,
    required Set<String> capabilities,
    required Set<String> permissions,
    required this.authenticatedAt,
    required this.lastActivityAt,
    required this.idleExpiresAt,
    this.recentMfaAt,
  }) : capabilities = Set.unmodifiable(capabilities),
       permissions = Set.unmodifiable(permissions);

  final String sessionId;
  final String userId;
  final String username;
  final String csrfToken;
  final Set<String> capabilities;
  final Set<String> permissions;
  final DateTime authenticatedAt;
  final DateTime lastActivityAt;
  final DateTime idleExpiresAt;
  final DateTime? recentMfaAt;

  bool can(String capability) =>
      capabilities.contains('*') || capabilities.contains(capability);

  @override
  String toString() =>
      'AdminSessionSnapshot(sessionId: [redacted], userId: $userId, '
      'username: $username, csrfToken: [redacted], capabilities: $capabilities)';
}

final class AdminSessionState {
  const AdminSessionState({
    required this.phase,
    this.session,
    this.challenge,
    this.message,
    this.capabilityDenied = false,
  });

  const AdminSessionState.restoring()
    : this(phase: AdminSessionPhase.restoring);

  const AdminSessionState.signedOut({String? message})
    : this(phase: AdminSessionPhase.signedOut, message: message);

  final AdminSessionPhase phase;
  final AdminSessionSnapshot? session;
  final AdminLoginChallenge? challenge;
  final String? message;
  final bool capabilityDenied;

  bool get isAuthenticated =>
      phase == AdminSessionPhase.signedIn && session != null;

  AdminSessionState copyWith({
    AdminSessionPhase? phase,
    AdminSessionSnapshot? session,
    bool clearSession = false,
    AdminLoginChallenge? challenge,
    bool clearChallenge = false,
    String? message,
    bool clearMessage = false,
    bool? capabilityDenied,
  }) {
    return AdminSessionState(
      phase: phase ?? this.phase,
      session: clearSession ? null : session ?? this.session,
      challenge: clearChallenge ? null : challenge ?? this.challenge,
      message: clearMessage ? null : message ?? this.message,
      capabilityDenied: capabilityDenied ?? this.capabilityDenied,
    );
  }

  @override
  String toString() =>
      'AdminSessionState(phase: $phase, session: ${session == null ? 'none' : '[present]'}, '
      'challenge: ${challenge == null ? 'none' : '[present]'}, '
      'message: $message, capabilityDenied: $capabilityDenied)';
}
