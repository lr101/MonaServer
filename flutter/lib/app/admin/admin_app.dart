import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/admin_session/domain/admin_session_models.dart';
import '../../features/admin_session/presentation/admin_session_controller.dart';
import '../../features/admin_session/presentation/admin_login_screen.dart';
import '../../features/admin_session/presentation/admin_mfa_screen.dart';
import '../../features/admin_audit/domain/admin_audit_ports.dart';
import '../../features/admin_campaigns/domain/admin_campaign_ports.dart';
import '../../features/admin_jobs/domain/admin_job_ports.dart';
import '../../features/admin_reports/domain/admin_report_ports.dart';
import '../../features/admin_security/domain/admin_security_ports.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import 'admin_shell.dart';

/// Independent admin application composition root. It does not create the
/// consumer bootstrap, Drift database, sync lifecycle, camera, or Firebase.
final class AdminApp extends StatefulWidget {
  const AdminApp({
    required this.sessionController,
    required this.usersRepository,
    required this.reportsRepository,
    required this.campaignRepository,
    required this.jobsRepository,
    required this.securityRepository,
    required this.auditRepository,
    this.autoRestore = true,
    this.onDispose,
    super.key,
  });

  final AdminSessionController sessionController;
  final AdminUsersRepository usersRepository;
  final AdminReportsRepository reportsRepository;
  final AdminCampaignRepository campaignRepository;
  final AdminJobsRepository jobsRepository;
  final AdminSecurityRepository securityRepository;
  final AdminAuditRepository auditRepository;
  final bool autoRestore;
  final VoidCallback? onDispose;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

final class _AdminAppState extends State<AdminApp> {
  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionChanged);
    if (widget.autoRestore) unawaited(widget.sessionController.restore());
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionChanged);
    widget.sessionController.dispose();
    widget.onDispose?.call();
    super.dispose();
  }

  void _onSessionChanged(AdminSessionState _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin workspace',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff005cbb)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          alignLabelWithHint: true,
        ),
      ),
      home: _AdminGate(
        controller: widget.sessionController,
        usersRepository: widget.usersRepository,
        reportsRepository: widget.reportsRepository,
        campaignRepository: widget.campaignRepository,
        jobsRepository: widget.jobsRepository,
        securityRepository: widget.securityRepository,
        auditRepository: widget.auditRepository,
      ),
    );
  }
}

final class _AdminGate extends StatelessWidget {
  const _AdminGate({
    required this.controller,
    required this.usersRepository,
    required this.reportsRepository,
    required this.campaignRepository,
    required this.jobsRepository,
    required this.securityRepository,
    required this.auditRepository,
  });

  final AdminSessionController controller;
  final AdminUsersRepository usersRepository;
  final AdminReportsRepository reportsRepository;
  final AdminCampaignRepository campaignRepository;
  final AdminJobsRepository jobsRepository;
  final AdminSecurityRepository securityRepository;
  final AdminAuditRepository auditRepository;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    switch (state.phase) {
      case AdminSessionPhase.restoring:
        return const _AdminRestoringScreen();
      case AdminSessionPhase.mfaRequired:
        return AdminMfaScreen(controller: controller);
      case AdminSessionPhase.signedIn:
        return AdminShell(
          session: state.session!,
          sessionController: controller,
          usersRepository: usersRepository,
          reportsRepository: reportsRepository,
          campaignRepository: campaignRepository,
          jobsRepository: jobsRepository,
          securityRepository: securityRepository,
          auditRepository: auditRepository,
        );
      case AdminSessionPhase.signedOut:
      case AdminSessionPhase.expired:
      case AdminSessionPhase.unavailable:
        return AdminLoginScreen(controller: controller);
    }
  }
}

final class _AdminRestoringScreen extends StatelessWidget {
  const _AdminRestoringScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                semanticsLabel: 'Restoring admin session',
              ),
              SizedBox(height: 16),
              Text('Restoring admin session…'),
            ],
          ),
        ),
      ),
    );
  }
}
