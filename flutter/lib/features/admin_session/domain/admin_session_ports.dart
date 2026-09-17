import 'admin_session_models.dart';

/// Transport boundary for the admin-only cookie/MFA flow.
///
/// Implementations own the browser cookie, CSRF rotation, HTTP client and
/// disposal. This port has no consumer JWT, refresh credential, Drift or
/// secure-storage concept.
abstract interface class AdminSessionTransport {
  Future<AdminBootstrap> bootstrap();

  Future<AdminLoginChallenge> beginLogin({
    required String username,
    required String password,
  });

  Future<AdminSessionSnapshot> completeMfa({
    required String challengeId,
    required String code,
  });

  Future<AdminSessionSnapshot?> restore();

  Future<void> logout();
}
