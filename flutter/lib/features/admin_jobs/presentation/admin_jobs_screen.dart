import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';
import 'package:buff_lisa/features/admin_jobs/presentation/admin_jobs_controller.dart';
import 'package:flutter/material.dart';

/// Constructor-only seam for T10 composition; polling remains opt-in to wiring.
final class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({required this.controller, super.key});

  final AdminJobsController controller;

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

final class _AdminJobsScreenState extends State<AdminJobsScreen> {
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

  void _changed(AdminJobsState _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Job monitoring',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          Text(state.message!, key: const ValueKey('admin-jobs-message')),
        ],
        Text(
          state.loadedAt == null
              ? 'Job data has not been refreshed yet.'
              : 'Last refreshed: ${state.loadedAt!.toUtc().toIso8601String()}',
        ),
        const SizedBox(height: 12),
        for (final job in state.jobs)
          _JobCard(
            job: job,
            controller: widget.controller,
            refreshedAt: state.loadedAt,
            onCancel: () => _confirmCancellation(job.id),
          ),
        if (state.nextCursor != null)
          OutlinedButton(
            onPressed: state.loading ? null : widget.controller.loadNextPage,
            child: const Text('Load more jobs'),
          ),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _confirmCancellation(String jobId) async {
    widget.controller.requestCancellation(jobId);
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel pending work?'),
        content: const Text(
          'Cancellation stops pending work only. Accepted deliveries cannot be unsent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep job'),
          ),
          ElevatedButton(
            key: const ValueKey('admin-job-cancel-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel pending work'),
          ),
        ],
      ),
    );
    if (acknowledged == true) {
      await widget.controller.confirmCancellation(acknowledged: true);
    }
  }
}

final class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.controller,
    required this.refreshedAt,
    required this.onCancel,
  });

  final AdminJobRecord job;
  final AdminJobsController controller;
  final DateTime? refreshedAt;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.actionLabel, style: Theme.of(context).textTheme.titleMedium),
          Text(job.statusExplanation),
          if (job.deliveryExplanation != null) Text(job.deliveryExplanation!),
          Text(
            refreshedAt == null
                ? 'Job freshness is unavailable until data refreshes.'
                : job.freshnessDescription(refreshedAt!),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => controller.retry(job.id),
                child: const Text('Retry eligible failures'),
              ),
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel pending work'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
