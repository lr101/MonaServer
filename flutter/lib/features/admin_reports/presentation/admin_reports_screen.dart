import 'dart:async';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_audience/presentation/admin_audience_confirmation.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';
import 'package:buff_lisa/features/admin_reports/presentation/admin_reports_controller.dart';
import 'package:flutter/material.dart';

/// Constructor-only seam for T10/T13 composition. This feature does not own
/// routing or generated-client wiring.
final class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({
    required this.controller,
    required this.canRead,
    this.onOpenRelatedTarget,
    super.key,
  });

  final AdminReportsController controller;
  final bool canRead;
  final ValueChanged<String>? onOpenRelatedTarget;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

final class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _searchController = TextEditingController();
  final _assigneeController = TextEditingController();
  final _noteController = TextEditingController();
  bool _allMatching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    if (widget.canRead) unawaited(widget.controller.loadInbox());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _searchController.dispose();
    _assigneeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onStateChanged(AdminReportsState _) {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    _allMatching = false;
    await widget.controller.loadInbox(search: _searchController.text);
  }

  Future<void> _changeStatus(AdminReportStatus? status) async {
    _allMatching = false;
    await widget.controller.loadInbox(
      status: status,
      clearStatus: status == null,
      search: _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canRead) return const _PermissionDeniedView();
    final state = widget.controller.state;
    return ListView(
      key: const ValueKey('admin-reports-screen'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Report review', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Review submitted reports and make status changes with a revision check.',
        ),
        const SizedBox(height: 20),
        _InboxControls(
          state: state,
          searchController: _searchController,
          onSearch: _search,
          onStatusChanged: _changeStatus,
        ),
        const SizedBox(height: 16),
        if (state.error != null)
          _ErrorMessage(
            message: state.error!,
            onRetry: state.loading ? null : _search,
          ),
        if (state.loading && state.reports.isEmpty)
          const _LoadingView()
        else if (state.reports.isEmpty)
          const _EmptyView()
        else ...[
          _BulkActions(
            state: state,
            allMatching: _allMatching,
            onSelected: (status) {
              _allMatching = false;
              unawaited(widget.controller.previewBulk(status));
            },
            onAllMatching: (status) {
              _allMatching = true;
              unawaited(
                widget.controller.previewBulk(status, allMatching: true),
              );
            },
          ),
          const SizedBox(height: 12),
          ...state.reports.map(
            (report) => _ReportRow(
              report: report,
              selected: state.selectedIds.contains(report.id),
              onSelected: () => widget.controller.toggleSelection(report.id),
              onOpen: () => unawaited(widget.controller.loadDetail(report.id)),
            ),
          ),
          if (state.nextCursor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const ValueKey('admin-reports-load-more'),
                onPressed: state.loading
                    ? null
                    : widget.controller.loadNextPage,
                child: Text(state.loading ? 'Loading…' : 'Load more reports'),
              ),
            ),
        ],
        if (state.bulkPreview != null) ...[
          const SizedBox(height: 20),
          AdminAudienceConfirmation(
            selection:
                state.bulkPreview!.audience ??
                AdminAudienceSelection.selected(
                  state.selectedIds,
                  resource: AdminAudienceResource.reports,
                ),
            preview: state.bulkPreview,
            action: state.bulkPreview!.action,
            payloadHash: state.bulkPreview!.payloadHash,
            onConfirm: widget.controller.confirmBulk,
          ),
        ],
        if (state.bulkMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              state.bulkMessage!,
              key: const ValueKey('admin-reports-bulk-message'),
            ),
          ),
        const SizedBox(height: 20),
        _DetailPanel(
          state: state,
          assigneeController: _assigneeController,
          noteController: _noteController,
          onOpenRelatedTarget: widget.onOpenRelatedTarget,
          onUpdate: (status) => unawaited(_updateDetail(status)),
          onAddNote: () => unawaited(_addNote()),
        ),
      ],
    );
  }

  Future<void> _updateDetail(AdminReportStatus status) async {
    await widget.controller.updateDetail(
      status: status,
      assigneeUserId: _assigneeController.text,
    );
  }

  Future<void> _addNote() async {
    final text = _noteController.text;
    await widget.controller.addNote(text);
    if (mounted && widget.controller.state.error == null) {
      _noteController.clear();
    }
  }
}

final class _InboxControls extends StatelessWidget {
  const _InboxControls({
    required this.state,
    required this.searchController,
    required this.onSearch,
    required this.onStatusChanged,
  });

