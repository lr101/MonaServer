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
        const SizedBox(height: 12),
        for (final job in state.jobs)
          _JobCard(job: job, controller: widget.controller),
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
}

final class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.controller});

  final AdminJobRecord job;
  final AdminJobsController controller;

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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => controller.retry(job.id),
                child: const Text('Retry eligible failures'),
              ),
              OutlinedButton(
                onPressed: () => controller.requestCancellation(job.id),
                child: const Text('Cancel pending work'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
