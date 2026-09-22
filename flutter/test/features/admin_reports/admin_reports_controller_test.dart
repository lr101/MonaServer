import 'dart:async';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_ports.dart';
import 'package:buff_lisa/features/admin_reports/presentation/admin_reports_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads a cursor page and keeps selected report IDs across pages',
    () async {
      final repository = _ReportsRepository(
        pages: [
          _page(['one'], 'cursor-1'),
          _page(['two'], null),
        ],
      );
      final controller = AdminReportsController(repository);

      await controller.loadInbox();
      controller.toggleSelection('one');
      await controller.loadNextPage();

      expect(controller.state.reports.map((report) => report.id), [
        'one',
        'two',
      ]);
      expect(controller.state.selectedIds, {'one'});
      expect(repository.queries.last.cursor, 'cursor-1');
    },
  );

  test('ignores a stale filtered inbox response', () async {
    final first = Completer<AdminReportPage>();
    final repository = _ReportsRepository(
      futures: [
        first.future,
        _page(['new'], null),
      ],
    );
    final controller = AdminReportsController(repository);

    final pending = controller.loadInbox(search: 'old');
    await controller.loadInbox(search: 'new');
    first.complete(_page(['old'], null));
    await pending;

    expect(controller.state.query.search, 'new');
    expect(controller.state.reports.single.id, 'new');
  });

  test('conflicting revision asks the reviewer to reload without overwriting detail', () async {
    final repository = _ReportsRepository(
      detail: _report('one', revision: 2),
      updateError: const AdminReportsTransportException(409),
    );
    final controller = AdminReportsController(repository);

    await controller.loadDetail('one');
    await controller.updateDetail(status: AdminReportStatus.resolved);

    expect(controller.state.detail?.revision, 2);
    expect(controller.state.error, contains('changed by another reviewer'));
  });

  test(
    'adds notes and applies assignment/status updates through the port',
    () async {
      final repository = _ReportsRepository(
        detail: _report('one', revision: 2),
      );
      final controller = AdminReportsController(repository);

      await controller.loadDetail('one');
      await controller.updateDetail(
        status: AdminReportStatus.resolved,
        assigneeUserId: 'admin-2',
        note: 'Reviewed carefully',
      );
      await controller.addNote('Follow-up note');

      expect(repository.updates.single.status, AdminReportStatus.resolved);
      expect(repository.updates.single.assigneeUserId, 'admin-2');
      expect(
        controller.state.detail?.notes.map((note) => note.text),
        contains('Follow-up note'),
      );
    },
  );

  test('does not overlap detail mutations while one is saving', () async {
    final update = Completer<AdminReport>();
    final repository = _ReportsRepository(
      detail: _report('one', revision: 2),
      updateFuture: update.future,
    );
    final controller = AdminReportsController(repository);

    await controller.loadDetail('one');
    final first = controller.updateDetail(status: AdminReportStatus.resolved);
    final second = controller.addNote('Must wait');

    await second;
    expect(repository.updates, hasLength(1));
    update.complete(
      _report('one', revision: 3).copyWith(status: AdminReportStatus.resolved),
    );
    await first;
    expect(controller.state.loadingDetail, isFalse);
  });

  test(
    'clears an empty assignee instead of sending a blank identity',
    () async {
      final repository = _ReportsRepository(
        detail: _report('one', revision: 2),
      );
      final controller = AdminReportsController(repository);

      await controller.loadDetail('one');
      await controller.updateDetail(
        status: AdminReportStatus.open,
        assigneeUserId: '  ',
      );

      expect(repository.updates.single.assigneeUserId, isNull);
      expect(repository.updates.single.clearAssignee, isTrue);
    },
  );

  test(
    'drops a bulk preview that completes after the selection changes',
    () async {
      final preview = Completer<AdminAudiencePreview>();
      final repository = _ReportsRepository(previewFuture: preview.future);
      final controller = AdminReportsController(repository);
      controller.toggleSelection('one');

      final pending = controller.previewBulk(AdminReportStatus.resolved);
      controller.toggleSelection('two');
      preview.complete(_previewForSelection({'one'}));
      await pending;

      expect(controller.state.bulkPreview, isNull);
      expect(controller.state.bulkStatus, isNull);
    },
  );

  test(
    'does not surface a stale bulk commit error after the selection changes',
    () async {
      final commit = Completer<AdminReportBulkOutcome>();
      final repository = _ReportsRepository(bulkFuture: commit.future);
      final controller = AdminReportsController(repository);
      controller.toggleSelection('one');
      await controller.previewBulk(AdminReportStatus.resolved);

      final pending = controller.confirmBulk();
      await controller.loadInbox(search: 'new-filter');
      commit.completeError(const AdminReportsTransportException(503));
      await pending;

      expect(controller.state.error, isNull);
    },
  );

  test('surfaces a successful bulk outcome after the inbox changes', () async {
    final commit = Completer<AdminReportBulkOutcome>();
    final repository = _ReportsRepository(bulkFuture: commit.future);
    final controller = AdminReportsController(repository);
    controller.toggleSelection('one');
    await controller.previewBulk(AdminReportStatus.resolved);

    final pending = controller.confirmBulk();
    await controller.loadInbox(search: 'changed');
    commit.complete(const AdminReportBulkOutcome(changed: 1, skipped: 0));
    await pending;

    expect(
      controller.state.bulkMessage,
      '1 report was resolved while the inbox changed. Refresh to see the latest results.',
    );
  });

  test(
    'previews and confirms selected report actions using the frozen audience',
    () async {
      final repository = _ReportsRepository();
      final controller = AdminReportsController(repository);
      controller.toggleSelection('one');
      controller.toggleSelection('two');

      await controller.previewBulk(AdminReportStatus.dismissed);
      await controller.confirmBulk();

      expect(
        repository.previewed.single.audience.resource,
        AdminAudienceResource.reports,
      );
      expect(repository.previewed.single.audience.selectedIds, {'one', 'two'});
      expect(repository.bulkCommands.single.commit.snapshotId, 'snapshot-1');
      expect(controller.state.bulkMessage, '2 reports were dismissed.');
      expect(repository.queries, isNotEmpty);
    },
  );

  test(
    'does not send a second bulk commit while the first is in flight',
    () async {
      final commit = Completer<AdminReportBulkOutcome>();
      final repository = _ReportsRepository(bulkFuture: commit.future);
      final controller = AdminReportsController(repository);
      controller.toggleSelection('one');
      await controller.previewBulk(AdminReportStatus.resolved);

      final first = controller.confirmBulk();
      final second = controller.confirmBulk();
      commit.complete(const AdminReportBulkOutcome(changed: 1, skipped: 0));
      await Future.wait([first, second]);

      expect(repository.bulkCommands, hasLength(1));
    },
  );

  test(
    'uses the current status filter for all-matching report actions',
    () async {
      final repository = _ReportsRepository();
      final controller = AdminReportsController(repository);

      await controller.loadInbox(status: AdminReportStatus.open);
      await controller.previewBulk(
        AdminReportStatus.dismissed,
        allMatching: true,
      );

      final audience = repository.previewed.single.audience;
      expect(audience.kind, AdminAudienceSelectionKind.filter);
      expect(audience.filter?.statuses, {AdminAudienceReportStatus.open});
    },
  );

  test('uses the explicit reports all selection without a filter', () async {
    final repository = _ReportsRepository();
    final controller = AdminReportsController(repository);

    await controller.loadInbox();
    await controller.previewBulk(AdminReportStatus.resolved, allMatching: true);

    final audience = repository.previewed.single.audience;
    expect(audience.kind, AdminAudienceSelectionKind.all);
    expect(audience.resource, AdminAudienceResource.reports);
  });

  test(
    'does not broaden an all-matching action beyond a text search',
    () async {
      final repository = _ReportsRepository();
      final controller = AdminReportsController(repository);

      await controller.loadInbox(search: 'needle');
      await controller.previewBulk(
        AdminReportStatus.resolved,
        allMatching: true,
      );

      expect(repository.previewed, isEmpty);
      expect(
        controller.state.error,
        'Clear the text search before using all-matching report actions.',
      );
    },
  );

  test('reports capability denial and never offers a bulk commit', () async {
    final repository = _ReportsRepository(
      pages: [
        Future<AdminReportPage>.error(
          const AdminReportsTransportException(403),
        ),
      ],
    );
    var denied = false;
    final controller = AdminReportsController(
      repository,
      onCapabilityDenied: () => denied = true,
    );

    await controller.loadInbox();
    await controller.confirmBulk();

    expect(denied, isTrue);
    expect(
      controller.state.error,
      'You do not have permission to review reports.',
    );
    expect(repository.bulkCommands, isEmpty);
  });
}

