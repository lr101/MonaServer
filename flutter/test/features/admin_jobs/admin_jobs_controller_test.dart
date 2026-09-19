import 'dart:async';

import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';
import 'package:buff_lisa/features/admin_jobs/domain/admin_job_ports.dart';
import 'package:buff_lisa/features/admin_jobs/presentation/admin_jobs_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explains partial failures and uncertain provider acceptance', () {
    const job = AdminJobRecord(
      id: 'job-1',
      actionLabel: 'Email campaign',
      status: AdminJobStatus.completedWithErrors,
      pendingCount: 0,
      completedCount: 3,
      failedCount: 1,
      unknownDeliveryCount: 1,
      cancellationRequested: false,
    );

    expect(job.statusExplanation, 'Completed with errors: 1 recipient failed.');
    expect(
      job.deliveryExplanation,
      '1 delivery is uncertain after provider acceptance. Retrying may duplicate it.',
    );
  });

  test(
    'requires a cancellation warning acknowledgement before cancelling',
    () async {
      final repository = _JobsRepository();
      final controller = AdminJobsController(repository);

      controller.requestCancellation('job-1');
      await controller.confirmCancellation();
      expect(repository.cancelled, isEmpty);

      await controller.confirmCancellation(acknowledged: true);
      expect(repository.cancelled, ['job-1']);
    },
  );

  test('shares a retry command while it is in flight', () async {
    final pending = Completer<AdminJobCommandResult>();
    final repository = _JobsRepository(retryFuture: pending.future);
    final controller = AdminJobsController(repository);

    final first = controller.retry('job-1');
    final retry = controller.retry('job-1');
    pending.complete(const AdminJobCommandResult(jobId: 'job-2'));
    await Future.wait([first, retry]);

    expect(repository.retried, ['job-1']);
  });

  test(
    'session expiry stops a late page response from updating the UI',
    () async {
      final page = Completer<AdminJobPage>();
      final controller = AdminJobsController(
        _JobsRepository(pageFuture: page.future),
      );

      final load = controller.load();
      controller.expireSession();
      page.complete(
        const AdminJobPage(
          items: [
            AdminJobRecord(
              id: 'job-1',
              actionLabel: 'Email campaign',
              status: AdminJobStatus.running,
              pendingCount: 1,
              completedCount: 0,
              failedCount: 0,
              unknownDeliveryCount: 0,
              cancellationRequested: false,
            ),
          ],
        ),
      );
      await load;

      expect(controller.state.jobs, isEmpty);
    },
  );
}

final class _JobsRepository implements AdminJobsRepository {
  _JobsRepository({this._pageFuture, this._retryFuture});

  final Future<AdminJobPage>? _pageFuture;
  final Future<AdminJobCommandResult>? _retryFuture;
  final List<String> retried = [];
  final List<String> cancelled = [];

  @override
  Future<AdminJobPage> list(AdminJobQuery query) =>
      _pageFuture ?? Future.value(const AdminJobPage(items: []));

  @override
  Future<AdminJobCommandResult> retry(String jobId) {
    retried.add(jobId);
    return _retryFuture ?? Future.value(AdminJobCommandResult(jobId: jobId));
  }

  @override
  Future<AdminJobCommandResult> cancel(String jobId) async {
    cancelled.add(jobId);
    return AdminJobCommandResult(jobId: jobId);
  }
}
