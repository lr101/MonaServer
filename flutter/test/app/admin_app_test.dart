import 'package:buff_lisa/app/admin/admin_app.dart';
import 'package:buff_lisa/app/admin/admin_bootstrap.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_models.dart';
import 'package:buff_lisa/features/admin_session/domain/admin_session_ports.dart';
import 'package:buff_lisa/features/admin_session/presentation/admin_session_controller.dart';
import 'package:buff_lisa/features/admin_audit/domain/admin_audit_models.dart';
import 'package:buff_lisa/features/admin_audit/domain/admin_audit_ports.dart';
import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_ports.dart';
import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';
import 'package:buff_lisa/features/admin_jobs/domain/admin_job_ports.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_ports.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_ports.dart';
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
      final features = _FakeAdminFeatureRepositories();
      await tester.pumpWidget(
        AdminApp(
          sessionController: controller,
          usersRepository: _FakeAdminUsersRepository(),
          reportsRepository: features,
          campaignRepository: features,
          jobsRepository: features,
          securityRepository: features,
          auditRepository: features,
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
    final features = _FakeAdminFeatureRepositories();
    await tester.pumpWidget(
      AdminApp(
        sessionController: controller,
        usersRepository: _FakeAdminUsersRepository(),
        reportsRepository: features,
        campaignRepository: features,
        jobsRepository: features,
        securityRepository: features,
        auditRepository: features,
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

  testWidgets('signed-in shell routes to integrated admin feature screens', (
    tester,
  ) async {
    final controller = AdminSessionController(
      _FakeAdminSessionTransport(restored: _session()),
    );
    final features = _FakeAdminFeatureRepositories();
    await tester.pumpWidget(
      AdminApp(
        sessionController: controller,
        usersRepository: _FakeAdminUsersRepository(),
        reportsRepository: features,
        campaignRepository: features,
        jobsRepository: features,
        securityRepository: features,
        auditRepository: features,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('admin-nav-reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-reports-screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-nav-campaigns')));
    await tester.pumpAndSettle();
    expect(find.text('Campaign composer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-nav-security')));
    await tester.pumpAndSettle();
    expect(find.text('Security actions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-nav-jobs')));
    await tester.pumpAndSettle();
    expect(find.text('Job monitoring'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-nav-audit')));
    await tester.pumpAndSettle();
    expect(find.text('Audit history'), findsOneWidget);
  });

  testWidgets('admin composition mounts without consumer initialization work', (
    tester,
  ) async {
    final sessionTransport = _FakeAdminSessionTransport();
    final usersRepository = _FakeAdminUsersRepository();
    final features = _FakeAdminFeatureRepositories();

    await tester.pumpWidget(
      createAdminApplication(
        sessionTransport: sessionTransport,
        usersRepository: usersRepository,
        reportsRepository: features,
        campaignRepository: features,
        jobsRepository: features,
        securityRepository: features,
        auditRepository: features,
        autoRestore: false,
      ),
    );

    expect(find.text('Admin sign in'), findsOneWidget);
    expect(sessionTransport.calls, isEmpty);
    expect(usersRepository.calls, isEmpty);
  });
}

AdminSessionSnapshot _session() => AdminSessionSnapshot(
  sessionId: 'session-1',
  userId: 'user-1',
  username: 'operator',
  csrfToken: 'csrf-secret',
  capabilities: const {
    'users.read',
    'reports.read',
    'reports.review',
    'reports.resolve',
    'reports.dismiss',
    'campaigns.write',
    'security.write',
    'jobs.read',
    'audit.read',
  },
  permissions: const {'users.read'},
  authenticatedAt: DateTime.utc(2026, 1, 1),
  lastActivityAt: DateTime.utc(2026, 1, 1),
  idleExpiresAt: DateTime.utc(2026, 1, 1, 1),
);

final class _FakeAdminSessionTransport implements AdminSessionTransport {
  _FakeAdminSessionTransport({this.restored});

  final AdminSessionSnapshot? restored;
  final calls = <String>[];

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
  Future<AdminSessionSnapshot?> restore() async {
    calls.add('restore');
    return restored;
  }

  @override
  Future<void> logout() async {}
}

final class _FakeAdminUsersRepository implements AdminUsersRepository {
  final calls = <String>[];

  @override
  Future<AdminUserDetails?> getUser(String userId) async {
    calls.add('details');
    return null;
  }

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    calls.add('users');
    return AdminUserPage(items: const []);
  }
}

final class _FakeAdminFeatureRepositories
    implements
        AdminReportsRepository,
        AdminCampaignRepository,
        AdminJobsRepository,
        AdminSecurityRepository,
        AdminAuditRepository {
  @override
  Future<AdminReportPage> listReports(AdminReportQuery query) async =>
      AdminReportPage(items: const []);

  @override
  Future<AdminReport?> get(String reportId) async => null;

  @override
  Future<AdminReport> update(AdminReportUpdate update) =>
      throw UnimplementedError();

  @override
  Future<AdminReportNote> addNote(String reportId, String text) =>
      throw UnimplementedError();

  @override
  Future<AdminReportBulkOutcome> commitBulk(AdminReportBulkCommand command) =>
      throw UnimplementedError();

  @override
  Future<AdminAudiencePreview> preview(AdminAudiencePreviewRequest request) =>
      throw UnimplementedError();

  @override
  Future<AdminCampaignCommitResult> commit(
    AdminCampaignCommitCommand command,
  ) => throw UnimplementedError();

  @override
  Future<AdminCampaignTestResult> sendTest({
    required String recipientUserId,
    required AdminAudienceAction action,
  }) => throw UnimplementedError();

  @override
  Future<AdminJobPage> listJobs(AdminJobQuery query) async =>
      const AdminJobPage(items: []);

  @override
  Future<AdminJobCommandResult> retry(AdminJobCommand command) =>
      throw UnimplementedError();

  @override
  Future<AdminJobCommandResult> cancel(AdminJobCommand command) =>
      throw UnimplementedError();

  @override
  Future<AdminSecurityResult> submit(AdminSecurityActionRequest request) =>
      throw UnimplementedError();

  @override
  Future<AdminAuditPage> listAudit(AdminAuditQuery query) async =>
      const AdminAuditPage(items: []);
}
