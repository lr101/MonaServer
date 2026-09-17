import 'dart:async';

import 'package:flutter/material.dart';

import '../../admin_audience/domain/admin_audience_models.dart';
import '../../admin_audience/presentation/admin_audience_confirmation.dart';
import '../domain/admin_user_models.dart';
import '../domain/admin_users_controller.dart';

final class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    required this.controller,
    required this.canRead,
    super.key,
  });

  final AdminUsersController controller;
  final bool canRead;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

final class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  final _selection = AdminAudienceSelectionModel();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    if (widget.canRead) unawaited(widget.controller.searchUsers(''));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChanged(AdminUsersState _) {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    _selection.clear();
    await widget.controller.searchUsers(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canRead) return const _CapabilityDeniedView();
    final state = widget.controller.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final list = _UsersList(
          state: state,
          searchController: _searchController,
          selection: _selection,
          onSearch: _search,
          onToggleSelected: (id) {
            _selection.toggleSelected(id);
            setState(() {});
          },
          onOpenDetails: widget.controller.loadDetails,
          onLoadMore: widget.controller.loadNextPage,
        );
        final confirmation = AdminAudienceConfirmation(
          selection: _selection.audience,
          onPreview: () {},
        );
        final tools = _AudienceTools(
          selection: _selection,
          onChanged: () => setState(() {}),
        );
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [list, tools, confirmation],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              list,
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tools),
                  const SizedBox(width: 20),
                  SizedBox(width: 340, child: confirmation),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.state,
    required this.searchController,
    required this.selection,
    required this.onSearch,
    required this.onToggleSelected,
    required this.onOpenDetails,
    required this.onLoadMore,
  });

  final AdminUsersState state;
  final TextEditingController searchController;
  final AdminAudienceSelectionModel selection;
  final Future<void> Function() onSearch;
  final ValueChanged<String> onToggleSelected;
  final Future<void> Function(String) onOpenDetails;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('admin-users-list'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Users', style: theme.textTheme.headlineSmall),
                ),
                if (selection.selectedIds.isNotEmpty)
                  Chip(label: Text('${selection.selectedIds.length} selected')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Search username, email, or stable account ID. Account records contain no credentials.',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('admin-user-search'),
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    decoration: const InputDecoration(
                      labelText: 'Search users',
                      hintText: 'name, email, or ID',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const ValueKey('admin-user-search-submit'),
                  onPressed: state.loading ? null : onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (state.loading && state.users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No users match this search.'),
              )
            else
              ...state.users.map(
                (user) => _UserRow(
                  user: user,
                  selected: selection.selectedIds.contains(user.id),
                  onToggleSelected: () => onToggleSelected(user.id),
                  onOpenDetails: () => onOpenDetails(user.id),
                ),
              ),
            if (state.nextCursor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey('admin-users-load-more'),
                  onPressed: state.loading ? null : onLoadMore,
                  child: Text(state.loading ? 'Loading…' : 'Load more users'),
                ),
              ),
            const SizedBox(height: 16),
            _UserDetailPanel(state: state),
          ],
        ),
      ),
    );
  }
}

final class _UserDetailPanel extends StatelessWidget {
  const _UserDetailPanel({required this.state});

  final AdminUsersState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingDetail) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final user = state.selectedDetail;
    if (user == null) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('admin-user-detail'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User detail', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(user.username, style: Theme.of(context).textTheme.titleLarge),
            Text(user.email ?? 'No email address'),
            const SizedBox(height: 12),
            Text('Stable ID: ${user.id}'),
            Text('Auth generation: ${user.authGeneration}'),
            Text('Registered devices: ${user.registeredDeviceCount}'),
            Text(
              user.communicationOptOut
                  ? 'General communication: opted out'
                  : 'General communication: eligible',
            ),
            if (user.eligibilityReasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Eligibility: ${user.eligibilityReasons.join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }
}

final class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.selected,
    required this.onToggleSelected,
    required this.onOpenDetails,
  });

  final AdminUserRecord user;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'User ${user.username}',
      child: ListTile(
        key: ValueKey('admin-user-${user.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: selected,
          onChanged: (_) => onToggleSelected(),
          semanticLabel: 'Select ${user.username}',
        ),
        title: Text(user.username),
        subtitle: Text(user.email ?? 'No email address'),
        trailing: Chip(label: Text(_securityLabel(user.securityStatus))),
        onTap: onOpenDetails,
      ),
    );
  }

  String _securityLabel(AdminSecurityStatus status) {
    switch (status) {
      case AdminSecurityStatus.normal:
        return 'Normal';
      case AdminSecurityStatus.passwordDisabled:
        return 'Password disabled';
      case AdminSecurityStatus.compromised:
        return 'Compromised';
      case AdminSecurityStatus.securedManualRecoveryRequired:
        return 'Manual recovery';
      case AdminSecurityStatus.deleted:
        return 'Deleted';
    }
  }
}

final class _AudienceTools extends StatelessWidget {
  const _AudienceTools({required this.selection, required this.onChanged});

  final AdminAudienceSelectionModel selection;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Audience scope',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose explicit accounts, every account matching the current filter, or all eligible accounts before a bulk action.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('admin-audience-all'),
                  onPressed: () {
                    selection.selectAllMatching();
                    onChanged();
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('All eligible'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('admin-audience-filter'),
                  onPressed: () {
                    selection.setFilter(const AdminAudienceFilter());
                    onChanged();
                  },
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('All matching filter'),
                ),
                TextButton(
                  onPressed: () {
                    selection.clear();
                    onChanged();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Current scope: ${selection.audience.summary}'),
          ],
        ),
      ),
    );
  }
}

final class _CapabilityDeniedView extends StatelessWidget {
  const _CapabilityDeniedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Your admin session does not have permission to view users.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
