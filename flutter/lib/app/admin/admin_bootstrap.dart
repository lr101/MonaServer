import 'package:flutter/widgets.dart';

import '../../features/admin_users/domain/admin_user_ports.dart';
import '../../features/admin_audit/domain/admin_audit_ports.dart';
import '../../features/admin_campaigns/domain/admin_campaign_ports.dart';
import '../../features/admin_jobs/domain/admin_job_ports.dart';
import '../../features/admin_reports/domain/admin_report_ports.dart';
import '../../features/admin_security/domain/admin_security_ports.dart';
import '../../features/admin_session/domain/admin_session_ports.dart';
import '../../features/admin_session/presentation/admin_session_controller.dart';
import 'admin_api_adapter.dart';
import 'admin_app.dart';

/// Builds only the admin composition root. The API adapter is disposed with
/// the app, and no consumer startup work is reachable from this function.
Widget createAdminApplication({
  String? apiHost,
  AdminSessionTransport? sessionTransport,
  AdminUsersRepository? usersRepository,
  AdminReportsRepository? reportsRepository,
  AdminCampaignRepository? campaignRepository,
  AdminJobsRepository? jobsRepository,
  AdminSecurityRepository? securityRepository,
  AdminAuditRepository? auditRepository,
  bool autoRestore = true,
  VoidCallback? onDispose,
}) {
  final supplied = [
    sessionTransport,
    usersRepository,
    reportsRepository,
    campaignRepository,
    jobsRepository,
    securityRepository,
    auditRepository,
  ];
  if (supplied.any((dependency) => dependency == null) &&
      supplied.any((dependency) => dependency != null)) {
    throw ArgumentError(
      'All admin feature dependencies must be supplied together.',
    );
  }
  final suppliedSessionTransport = sessionTransport;
  final suppliedUsersRepository = usersRepository;
  final suppliedReportsRepository = reportsRepository;
  final suppliedCampaignRepository = campaignRepository;
  final suppliedJobsRepository = jobsRepository;
  final suppliedSecurityRepository = securityRepository;
  final suppliedAuditRepository = auditRepository;
  AdminApiAdapter? adapter;
  if (suppliedSessionTransport == null) {
    adapter = AdminApiAdapter(
      basePath:
          apiHost ??
          const String.fromEnvironment(
            'API_HOST',
            defaultValue: 'https://stick-it.lr-projects.de',
          ),
    );
  }
  final resolvedSessionTransport = suppliedSessionTransport ?? adapter!;
  final resolvedUsersRepository = suppliedUsersRepository ?? adapter!;
  return AdminApp(
    sessionController: AdminSessionController(resolvedSessionTransport),
    usersRepository: resolvedUsersRepository,
    reportsRepository: suppliedReportsRepository ?? adapter!,
    campaignRepository: suppliedCampaignRepository ?? adapter!,
    jobsRepository: suppliedJobsRepository ?? adapter!,
    securityRepository: suppliedSecurityRepository ?? adapter!,
    auditRepository: suppliedAuditRepository ?? adapter!,
    autoRestore: autoRestore,
    onDispose: onDispose ?? adapter?.close,
  );
}
