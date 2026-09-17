import 'package:flutter/material.dart';

import '../../features/admin_session/domain/admin_session_controller.dart';
import '../../features/admin_session/domain/admin_session_models.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import '../../features/admin_users/domain/admin_users_controller.dart';
import '../../features/admin_users/presentation/admin_users_screen.dart';

enum AdminRoute { overview, users, reports, jobs }

final class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.session,
    required this.sessionController,
    required this.usersRepository,
    super.key,
  });

  final AdminSessionSnapshot session;
  final AdminSessionController sessionController;
  final AdminUsersRepository usersRepository;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

final class _AdminShellState extends State<AdminShell> {
  late final AdminUsersController _usersController;
  AdminRoute _route = AdminRoute.overview;

  @override
  void initState() {
    super.initState();
    _usersController = AdminUsersController(
      widget.usersRepository,
      onUnauthorized: widget.sessionController.reportUnauthorized,
      onCapabilityDenied: widget.sessionController.reportCapabilityDenied,
    );
  }

  @override
  void dispose() {
    _usersController.dispose();
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
        );
      case AdminRoute.reports:
        return const _PlaceholderPage(
          title: 'Reports',
          message: 'Report review is ready for the next integration slice.',
          icon: Icons.flag_outlined,
        );
      case AdminRoute.jobs:
        return const _PlaceholderPage(
          title: 'Jobs',
          message: 'Job monitoring is ready for the next integration slice.',
          icon: Icons.work_history_outlined,
        );
    }
  }
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
      key: ValueKey('admin-nav-jobs'),
      child: Icon(Icons.work_history_outlined),
    ),
    selectedIcon: Icon(Icons.work_history),
    label: Text('Jobs'),
  ),
];

const _destinationLabels = ['Overview', 'Users', 'Reports', 'Jobs'];
const _destinationIcons = [
  Icon(Icons.dashboard_outlined),
  Icon(Icons.people_outline),
  Icon(Icons.flag_outlined),
  Icon(Icons.work_history_outlined),
];
const _destinationKeys = [
  ValueKey('admin-nav-overview'),
  ValueKey('admin-nav-users'),
  ValueKey('admin-nav-reports'),
  ValueKey('admin-nav-jobs'),
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

final class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

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
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
