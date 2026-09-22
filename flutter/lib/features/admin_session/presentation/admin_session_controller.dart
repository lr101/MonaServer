import 'dart:async';

import '../domain/admin_session_models.dart';
import '../domain/admin_session_ports.dart';

typedef AdminSessionListener = void Function(AdminSessionState state);

/// Owns the short-lived admin UI state and fences late transport responses.
///
/// The controller intentionally accepts passwords and MFA codes only as method
/// arguments. It never stores either value in state, preferences, or a model.
final class AdminSessionController {
  AdminSessionController(this.transport);

  final AdminSessionTransport transport;
  final _listeners = <AdminSessionListener>{};
  AdminSessionState _state = const AdminSessionState.signedOut();
  Future<AdminBootstrap>? _preAuthBootstrap;
  bool _retainCompletedPreAuth = false;
  Future<void>? _logoutInFlight;
  int _bootstrapGeneration = 0;
  int _operation = 0;
  bool _disposed = false;

  AdminSessionState get state => _state;

  void addListener(AdminSessionListener listener) => _listeners.add(listener);

  void removeListener(AdminSessionListener listener) =>
      _listeners.remove(listener);

  Future<void> restore() async {
    if (_disposed) return;
    await _waitForLogout();
    if (_disposed) return;
    final operation = ++_operation;
    _emit(const AdminSessionState.restoring());
    try {
      // Bootstrap establishes the pre-authentication CSRF cookie/header pair.
      await _ensurePreAuth();
      if (!_isCurrent(operation)) return;
      final session = await transport.restore();
      if (!_isCurrent(operation)) return;
      if (session == null) {
        _emit(const AdminSessionState.signedOut());
      } else {
        _emit(
          AdminSessionState(
            phase: AdminSessionPhase.signedIn,
            session: session,
          ),
        );
      }
    } on AdminTransportException catch (error) {
      if (!_isCurrent(operation)) return;
      _handleFailure(error, restoring: true);
    } catch (_) {
      if (_isCurrent(operation)) {
        _emit(const AdminSessionState(phase: AdminSessionPhase.unavailable));
      }
    }
  }

