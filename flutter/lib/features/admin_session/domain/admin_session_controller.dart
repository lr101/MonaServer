import 'admin_session_models.dart';
import 'admin_session_ports.dart';

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
  int _operation = 0;
  bool _disposed = false;

  AdminSessionState get state => _state;

  void addListener(AdminSessionListener listener) => _listeners.add(listener);

  void removeListener(AdminSessionListener listener) =>
      _listeners.remove(listener);

  Future<void> restore() async {
    if (_disposed) return;
    final operation = ++_operation;
    _emit(const AdminSessionState.restoring());
    try {
      // Bootstrap establishes the pre-authentication CSRF cookie/header pair.
      await transport.bootstrap();
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
    final operation = ++_operation;
    _emit(const AdminSessionState(phase: AdminSessionPhase.restoring));
    try {
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
  void reportUnauthorized() {
    if (_disposed) return;
    ++_operation;
    _emit(
      const AdminSessionState(
        phase: AdminSessionPhase.expired,
        message: 'Your admin session has expired.',
      ),
    );
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

  Future<void> logout() async {
    if (_disposed) return;
    ++_operation;
    _emit(const AdminSessionState.signedOut());
    try {
      await transport.logout();
    } catch (_) {
      // Local state is already signed out. The adapter owns cookie revocation;
      // no transport detail belongs in the next login screen.
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_operation;
    _listeners.clear();
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _handleFailure(AdminTransportException error, {bool restoring = false}) {
    if (error.isUnauthorized) {
      _emit(
        const AdminSessionState(
          phase: AdminSessionPhase.expired,
          message: 'Your admin session has expired.',
        ),
      );
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
