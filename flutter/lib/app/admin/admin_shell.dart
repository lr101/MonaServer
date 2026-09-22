import '../../features/admin_audience/domain/admin_audience_models.dart';
import '../../features/admin_audit/domain/admin_audit_ports.dart';
import '../../features/admin_audit/presentation/admin_audit_controller.dart';
import '../../features/admin_audit/presentation/admin_audit_screen.dart';
import '../../features/admin_campaigns/domain/admin_campaign_ports.dart';
import '../../features/admin_campaigns/presentation/admin_campaign_controller.dart';
import '../../features/admin_campaigns/presentation/admin_campaign_screen.dart';
import '../../features/admin_jobs/domain/admin_job_ports.dart';
import '../../features/admin_jobs/presentation/admin_jobs_controller.dart';
import '../../features/admin_jobs/presentation/admin_jobs_screen.dart';
import '../../features/admin_reports/domain/admin_report_ports.dart';
import '../../features/admin_reports/presentation/admin_reports_controller.dart';
import '../../features/admin_reports/presentation/admin_reports_screen.dart';
import '../../features/admin_security/domain/admin_security_ports.dart';
import '../../features/admin_security/presentation/admin_security_controller.dart';
import '../../features/admin_security/presentation/admin_security_screen.dart';

import 'package:flutter/material.dart';

import '../../features/admin_session/domain/admin_session_models.dart';
import '../../features/admin_session/presentation/admin_session_controller.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import '../../features/admin_users/presentation/admin_users_controller.dart';
import '../../features/admin_users/presentation/admin_users_screen.dart';

enum AdminRoute { overview, users, reports, campaigns, security, jobs, audit }

final class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.session,
    required this.sessionController,
    required this.usersRepository,
    required this.reportsRepository,
    required this.campaignRepository,
    required this.jobsRepository,
    required this.securityRepository,
    required this.auditRepository,
    super.key,
  });

  final AdminSessionSnapshot session;
  final AdminSessionController sessionController;
  final AdminUsersRepository usersRepository;
  final AdminReportsRepository reportsRepository;
  final AdminCampaignRepository campaignRepository;
  final AdminJobsRepository jobsRepository;
  final AdminSecurityRepository securityRepository;
  final AdminAuditRepository auditRepository;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

final class _AdminShellState extends State<AdminShell> {
  late final AdminUsersController _usersController;
  late final AdminReportsController _reportsController;
  late final AdminCampaignController _campaignController;
  late final AdminJobsController _jobsController;
  late final AdminSecurityController _securityController;
  late final AdminAuditController _auditController;
  final _audienceSelection = AdminAudienceSelectionModel();
  AdminRoute _route = AdminRoute.overview;