AdminReportPage _page(List<String> ids, String? cursor) =>
    AdminReportPage(items: ids.map(_report).toList(), nextCursor: cursor);

AdminReport _report(String id, {int revision = 1}) => AdminReport(
  id: id,
  text: 'Text for $id',
  reporterUserId: 'reporter-$id',
  reporterUsername: 'reporter',
  target: const AdminReportTarget(userId: null, username: null, deleted: true),
  status: AdminReportStatus.open,
  revision: revision,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _ReportsRepository implements AdminReportsRepository {
  _ReportsRepository({
    List<Object>? pages,
    List<Object>? futures,
    this.detail,
    this.updateError,
    this.updateFuture,
    this.previewFuture,
    this.bulkFuture,
  }) : _pages = [...?pages, ...?futures];

  final List<Object> _pages;
  final AdminReport? detail;
  final Object? updateError;
  final Future<AdminReport>? updateFuture;
  final Future<AdminAudiencePreview>? previewFuture;
  final Future<AdminReportBulkOutcome>? bulkFuture;
  final queries = <AdminReportQuery>[];
  final updates = <AdminReportUpdate>[];
  final previewed = <AdminAudiencePreviewRequest>[];
  final bulkCommands = <AdminReportBulkCommand>[];

  @override
  Future<AdminReportPage> list(AdminReportQuery query) async {
    queries.add(query);
    final value = _pages.isEmpty ? _page(const [], null) : _pages.removeAt(0);
    return value is Future<AdminReportPage> ? value : value as AdminReportPage;
  }

  @override
  Future<AdminReport?> get(String reportId) async =>
      detail ?? _report(reportId);

  @override
  Future<AdminReport> update(AdminReportUpdate update) async {
    updates.add(update);
    if (updateError != null) throw updateError!;
    if (updateFuture != null) return updateFuture!;
    return _report(
      update.reportId,
      revision: update.expectedRevision + 1,
    ).copyWith(status: update.status, assigneeUserId: update.assigneeUserId);
  }

  @override
  Future<AdminReportNote> addNote(String reportId, String text) async =>
      AdminReportNote(
        id: 'note-${text.length}',
        actorUserId: 'operator',
        text: text,
        createdAt: DateTime.utc(2026),
      );

  @override
  Future<AdminAudiencePreview> preview(
    AdminAudiencePreviewRequest request,
  ) async {
    previewed.add(request);
    if (previewFuture != null) return previewFuture!;
    return AdminAudiencePreview(
      snapshotId: 'snapshot-1',
      accountAudienceCount: request.audience.selectedIds.length,
      eligibleRecipientCount: request.audience.selectedIds.length,
      excludedCount: 0,
      deviceDeliveryCount: 0,
      expiresAt: DateTime.utc(2027),
      audience: request.audience,
      action: request.action,
      payloadHash: 'hash-1',
      resource: AdminAudienceResource.reports,
    );
  }

  @override
  Future<AdminReportBulkOutcome> commitBulk(
    AdminReportBulkCommand command,
  ) async {
    bulkCommands.add(command);
    if (bulkFuture != null) return bulkFuture!;
    return const AdminReportBulkOutcome(changed: 2, skipped: 0);
  }
}

AdminAudiencePreview _previewForSelection(Set<String> ids) =>
    AdminAudiencePreview(
      snapshotId: 'snapshot-1',
      accountAudienceCount: ids.length,
      eligibleRecipientCount: ids.length,
      excludedCount: 0,
      deviceDeliveryCount: 0,
      expiresAt: DateTime.utc(2027),
      audience: AdminAudienceSelection.selected(
        ids,
        resource: AdminAudienceResource.reports,
      ),
      action: const AdminAudienceAction(
        kind: AdminAudienceActionKind.reportResolve,
      ),
      payloadHash: 'hash-1',
      resource: AdminAudienceResource.reports,
    );