  final AdminReportsState state;
  final TextEditingController searchController;
  final Future<void> Function() onSearch;
  final Future<void> Function(AdminReportStatus?) onStatusChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('admin-report-search'),
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => unawaited(onSearch()),
            decoration: const InputDecoration(
              labelText: 'Search reports',
              hintText: 'text or target identity',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const ValueKey('admin-report-search-submit'),
                onPressed: state.loading ? null : onSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<AdminReportStatus>(
                  key: const ValueKey('admin-report-status-filter'),
                  initialValue: state.query.status,
                  isExpanded: true,
                  hint: const Text('Any status'),
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: AdminReportStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.loading
                      ? null
                      : (status) => unawaited(onStatusChanged(status)),
                ),
              ),
              if (state.query.status != null)
                TextButton(
                  onPressed: state.loading
                      ? null
                      : () => unawaited(onStatusChanged(null)),
                  child: const Text('Clear status'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _BulkActions extends StatelessWidget {
  const _BulkActions({
    required this.state,
    required this.allMatching,
    required this.onSelected,
    required this.onAllMatching,
  });

  final AdminReportsState state;
  final bool allMatching;
  final ValueChanged<AdminReportStatus> onSelected;
  final ValueChanged<AdminReportStatus> onAllMatching;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedIds.length;
    final allMatchingAllowed = state.query.search.trim().isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              selected == 0
                  ? 'No reports selected'
                  : '$selected report${selected == 1 ? '' : 's'} selected',
            ),
            OutlinedButton(
              key: const ValueKey('admin-reports-preview-resolve-selected'),
              onPressed: selected == 0
                  ? null
                  : () => onSelected(AdminReportStatus.resolved),
              child: const Text('Preview resolve selected'),
            ),
            OutlinedButton(
              key: const ValueKey('admin-reports-preview-dismiss-selected'),
              onPressed: selected == 0
                  ? null
                  : () => onSelected(AdminReportStatus.dismissed),
              child: const Text('Preview dismiss selected'),
            ),
            OutlinedButton(
              key: const ValueKey('admin-reports-preview-resolve-all'),
              onPressed: allMatchingAllowed
                  ? () => onAllMatching(AdminReportStatus.resolved)
                  : null,
              child: Text(
                allMatching
                    ? 'Preview all matching ✓'
                    : 'Preview resolve all matching',
              ),
            ),
            OutlinedButton(
              key: const ValueKey('admin-reports-preview-dismiss-all'),
              onPressed: allMatchingAllowed
                  ? () => onAllMatching(AdminReportStatus.dismissed)
                  : null,
              child: const Text('Preview dismiss all matching'),
            ),
            if (!allMatchingAllowed)
              const Text('Clear search to use all-matching actions.'),
          ],
        ),
      ),
    );
  }
}

final class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.selected,
    required this.onSelected,
    required this.onOpen,
  });

  final AdminReport report;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final reporter = report.reporterUsername?.trim();
    final reporterText = reporter == null || reporter.isEmpty
        ? report.reporterUserId
        : reporter;
    return Semantics(
      container: true,
      button: true,
      label: 'Open report ${report.id}',
      child: Card(
        child: ListTile(
          key: ValueKey('admin-report-${report.id}'),
          leading: Checkbox(
            value: selected,
            onChanged: (_) => onSelected(),
            semanticLabel: 'Select report ${report.id}',
          ),
          title: Text(report.text),
          subtitle: Text(
            'Reporter: $reporterText\nTarget: ${report.target.displayText}',
          ),
          isThreeLine: true,
          trailing: Chip(label: Text(_statusLabel(report.status))),
          onTap: onOpen,
        ),
      ),
    );
  }
}

final class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.state,
    required this.assigneeController,
    required this.noteController,
    required this.onOpenRelatedTarget,
    required this.onUpdate,
    required this.onAddNote,
  });

  final AdminReportsState state;
  final TextEditingController assigneeController;
  final TextEditingController noteController;
  final ValueChanged<String>? onOpenRelatedTarget;
  final ValueChanged<AdminReportStatus> onUpdate;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    if (state.loadingDetail && state.detail == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final report = state.detail;
    if (report == null) return const SizedBox.shrink();
    final targetId = report.target.userId;
    return Card(
      key: const ValueKey('admin-report-detail'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report detail',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(report.text),
            if (report.legacyMessage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Legacy context: ${report.legacyMessage}'),
            ],
            const SizedBox(height: 12),
            Text(
              'Reporter: ${report.reporterUsername ?? report.reporterUserId}',
            ),
            Text('Related target: ${report.target.displayText}'),
            if (!report.target.deleted &&
                targetId != null &&
                targetId.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenRelatedTarget == null
                      ? null
                      : () => onOpenRelatedTarget!(targetId),
                  child: const Text('View related target'),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: assigneeController,
              decoration: const InputDecoration(
                labelText: 'Assignee user ID',
                hintText: 'Leave blank to clear assignment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: state.loadingDetail
                      ? null
                      : () => onUpdate(AdminReportStatus.resolved),
                  child: const Text('Resolve'),
                ),
                OutlinedButton(
                  onPressed: state.loadingDetail
                      ? null
                      : () => onUpdate(AdminReportStatus.dismissed),
                  child: const Text('Dismiss'),
                ),
                OutlinedButton(
                  onPressed: state.loadingDetail
                      ? null
                      : () => onUpdate(AdminReportStatus.open),
                  child: const Text('Reopen'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Internal note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: state.loadingDetail ? null : onAddNote,
                child: const Text('Add note'),
              ),
            ),
            if (state.error != null)
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            if (report.notes.isEmpty)
              const Text('No internal notes yet.')
            else
              ...report.notes.map(
                (note) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(note.text),
                  subtitle: Text('Actor: ${note.actorUserId}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('You do not have permission to review reports.'),
    ),
  );
}

final class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading reports'),
    ),
  );
}

final class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Text('No reports match this filter.'),
  );
}

final class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _statusLabel(AdminReportStatus status) => switch (status) {
  AdminReportStatus.open => 'Open',
  AdminReportStatus.resolved => 'Resolved',
  AdminReportStatus.dismissed => 'Dismissed',
};
