import 'dart:async';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_ports.dart';
import 'package:buff_lisa/features/admin_reports/presentation/admin_reports_controller.dart';
import 'package:buff_lisa/features/admin_reports/presentation/admin_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders deleted targets as text and exposes report review controls',
    (tester) async {
      final repository = _ScreenReportsRepository();
      final controller = AdminReportsController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(controller: controller, canRead: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report review'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('admin-reports-screen')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Deleted or unavailable target'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Open report one'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Load more reports'),
        findsNothing,
      );

      await tester.tap(find.bySemanticsLabel('Open report one'));
      await tester.pumpAndSettle();
      expect(find.text('Report detail'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('admin-report-assignee')),
            )
            .controller
            ?.text,
        'assigned-admin',
      );
      expect(find.widgetWithText(FilledButton, 'Resolve'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Dismiss'), findsOneWidget);

      final resolve = find.widgetWithText(FilledButton, 'Resolve');
      tester.widget<FilledButton>(resolve).onPressed!.call();
      await tester.pumpAndSettle();
      expect(repository.updates.single.assigneeUserId, 'assigned-admin');
      expect(repository.updates.single.clearAssignee, isFalse);
    },
  );

  testWidgets(
    'keeps report review visibly denied without starting an inbox request',
    (tester) async {
      final repository = _ScreenReportsRepository();
      final controller = AdminReportsController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(controller: controller, canRead: false),
        ),
      );

      expect(
        find.text('You do not have permission to review reports.'),
        findsOneWidget,
      );
      expect(repository.listed, isFalse);
    },
  );

  testWidgets('shows loading and then the empty inbox state', (tester) async {
    final page = Completer<AdminReportPage>();
    final repository = _ScreenReportsRepository(listFuture: page.future);
    final controller = AdminReportsController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminReportsScreen(controller: controller, canRead: true),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Loading reports'), findsOneWidget);

    page.complete(AdminReportPage(items: const []));
    await tester.pumpAndSettle();
    expect(find.text('No reports match this filter.'), findsOneWidget);
  });

  testWidgets('shows a retryable inbox error', (tester) async {
    final repository = _ScreenReportsRepository(
      listError: const AdminReportsTransportException(503),
    );
    final controller = AdminReportsController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminReportsScreen(controller: controller, canRead: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports are unavailable. Try again.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });

  testWidgets('disables all-matching actions while text search is active', (
    tester,
  ) async {
    final repository = _ScreenReportsRepository();
    final controller = AdminReportsController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminReportsScreen(controller: controller, canRead: true),
      ),
    );
    await tester.pumpAndSettle();
    await controller.loadInbox(search: 'needle');
    await tester.pumpAndSettle();

    final allMatching = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('admin-reports-preview-resolve-all')),
    );
    expect(allMatching.onPressed, isNull);
    expect(
      find.text('Clear search to use all-matching actions.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'honors review capabilities and activates search from the keyboard',
    (tester) async {
      final repository = _ScreenReportsRepository();
      final controller = AdminReportsController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            controller: controller,
            canRead: true,
            canReview: false,
            canResolve: false,
            canDismiss: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey('admin-reports-preview-resolve-selected'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('admin-reports-preview-resolve-all')),
            )
            .onPressed,
        isNull,
      );

      final searchField = find.byKey(const ValueKey('admin-report-search'));
      await tester.tap(searchField);
      await tester.enterText(searchField, 'keyboard');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repository.queries, hasLength(2));
      expect(repository.queries.last.search, 'keyboard');
    },
  );

  testWidgets(
    'keeps individual review actions available with bulk capabilities absent',
    (tester) async {
      final repository = _ScreenReportsRepository();
      final controller = AdminReportsController(repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            controller: controller,
            canRead: true,
            canReview: true,
            canResolve: false,
            canDismiss: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.loadDetail('one');
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('admin-reports-screen')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Resolve'))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Dismiss'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}

final class _ScreenReportsRepository implements AdminReportsRepository {
  _ScreenReportsRepository({
    this.listFuture,
    this.listError,
    AdminReportPage? page,
  }) : page = page ?? AdminReportPage(items: [_report]);

  final Future<AdminReportPage>? listFuture;
  final Object? listError;
  final AdminReportPage page;
  final updates = <AdminReportUpdate>[];
  final queries = <AdminReportQuery>[];
  bool listed = false;

  @override
  Future<AdminReportNote> addNote(String reportId, String text) =>
      throw UnimplementedError();

  @override
  Future<AdminReportBulkOutcome> commitBulk(AdminReportBulkCommand command) =>
      throw UnimplementedError();

  @override
  Future<AdminReport?> get(String reportId) async => _report;

  @override
  Future<AdminReportPage> list(AdminReportQuery query) async {
    listed = true;
    queries.add(query);
    if (listFuture != null) return listFuture!;
    if (listError != null) throw listError!;
    return page;
  }

  @override
  Future<AdminAudiencePreview> preview(AdminAudiencePreviewRequest request) =>
      throw UnimplementedError();

  @override
  Future<AdminReport> update(AdminReportUpdate update) async {
    updates.add(update);
    return _report.copyWith(
      status: update.status,
      assigneeUserId: update.assigneeUserId,
      clearAssigneeUserId: update.clearAssignee,
    );
  }
}

final _report = AdminReport(
  id: 'one',
  text: 'Safe text-only report',
  reporterUserId: 'reporter-one',
  reporterUsername: 'reporter',
  assigneeUserId: 'assigned-admin',
  target: const AdminReportTarget(userId: null, username: null, deleted: true),
  status: AdminReportStatus.open,
  revision: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
