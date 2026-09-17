import 'dart:async';

import 'package:buff_lisa/features/admin_session/domain/admin_session_controller.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_models.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restores the cookie session through bootstrap and session GET',
    () async {
      final transport = _FakeAdminSessionTransport(restored: _session());
      final controller = AdminSessionController(transport);

      await controller.restore();

      expect(transport.calls, ['bootstrap', 'restore']);
      expect(controller.state.phase, AdminSessionPhase.signedIn);
      expect(controller.state.session?.username, 'operator');
      expect(controller.state.session?.capabilities, contains('users.read'));
    },
  );

  test('a 401 expires the admin state and clears its challenge', () async {
    final transport = _FakeAdminSessionTransport(
      restoredError: const AdminTransportException(401),
    );
    final controller = AdminSessionController(transport);

    await controller.restore();

    expect(controller.state.phase, AdminSessionPhase.expired);
    expect(controller.state.session, isNull);
    expect(controller.state.challenge, isNull);
    expect(controller.state.message, 'Your admin session has expired.');
  });

  test('a 403 records capability denial without logging out', () async {
    final controller = AdminSessionController(
      _FakeAdminSessionTransport(restored: _session()),
    );

    await controller.restore();
    controller.reportCapabilityDenied();

    expect(controller.state.phase, AdminSessionPhase.signedIn);
    expect(controller.state.session, isNotNull);
    expect(controller.state.capabilityDenied, isTrue);
    expect(
      controller.state.message,
      'You do not have permission for that action.',
    );
  });

  test('logout invalidates a late login response', () async {
    final challenge = Completer<AdminLoginChallenge>();
    final transport = _FakeAdminSessionTransport(loginFuture: challenge.future);
    final controller = AdminSessionController(transport);

    final login = controller.beginLogin('operator', 'never-retained');
    await Future<void>.delayed(Duration.zero);
    await controller.logout();
    challenge.complete(_challenge());
    await login;

    expect(controller.state.phase, AdminSessionPhase.signedOut);
    expect(controller.state.challenge, isNull);
  });

  test(
    'passwords, MFA codes, and CSRF values never appear in state text',
    () async {
      final transport = _FakeAdminSessionTransport(
        loginFuture: Future.value(_challenge()),
      );
      final controller = AdminSessionController(transport);

      await controller.beginLogin('operator', 'super-secret-password');
      final stateText = '${controller.state}';

      expect(stateText, isNot(contains('super-secret-password')));
      expect(stateText, isNot(contains('csrf-secret')));
      expect(stateText, isNot(contains('654321')));
    },
  );
}

AdminSessionSnapshot _session() => AdminSessionSnapshot(
  sessionId: 'session-1',
  userId: 'user-1',
  username: 'operator',
  csrfToken: 'csrf-secret',
  capabilities: const {'users.read'},
  permissions: const {'users.read'},
  authenticatedAt: DateTime.utc(2026, 1, 1),
  lastActivityAt: DateTime.utc(2026, 1, 1),
  idleExpiresAt: DateTime.utc(2026, 1, 1, 1),
  recentMfaAt: DateTime.utc(2026, 1, 1),
);

AdminLoginChallenge _challenge() => AdminLoginChallenge(
  challengeId: 'challenge-1',
  expiresAt: DateTime.utc(2026, 1, 1, 1),
);

final class _FakeAdminSessionTransport implements AdminSessionTransport {
  _FakeAdminSessionTransport({
    this.restored,
    this.restoredError,
    Future<AdminLoginChallenge>? loginFuture,
  }) : _loginFuture = loginFuture;

  final List<String> calls = [];
  final AdminSessionSnapshot? restored;
  final Object? restoredError;
  final Future<AdminLoginChallenge>? _loginFuture;

  @override
  Future<AdminBootstrap> bootstrap() async {
    calls.add('bootstrap');
    return AdminBootstrap(
      csrfToken: 'csrf-secret',
      expiresAt: DateTime.utc(2026, 1, 1, 1),
    );
  }

  @override
  Future<AdminLoginChallenge> beginLogin({
    required String username,
    required String password,
  }) {
    calls.add('login');
    return _loginFuture ?? Future.value(_challenge());
  }

  @override
  Future<AdminSessionSnapshot> completeMfa({
    required String challengeId,
    required String code,
  }) async {
    calls.add('mfa');
    return _session();
  }

  @override
  Future<AdminSessionSnapshot?> restore() async {
    calls.add('restore');
    if (restoredError != null) throw restoredError!;
    return restored;
  }

  @override
  Future<void> logout() async => calls.add('logout');
}
