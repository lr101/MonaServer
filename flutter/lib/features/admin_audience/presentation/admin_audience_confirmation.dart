import 'package:flutter/material.dart';

import '../domain/admin_audience_models.dart';

/// Shows the server-frozen audience preview before an administrative action is
/// committed. Empty selected audiences never expose an enabled confirm action.
final class AdminAudienceConfirmation extends StatelessWidget {
  const AdminAudienceConfirmation({
    required this.selection,
    this.preview,
    this.action,
    this.payloadHash,
    this.loading = false,
    this.onPreview,
    this.onConfirm,
    this.now,
    super.key,
  });

  final AdminAudienceSelection selection;
  final AdminAudiencePreview? preview;
  final AdminAudienceAction? action;
  final String? payloadHash;
  final bool loading;
  final VoidCallback? onPreview;
  final VoidCallback? onConfirm;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm =
        selection.isActionable &&
        (preview?.canConfirm(now, selection, action, payloadHash) ?? false) &&
        !loading;
    final hasEmptySelection =
        selection.kind == AdminAudienceSelectionKind.selected &&
        selection.selectedIds.isEmpty;
    final hasUnconstrainedFilter =
        selection.kind == AdminAudienceSelectionKind.filter &&
        !selection.isActionable;

    return Card(
      key: const ValueKey('admin-audience-confirmation'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Audience confirmation', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(selection.summary),
            if (preview != null) ...[
              const SizedBox(height: 16),
              _PreviewCounts(preview: preview!),
              if (preview!.isExpired(now)) ...[
                const SizedBox(height: 8),
                const Text('This preview has expired. Request a new preview.'),
              ],
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: selection.isActionable && !loading
                    ? onPreview
                    : null,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  loading ? 'Preparing preview…' : 'Preview audience',
                ),
              ),
            ],
            if (hasEmptySelection) ...[
              const SizedBox(height: 8),
              Text(
                'Select at least one account.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (hasUnconstrainedFilter) ...[
              const SizedBox(height: 8),
              Text(
                'Add a search or filter before using all matching accounts.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('admin-audience-confirm'),
              onPressed: canConfirm ? onConfirm : null,
              child: const Text('Confirm audience'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PreviewCounts extends StatelessWidget {
  const _PreviewCounts({required this.preview});

  final AdminAudiencePreview preview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Frozen audience preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${preview.accountAudienceCount} accounts in this snapshot'),
          Text('${preview.eligibleRecipientCount} eligible recipients'),
          Text('${preview.excludedCount} excluded'),
          Text('${preview.deviceDeliveryCount} device deliveries'),
          if (preview.exclusions.isNotEmpty)
            Text('${preview.exclusions.length} exclusions require review'),
        ],
      ),
    );
  }
}
