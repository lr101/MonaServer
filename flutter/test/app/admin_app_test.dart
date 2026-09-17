import 'package:buff_lisa/app/admin/admin_app.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_controller.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_models.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_ports.dart';
import 'package:buff_lisa/features/admin_users/domain/admin_user_models.dart';
import 'package:buff_lisa/features/admin_users/domain/admin_user_ports.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'signed-out admin entry point presents password then MFA screens',
    (tester) async {
      final transport = _FakeAdminSessionTransport();
      final controller = AdminSessionController(transport);
      await tester.pumpWidget(
        AdminApp(
          sessionController: controller,
          usersRepository: _FakeAdminUsersRepository(),
          autoRestore: false,
        ),
      );

      expect(find.text('Admin sign in'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('admin-username')),
        'operator',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-password')),
        'temporary-password',
      );
      await tester.tap(find.byKey(const ValueKey('admin-sign-in')));
      await tester.pumpAndSettle();

      expect(find.text('Multi-factor verification'), findsOneWidget);
      expect(find.textContaining('temporary-password'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('admin-mfa-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('admin-verify-mfa')));
      await tester.pumpAndSettle();

      expect(find.text('Admin workspace'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-navigation-rail')),
        findsOneWidget,
      );
    },
  );

  testWidgets('wide and narrow layouts keep keyboard-accessible navigation', (
    tester,
  ) async {
    final controller = AdminSessionController(
      _FakeAdminSessionTransport(restored: _session()),
    );
    await tester.pumpWidget(
      AdminApp(
        sessionController: controller,
        usersRepository: _FakeAdminUsersRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-navigation-rail')), findsOneWidget);
    expect(find.byTooltip('Open admin navigation'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(500, 900));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open admin navigation'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-navigation-rail')), findsNothing);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('signed-in shell exposes users, reports, and jobs destinations', (
    tester,
  ) async {
    final controller = AdminSessionController(
      _FakeAdminSessionTransport(restored: _session()),
    );
    await tester.pumpWidget(
      AdminApp(
        sessionController: controller,
        usersRepository: _FakeAdminUsersRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('admin-nav-reports')));
    await tester.pumpAndSettle();
    expect(find.text('Reports'), findsWidgets);
    expect(
      find.text('Report review is ready for the next integration slice.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('admin-nav-jobs')));
    await tester.pumpAndSettle();
    expect(find.text('Jobs'), findsWidgets);
    expect(
      find.text('Job monitoring is ready for the next integration slice.'),
      findsOneWidget,
    );
  });
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
);

final class _FakeAdminSessionTransport implements AdminSessionTransport {
  _FakeAdminSessionTransport({this.restored});

  final AdminSessionSnapshot? restored;

  @override
  Future<AdminBootstrap> bootstrap() async => AdminBootstrap(
    csrfToken: 'csrf-secret',
    expiresAt: DateTime.utc(2026, 1, 1, 1),
  );

  @override
  Future<AdminLoginChallenge> beginLogin({
    required String username,
    required String password,
  }) async => AdminLoginChallenge(
    challengeId: 'challenge-1',
    expiresAt: DateTime.utc(2026, 1, 1, 1),
  );

  @override
  Future<AdminSessionSnapshot> completeMfa({
    required String challengeId,
    required String code,
  }) async => _session();

  @override
  Future<AdminSessionSnapshot?> restore() async => restored;

  @override
  Future<void> logout() async {}
}

final class _FakeAdminUsersRepository implements AdminUsersRepository {
  @override
  Future<AdminUserDetails?> getUser(String userId) async => null;

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async =>
      AdminUserPage(items: const []);
}