  Future<void> beginLogin(String username, String password) async {
    if (_disposed) return;
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      _emit(
        const AdminSessionState.signedOut(
          message: 'Enter your operator username and password.',
        ),
      );
      return;
    }
    await _waitForLogout();
    if (_disposed) return;
    final operation = ++_operation;
    _emit(const AdminSessionState(phase: AdminSessionPhase.restoring));
    try {
      // This also handles the first login after logout or an expired 401. The
      // shared future prevents a background expiry reset racing this login.
      await _ensurePreAuth();
      if (!_isCurrent(operation)) return;
      final challenge = await transport.beginLogin(
        username: normalizedUsername,
        password: password,
      );
      if (!_isCurrent(operation)) return;
      _emit(
        AdminSessionState(
          phase: AdminSessionPhase.mfaRequired,
          challenge: challenge,
          message: 'Enter the verification code from your authenticator.',
        ),
      );
    } on AdminTransportException catch (error) {
      if (!_isCurrent(operation)) return;
      _handleFailure(error);
    } catch (_) {
      if (_isCurrent(operation)) {
        _emit(
          const AdminSessionState(
            phase: AdminSessionPhase.signedOut,
            message: 'Unable to start admin sign-in. Try again.',
          ),
        );
      }
    }
  }

  Future<void> completeMfa(String code) async {
    if (_disposed) return;
    final challenge = _state.challenge;
    if (challenge == null) {
      _emit(
        const AdminSessionState(
          phase: AdminSessionPhase.expired,
          message: 'Your admin sign-in challenge has expired.',
        ),
      );
      return;
    }
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      _emit(_state.copyWith(message: 'Enter your verification code.'));
      return;
    }
    final operation = ++_operation;
    _emit(_state.copyWith(message: 'Verifying…'));
    try {
      final session = await transport.completeMfa(
        challengeId: challenge.challengeId,
        code: normalizedCode,
      );
      if (!_isCurrent(operation)) return;
      _emit(
        AdminSessionState(phase: AdminSessionPhase.signedIn, session: session),
      );
    } on AdminTransportException catch (error) {
      if (!_isCurrent(operation)) return;
      _handleFailure(error);
    } catch (_) {
      if (_isCurrent(operation)) {
        _emit(
          _state.copyWith(message: 'Unable to verify the code. Try again.'),
        );
      }
    }
  }

  /// Called by authenticated feature adapters when the cookie is rejected.
  /// A 401 expires all admin work; no request is retried with a consumer token.
  Future<void> reportUnauthorized() async {
    if (_disposed) return;
    final logout = _logoutInFlight;
    if (logout != null) {
      await logout;
      return;
    }
    ++_operation;
    _invalidatePreAuth();
    _emit(
      const AdminSessionState(
        phase: AdminSessionPhase.expired,
        message: 'Your admin session has expired.',
      ),
    );
    await _rebootstrapPreAuth();
  }

  /// Called for 403 responses. Capability denial retains the cookie session so
  /// the user can navigate to work they are allowed to perform.
  void reportCapabilityDenied() {
    if (_disposed || !_state.isAuthenticated) return;
    _emit(
      _state.copyWith(
        message: 'You do not have permission for that action.',
        capabilityDenied: true,
      ),
    );
  }

  void clearMessage() {
    if (_disposed) return;
    _emit(_state.copyWith(clearMessage: true, capabilityDenied: false));
  }

  Future<void> logout() {
    if (_disposed) return Future<void>.value();
    final pending = _logoutInFlight;
    if (pending != null) return pending;

    ++_operation;
    _invalidatePreAuth();
    _emit(const AdminSessionState.signedOut());

    final logout = _performLogout();
    _logoutInFlight = logout;
    logout.then<void>(
      (_) {
        if (identical(_logoutInFlight, logout)) _logoutInFlight = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_logoutInFlight, logout)) _logoutInFlight = null;
      },
    );
    return logout;
  }

  Future<void> _performLogout() async {
    Object? failure;
    try {
      await transport.logout();
    } catch (error) {
      failure = error;
    }

    // Re-establish a fresh pre-authentication CSRF/cookie pair even when
    // revocation returned 401/503. This keeps the next login usable while the
    // UI still reports that sign-out did not complete cleanly.
    try {
      // Keep the completed bootstrap future available for a login that was
      // started while logout was waiting on the server. That login already
      // waited for this logout, so starting a second bootstrap would rotate
      // the pre-auth CSRF lifecycle unnecessarily.
      await _ensurePreAuth(retainAfterCompletion: true);
    } catch (error) {
      failure ??= error;
    }

    if (!_isCurrent(_operation)) return;
    if (failure != null) {
      _emit(
        const AdminSessionState(
          phase: AdminSessionPhase.signedOut,
          message: 'Unable to complete admin sign-out. Try again.',
        ),
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_operation;
    _listeners.clear();
  }

  Future<AdminBootstrap> _ensurePreAuth({bool retainAfterCompletion = false}) {
    final pending = _preAuthBootstrap;
    if (pending != null) {
      if (_retainCompletedPreAuth) {
        _retainCompletedPreAuth = false;
        _preAuthBootstrap = null;
      }
      return pending;
    }

    final generation = _bootstrapGeneration;
    final bootstrap = transport.bootstrap();
    _preAuthBootstrap = bootstrap;
    bootstrap.then<void>(
      (_) {
        if (generation == _bootstrapGeneration &&
            identical(_preAuthBootstrap, bootstrap)) {
          if (retainAfterCompletion) {
            _retainCompletedPreAuth = true;
          } else {
            _preAuthBootstrap = null;
          }
        }
      },
      onError: (Object _, StackTrace _) {
        if (generation == _bootstrapGeneration &&
            identical(_preAuthBootstrap, bootstrap)) {
          _retainCompletedPreAuth = false;
          _preAuthBootstrap = null;
        }
      },
    );
    return bootstrap;
  }

  Future<void> _waitForLogout() async {
    final logout = _logoutInFlight;
    if (logout != null) await logout;
  }

  void _invalidatePreAuth() {
    ++_bootstrapGeneration;
    _retainCompletedPreAuth = false;
    _preAuthBootstrap = null;
  }

  Future<void> _rebootstrapPreAuth() async {
    try {
      await _ensurePreAuth();
    } catch (_) {
      // The expired state remains visible and the next login retries bootstrap.
    }
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _handleFailure(AdminTransportException error, {bool restoring = false}) {
    if (error.isUnauthorized) {
      _invalidatePreAuth();
      _emit(
        const AdminSessionState(
          phase: AdminSessionPhase.expired,
          message: 'Your admin session has expired.',
        ),
      );
      unawaited(_rebootstrapPreAuth());
    } else if (error.isForbidden) {
      if (_state.isAuthenticated) {
        reportCapabilityDenied();
      } else {
        _emit(
          const AdminSessionState(
            phase: AdminSessionPhase.signedOut,
            message: 'This account is not enrolled for admin access.',
            capabilityDenied: true,
          ),
        );
      }
    } else if (restoring) {
      _emit(const AdminSessionState(phase: AdminSessionPhase.unavailable));
    } else {
      _emit(
        _state.copyWith(
          message: 'Unable to complete admin sign-in. Try again.',
        ),
      );
    }
  }

  void _emit(AdminSessionState state) {
    if (_disposed) return;
    _state = state;
    for (final listener in List<AdminSessionListener>.of(_listeners)) {
      listener(state);
    }
  }
}