  @override
  void initState() {
    super.initState();
    _usersController = AdminUsersController(
      widget.usersRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
    _reportsController = AdminReportsController(
      widget.reportsRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
    _campaignController = AdminCampaignController(
      widget.campaignRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
    _jobsController = AdminJobsController(
      widget.jobsRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
    _securityController = AdminSecurityController(
      widget.securityRepository,
      hasRecentMfa: () => widget.session.recentMfaAt != null,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
    _auditController = AdminAuditController(
      widget.auditRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
  }

  @override
  void dispose() {
    _usersController.dispose();
    _reportsController.dispose();
    _campaignController.dispose();
    _jobsController.dispose();
    _securityController.dispose();
    _auditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.sessionController.state;
    final capabilityMessage = state.capabilityDenied ? state.message : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin workspace'),
            actions: [
              if (capabilityMessage == null) Text(widget.session.username),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sign out of admin workspace',
                onPressed: widget.sessionController.logout,
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide
              ? null
              : _AdminDrawer(
                  route: _route,
                  onSelect: (route) {
                    Navigator.of(context).pop();
                    _selectRoute(route);
                  },
                ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                _AdminNavigationRail(route: _route, onSelect: _selectRoute),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (capabilityMessage != null)
                      MaterialBanner(
                        content: Text(capabilityMessage),
                        leading: const Icon(Icons.info_outline),
                        actions: [
                          TextButton(
                            onPressed: widget.sessionController.clearMessage,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    Expanded(child: _pageForRoute()),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: wide
              ? null
              : Builder(
                  builder: (context) => FloatingActionButton(
                    tooltip: 'Open admin navigation',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    child: const Icon(Icons.menu),
                  ),
                ),
        );
      },
    );
  }

  void _selectRoute(AdminRoute route) {
    if (mounted) setState(() => _route = route);
  }

  Widget _pageForRoute() {
    switch (_route) {
      case AdminRoute.overview:
        return const _OverviewPage();
      case AdminRoute.users:
        return AdminUsersScreen(
          controller: _usersController,
          canRead:
              widget.session.can('users.read') ||
              widget.session.can('admin.users.read'),
          selection: _audienceSelection,
          onAudienceChanged: () => setState(() {}),
        );
      case AdminRoute.reports:
        return AdminReportsScreen(
          controller: _reportsController,
          canRead: _can('reports.read'),
          canReview: _can('reports.review'),
          canResolve: _can('reports.resolve'),
          canDismiss: _can('reports.dismiss'),
        );
      case AdminRoute.campaigns:
        return _can('campaigns.write')
            ? AdminCampaignScreen(
                controller: _campaignController,
                audience: _audienceSelection.audience,
                testRecipientUserId: widget.session.userId,
              )
            : const _CapabilityPage(title: 'Campaigns');
      case AdminRoute.security:
        return _can('security.write')
            ? AdminSecurityScreen(
                controller: _securityController,
                audience: _audienceSelection.audience,
              )
            : const _CapabilityPage(title: 'Security actions');
      case AdminRoute.jobs:
        return _can('jobs.read')
            ? AdminJobsScreen(controller: _jobsController)
            : const _CapabilityPage(title: 'Job monitoring');
      case AdminRoute.audit:
        return _can('audit.read')
            ? AdminAuditScreen(controller: _auditController)
            : const _CapabilityPage(title: 'Audit history');
    }
  }

  bool _can(String capability) =>
      widget.session.can(capability) || widget.session.can('admin.$capability');
}

final class _AdminNavigationRail extends StatelessWidget {
  const _AdminNavigationRail({required this.route, required this.onSelect});

  final AdminRoute route;
  final ValueChanged<AdminRoute> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      key: const ValueKey('admin-navigation-rail'),
      selectedIndex: route.index,
      onDestinationSelected: (index) => onSelect(AdminRoute.values[index]),
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Icon(Icons.admin_panel_settings_outlined),
      ),
      destinations: _destinations,
    );
  }
}

final class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.route, required this.onSelect});

  final AdminRoute route;
  final ValueChanged<AdminRoute> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Admin workspace'),
            ),
            ..._destinationLabels.asMap().entries.map(
              (entry) => ListTile(
                selected: route.index == entry.key,
                leading: KeyedSubtree(
                  key: _destinationKeys[entry.key],
                  child: _destinationIcons[entry.key],
                ),
                title: Text(entry.value),
                onTap: () => onSelect(AdminRoute.values[entry.key]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _destinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-overview'),
      child: Icon(Icons.dashboard_outlined),
    ),
    selectedIcon: Icon(Icons.dashboard),
    label: Text('Overview'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-users'),
      child: Icon(Icons.people_outline),
    ),
    selectedIcon: Icon(Icons.people),
    label: Text('Users'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-reports'),
      child: Icon(Icons.flag_outlined),
    ),
    selectedIcon: Icon(Icons.flag),
    label: Text('Reports'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-campaigns'),
      child: Icon(Icons.campaign_outlined),
    ),
    selectedIcon: Icon(Icons.campaign),
    label: Text('Campaigns'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-security'),
      child: Icon(Icons.security_outlined),
    ),
    selectedIcon: Icon(Icons.security),
    label: Text('Security'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-jobs'),
      child: Icon(Icons.work_history_outlined),
    ),
    selectedIcon: Icon(Icons.work_history),
    label: Text('Jobs'),
  ),
  NavigationRailDestination(
    icon: KeyedSubtree(
      key: ValueKey('admin-nav-audit'),
      child: Icon(Icons.history_outlined),
    ),
    selectedIcon: Icon(Icons.history),
    label: Text('Audit'),
  ),
];

const _destinationLabels = [
  'Overview',
  'Users',
  'Reports',
  'Campaigns',
  'Security',
  'Jobs',
  'Audit',
];
const _destinationIcons = [
  Icon(Icons.dashboard_outlined),
  Icon(Icons.people_outline),
  Icon(Icons.flag_outlined),
  Icon(Icons.campaign_outlined),
  Icon(Icons.security_outlined),
  Icon(Icons.work_history_outlined),
  Icon(Icons.history_outlined),
];
const _destinationKeys = [
  ValueKey('admin-nav-overview'),
  ValueKey('admin-nav-users'),
  ValueKey('admin-nav-reports'),
  ValueKey('admin-nav-campaigns'),
  ValueKey('admin-nav-security'),
  ValueKey('admin-nav-jobs'),
  ValueKey('admin-nav-audit'),
];

final class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Welcome to the admin workspace',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'This independent shell is ready for reports, audience actions, and durable job monitoring.',
        ),
        const SizedBox(height: 24),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Protected admin session'),
            subtitle: Text(
              'Cookie and MFA state stay in memory for this browser session.',
            ),
          ),
        ),
      ],
    );
  }
}

final class _CapabilityPage extends StatelessWidget {
  const _CapabilityPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Your admin session does not have the required capability.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
