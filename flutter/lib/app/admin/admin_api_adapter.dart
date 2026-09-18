import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

import '../../features/admin_session/domain/admin_session_models.dart';
import '../../features/admin_session/domain/admin_session_ports.dart';
import '../../features/admin_users/domain/admin_user_models.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import 'admin_http_client.dart';

/// Generated-client adapter for the admin-only transport boundary.
///
/// The adapter owns one HTTP client and the in-memory CSRF value. It uses the
/// server's host-only opaque cookie and never constructs or persists consumer
/// JWT/refresh credentials.
final class AdminApiAdapter
    implements AdminSessionTransport, AdminUsersRepository {
  AdminApiAdapter({required String basePath, http.Client? client})
    : _ownsClient = client == null,
      _client = client ?? createAdminHttpClient(),
      _apiClient = ApiClient(basePath: basePath) {
    _apiClient.client = _client;
    _sessionApi = AdminSessionApi(_apiClient);
    _usersApi = AdminUsersApi(_apiClient);
  }

  final bool _ownsClient;
  final http.Client _client;
  final ApiClient _apiClient;
  late final AdminSessionApi _sessionApi;
  late final AdminUsersApi _usersApi;
  String? _csrfToken;
  bool _closed = false;

  @override
  Future<AdminBootstrap> bootstrap() async {
    _checkOpen();
    try {
      final response = await _sessionApi.bootstrapAdminSession();
      if (response == null) throw const AdminTransportException(502);
      if (response.csrfToken.trim().isEmpty) {
        throw const AdminTransportException(428);
      }
      _csrfToken = response.csrfToken;
      return AdminBootstrap(
        csrfToken: response.csrfToken,
        expiresAt: response.expiresAt,
      );
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminLoginChallenge> beginLogin({
    required String username,
    required String password,
  }) async {
    _checkOpen();
    try {
      var csrfToken = _csrfToken;
      // Logout and an expired session deliberately clear the in-memory CSRF
      // value. A login is allowed to start a fresh pre-auth cookie lifecycle
      // instead of surfacing an opaque "precondition" failure to the user.
      if (csrfToken == null || csrfToken.isEmpty) {
        final bootstrap = await this.bootstrap();
        if (bootstrap.csrfToken.isEmpty) {
          throw const AdminTransportException(428);
        }
        csrfToken = bootstrap.csrfToken;
      }
      final response = await _sessionApi.adminSessionLogin(
        csrfToken,
        AdminSessionLoginRequestDto(username: username, password: password),
      );
      if (response == null) throw const AdminTransportException(502);
      _csrfToken = response.csrfToken;
      return AdminLoginChallenge(
        challengeId: response.challengeId,
        expiresAt: response.expiresAt,
      );
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminSessionSnapshot> completeMfa({
    required String challengeId,
    required String code,
  }) async {
    _checkOpen();
    final csrfToken = _csrfToken;
    if (csrfToken == null || csrfToken.isEmpty) {
      throw const AdminTransportException(428);
    }
    try {
      final response = await _sessionApi.completeAdminSessionMfa(
        csrfToken,
        AdminMfaRequestDto(challengeId: challengeId, code: code),
      );
      if (response == null) throw const AdminTransportException(502);
      _csrfToken = response.csrfToken;
      return _sessionFromDto(response);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminSessionSnapshot?> restore() async {
    _checkOpen();
    try {
      final response = await _sessionApi.getAdminSession();
      if (response == null) return null;
      _csrfToken = response.csrfToken;
      return _sessionFromDto(response);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<void> logout() async {
    if (_closed) return;
    final csrfToken = _csrfToken;
    _csrfToken = null;
    if (csrfToken == null || csrfToken.isEmpty) return;
    try {
      await _sessionApi.logoutAdminSession(csrfToken);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    _checkOpen();
    try {
      final response = await _usersApi.listAdminUsers(
        cursor: query.cursor,
        limit: query.limit,
        search: query.search.isEmpty ? null : query.search,
      );
      if (response == null) throw const AdminUsersTransportException(502);
      return AdminUserPage(
        items: response.items.map(_userFromDto).toList(growable: false),
        nextCursor: response.nextCursor,
      );
    } catch (error) {
      throw _mapUsersError(error);
    }
  }

  @override
  Future<AdminUserDetails?> getUser(String userId) async {
    _checkOpen();
    try {
      final response = await _usersApi.getAdminUser(userId);
      return response == null ? null : _detailsFromDto(response);
    } catch (error) {
      throw _mapUsersError(error);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _csrfToken = null;
    if (_ownsClient) _client.close();
  }

  void _checkOpen() {
    if (_closed) throw const AdminTransportException(499);
  }

  AdminTransportException _mapSessionError(Object error) {
    if (error is AdminTransportException) {
      if (error.isUnauthorized) _csrfToken = null;
      return error;
    }
    if (error is ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminTransportException(error.code);
    }
    return const AdminTransportException(503);
  }

  AdminUsersTransportException _mapUsersError(Object error) {
    if (error is AdminUsersTransportException) {
      if (error.isUnauthorized) _csrfToken = null;
      return error;
    }
    if (error is ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminUsersTransportException(error.code);
    }
    return const AdminUsersTransportException(503);
  }

  AdminSessionSnapshot _sessionFromDto(AdminSessionDto dto) =>
      AdminSessionSnapshot(
        sessionId: dto.sessionId,
        userId: dto.userId,
        username: dto.username,
        csrfToken: dto.csrfToken,
        capabilities: dto.capabilities.toSet(),
        permissions: dto.permissions.toSet(),
        authenticatedAt: dto.authenticatedAt,
        lastActivityAt: dto.lastActivityAt,
        idleExpiresAt: dto.idleExpiresAt,
        recentMfaAt: dto.recentMfaAt,
      );

  AdminUserRecord _userFromDto(AdminUserDto dto) => AdminUserRecord(
    id: dto.id,
    username: dto.username,
    email: dto.email,
    emailVerified: dto.emailVerified,
    securityStatus: _securityStatus(dto.securityState),
    createdAt: dto.createdAt,
    isAdmin: dto.isAdmin,
    passwordDisabled: dto.passwordDisabled,
    passwordResetRequired: dto.passwordResetRequired,
    authGeneration: dto.authGeneration,
    eligibilityReasons: dto.eligibilityReasons,
  );

  AdminUserDetails _detailsFromDto(AdminUserDetailsDto dto) => AdminUserDetails(
    id: dto.id,
    username: dto.username,
    email: dto.email,
    emailVerified: dto.emailVerified,
    securityStatus: _securityStatus(dto.securityState),
    createdAt: dto.createdAt,
    isAdmin: dto.isAdmin,
    passwordDisabled: dto.passwordDisabled,
    passwordResetRequired: dto.passwordResetRequired,
    authGeneration: dto.authGeneration,
    eligibilityReasons: dto.eligibilityReasons,
    compromisedAt: dto.compromisedAt,
    communicationOptOut: dto.communicationOptOut,
    registeredDeviceCount: dto.registeredDeviceCount,
  );

  AdminSecurityStatus _securityStatus(AdminSecurityState state) {
    switch (state.value) {
      case 'password_disabled':
        return AdminSecurityStatus.passwordDisabled;
      case 'compromised':
        return AdminSecurityStatus.compromised;
      case 'secured_manual_recovery_required':
        return AdminSecurityStatus.securedManualRecoveryRequired;
      case 'deleted':
        return AdminSecurityStatus.deleted;
      case 'normal':
      default:
        return AdminSecurityStatus.normal;
    }
  }
}
