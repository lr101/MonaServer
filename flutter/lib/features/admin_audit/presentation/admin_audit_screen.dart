import 'package:buff_lisa/features/admin_audit/presentation/admin_audit_controller.dart';
import 'package:flutter/material.dart';

/// Constructor-only seam for T10 composition; it does not own app navigation.
final class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({required this.controller, super.key});

  final AdminAuditController controller;

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

final class _AdminAuditScreenState extends State<AdminAuditScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed(AdminAuditState _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Audit history', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (final event in state.events)
          ListTile(
            title: Text(event.summary),
            subtitle: Text(
              '${event.actionLabel} · ${event.occurredAt.toUtc()}',
            ),
          ),
        if (state.nextCursor != null)
          OutlinedButton(
            onPressed: state.loading ? null : widget.controller.loadNextPage,
            child: const Text('Load more audit history'),
          ),
        if (state.loading) const LinearProgressIndicator(),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          Text(state.message!, key: const ValueKey('admin-audit-message')),
        ],
      ],
    );
  }
}
