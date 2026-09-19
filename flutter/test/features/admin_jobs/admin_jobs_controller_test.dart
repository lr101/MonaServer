import 'dart:async';

import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';
import 'package:buff_lisa/features/admin_jobs/domain/admin_job_ports.dart';
import 'package:buff_lisa/features/admin_jobs/presentation/admin_jobs_controller.dart';
import 'package:buff_lisa/features/admin_jobs/presentation/admin_jobs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explains partial failures and unconfirmed provider acceptance', () {
    final refreshedAt = DateTime.utc(2026, 9, 19, 12, 10);
    final job = AdminJobRecord(
      id: 'job-1',
      actionLabel: 'Email campaign',
      status: AdminJobStatus.completedWithErrors,
      pendingCount: 0,
      completedCount: 3,
      failedCount: 1,
      unknownDeliveryCount: 1,
      cancellationRequested: false,
      updatedAt: refreshedAt.subtract(const Duration(minutes: 10)),
    );

    expect(job.statusExplanation, 'Completed with errors: 1 recipient failed.');
    expect(
      job.deliveryExplanation,
      '1 delivery has unconfirmed provider acceptance. Retrying may duplicate it.',
    );
    expect(
      job.freshnessDescription(refreshedAt),
      'Updated 10 minutes before this refresh.',
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
      expect(repository.cancelled.map((command) => command.jobId), ['job-1']);
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

    expect(repository.retried.map((command) => command.jobId), ['job-1']);
  });

  test(
    'reuses an idempotency key after an ambiguous retry transport failure',
    () async {
      final repository = _JobsRepository(
        retryResults: [
          () => Future.error(const AdminJobsTransportException(503)),
          () => Future.value(const AdminJobCommandResult(jobId: 'job-1')),
        ],
      );
      final controller = AdminJobsController(
        repository,
        idempotencyKey: () => 'stable-retry-key',
      );

      await controller.retry('job-1');
      await controller.retry('job-1');

      expect(repository.retried.map((command) => command.idempotencyKey), [
        'stable-retry-key',
        'stable-retry-key',
      ]);
    },
  );

  test('records load time so job freshness is visible', () async {
    final loadedAt = DateTime.utc(2026, 9, 19, 12, 10);
    final controller = AdminJobsController(
      _JobsRepository(
        page: AdminJobPage(
          items: [
            _job(updatedAt: loadedAt.subtract(const Duration(minutes: 2))),
          ],
        ),
      ),
      clock: () => loadedAt,
    );

    await controller.load();

    expect(controller.state.loadedAt, loadedAt);
    expect(
      controller.state.jobs.single.freshnessDescription(
        controller.state.loadedAt!,
      ),
      'Updated 2 minutes before this refresh.',
    );
  });

  testWidgets(
    'cancellation dialog acknowledges and submits the pending command',
    (tester) async {
      final repository = _JobsRepository(page: AdminJobPage(items: [_job()]));
      final controller = AdminJobsController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminJobsScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Cancel pending work'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('admin-job-cancel-confirm')));
      await tester.pumpAndSettle();

      expect(repository.cancelled.map((command) => command.jobId), ['job-1']);
    },
  );

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
  _JobsRepository({
    this._pageFuture,
    this._retryFuture,
    this._retryResults,
    this.page,
  });

  final Future<AdminJobPage>? _pageFuture;
  final Future<AdminJobCommandResult>? _retryFuture;
  final List<Future<AdminJobCommandResult> Function()>? _retryResults;
  final AdminJobPage? page;
  final List<AdminJobCommand> retried = [];
  final List<AdminJobCommand> cancelled = [];

  @override
  Future<AdminJobPage> list(AdminJobQuery query) =>
      _pageFuture ?? Future.value(page ?? const AdminJobPage(items: []));

  @override
  Future<AdminJobCommandResult> retry(AdminJobCommand command) {
    retried.add(command);
    final results = _retryResults;
    if (results != null) return results[retried.length - 1]();
    return _retryFuture ??
        Future.value(AdminJobCommandResult(jobId: command.jobId));
  }

  @override
  Future<AdminJobCommandResult> cancel(AdminJobCommand command) async {
    cancelled.add(command);
    return AdminJobCommandResult(jobId: command.jobId);
  }
}

AdminJobRecord _job({DateTime? updatedAt}) => AdminJobRecord(
  id: 'job-1',
  actionLabel: 'Email campaign',
  status: AdminJobStatus.running,
  pendingCount: 1,
  completedCount: 0,
  failedCount: 0,
  unknownDeliveryCount: 0,
  cancellationRequested: false,
  updatedAt: updatedAt,
);
