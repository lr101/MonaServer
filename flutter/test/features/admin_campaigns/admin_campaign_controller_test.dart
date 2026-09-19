import 'dart:async';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_ports.dart';
import 'package:buff_lisa/features/admin_campaigns/presentation/admin_campaign_controller.dart';
import 'package:buff_lisa/features/admin_campaigns/presentation/admin_campaign_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables campaign confirmation until a frozen preview exists', (
    tester,
  ) async {
    final controller = AdminCampaignController(_CampaignRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCampaignScreen(
            controller: controller,
            audience: AdminAudienceSelection.selected(const {'one'}),
            testRecipientUserId: 'operator',
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Confirm campaign'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('editing a previewed campaign invalidates stale confirmation', (
    tester,
  ) async {
    final repository = _CampaignRepository();
    final controller = AdminCampaignController(repository);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCampaignScreen(
            controller: controller,
            audience: AdminAudienceSelection.selected(const {'one'}),
            testRecipientUserId: 'operator',
          ),
        ),
      ),
    );
    await tester.enterText(find.bySemanticsLabel('Subject'), 'Original');
    await tester.enterText(find.bySemanticsLabel('Message'), 'Original copy');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Preview audience'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Message'), 'Edited copy');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm campaign'));

    expect(repository.commitCount, 0);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Confirm campaign'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('changing audience away and back invalidates a frozen preview', (
    tester,
  ) async {
    final repository = _CampaignRepository();
    final controller = AdminCampaignController(repository);
    final firstAudience = AdminAudienceSelection.selected(const {'one'});
    final secondAudience = AdminAudienceSelection.selected(const {'two'});

    Widget screenFor(AdminAudienceSelection audience) => MaterialApp(
      home: Scaffold(
        body: AdminCampaignScreen(
          controller: controller,
          audience: audience,
          testRecipientUserId: 'operator',
        ),
      ),
    );

    await tester.pumpWidget(screenFor(firstAudience));
    await tester.enterText(find.bySemanticsLabel('Subject'), 'Original');
    await tester.enterText(find.bySemanticsLabel('Message'), 'Original copy');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Preview audience'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(screenFor(secondAudience));
    await tester.pump();
    await tester.pumpWidget(screenFor(firstAudience));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm campaign'));

    expect(repository.commitCount, 0);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Confirm campaign'),
          )
          .onPressed,
      isNull,
    );
  });

  test('an edit cannot fence a late accepted campaign commit', () async {
    final accepted = Completer<AdminCampaignCommitResult>();
    final repository = _CampaignRepository(commitFuture: accepted.future);
    final controller = AdminCampaignController(repository);
    final audience = AdminAudienceSelection.selected(const {'one'});
    const original = AdminCampaignDraft.email(
      subject: 'Original',
      body: 'Original copy',
    );

    await controller.preview(audience, original);
    final commit = controller.confirm();
    controller.updateDraft(
      audience,
      const AdminCampaignDraft.email(subject: 'Edited', body: 'Edited copy'),
    );
    accepted.complete(const AdminCampaignCommitResult(jobId: 'job-1'));
    await commit;

    expect(controller.state.submitting, isFalse);
    expect(controller.state.jobId, 'job-1');
    expect(controller.state.message, 'Campaign accepted for delivery.');
  });

  test(
    'previews selected, filtered, and all audiences without changing scope',
    () async {
      final repository = _CampaignRepository();
      final controller = AdminCampaignController(repository);
      const draft = AdminCampaignDraft.email(
        subject: 'Service notice',
        body: 'The service will be unavailable briefly.',
      );
      final audiences = <AdminAudienceSelection>[
        AdminAudienceSelection.selected(const {'one'}),
        AdminAudienceSelection.filter(const AdminAudienceFilter(search: 'oak')),
        AdminAudienceSelection.all(),
      ];

      for (final audience in audiences) {
        await controller.preview(audience, draft);
      }

      expect(repository.previewed.map((request) => request.audience.kind), [
        AdminAudienceSelectionKind.selected,
        AdminAudienceSelectionKind.filter,
        AdminAudienceSelectionKind.all,
      ]);
    },
  );

  test('does not commit an expired snapshot', () async {
    final repository = _CampaignRepository(expiredPreview: true);
    final controller = AdminCampaignController(repository);
    final audience = AdminAudienceSelection.selected(const {'one'});
    const draft = AdminCampaignDraft.loginLink();

    await controller.preview(audience, draft);
    await controller.confirm();

    expect(repository.commitCount, 0);
    expect(
      controller.state.message,
      'This preview is stale. Prepare a new preview.',
    );
  });

  test('shares one commit while confirmation is retried', () async {
    final accepted = Completer<AdminCampaignCommitResult>();
    final repository = _CampaignRepository(commitFuture: accepted.future);
    final controller = AdminCampaignController(repository);

    await controller.preview(
      AdminAudienceSelection.selected(const {'one'}),
      const AdminCampaignDraft.loginLink(),
    );
    final first = controller.confirm();
    final retry = controller.confirm();
    accepted.complete(const AdminCampaignCommitResult(jobId: 'job-1'));
    await Future.wait([first, retry]);

    expect(repository.commitCount, 1);
    expect(controller.state.jobId, 'job-1');
  });

  test(
    'reuses one idempotency key after an uncertain commit failure',
    () async {
      final repository = _CampaignRepository(
        commitResults: [
          () => Future.error(const AdminCampaignTransportException(503)),
          () => Future.value(const AdminCampaignCommitResult(jobId: 'job-1')),
        ],
      );
      final controller = AdminCampaignController(
        repository,
        idempotencyKey: () => 'stable-commit-key',
      );

      await controller.preview(
        AdminAudienceSelection.selected(const {'one'}),
        const AdminCampaignDraft.loginLink(),
      );
      await controller.confirm();
      await controller.confirm();

      expect(repository.commits.map((command) => command.idempotencyKey), [
        'stable-commit-key',
        'stable-commit-key',
      ]);
    },
  );

  test(
    'reports unavailable test delivery without claiming it was sent',
    () async {
      final controller = AdminCampaignController(
        _CampaignRepository(
          testResult: const AdminCampaignTestResult.unavailable(),
        ),
      );

      await controller.sendTest(
        recipientUserId: 'operator',
        draft: const AdminCampaignDraft.loginLink(),
      );

      expect(
        controller.state.testDelivery,
        AdminCampaignTestDelivery.unavailable,
      );
      expect(
        controller.state.message,
        'Test delivery is unavailable. Nothing was sent.',
      );
    },
  );

  test(
    'session expiry ignores a late preview response and stops later work',
    () async {
      final preview = Completer<AdminAudiencePreview>();
      final repository = _CampaignRepository(previewFuture: preview.future);
      var unauthorized = 0;
      final controller = AdminCampaignController(
        repository,
        onUnauthorized: () => unauthorized++,
      );

      final pending = controller.preview(
        AdminAudienceSelection.selected(const {'one'}),
        const AdminCampaignDraft.loginLink(),
      );
      controller.expireSession();
      preview.complete(
        _preview(
          AdminAudiencePreviewRequest(
            audience: AdminAudienceSelection.selected(const {'one'}),
            action: const AdminAudienceAction(
              kind: AdminAudienceActionKind.loginLink,
            ),
          ),
        ),
      );
      await pending;
      await controller.sendTest(
        recipientUserId: 'operator',
        draft: const AdminCampaignDraft.loginLink(),
      );

      expect(controller.state.preview, isNull);
      expect(repository.testSendCount, 0);
      expect(unauthorized, 1);
    },
  );
}

final class _CampaignRepository implements AdminCampaignRepository {
  _CampaignRepository({
    this.expiredPreview = false,
    this._previewFuture,
    this._commitFuture,
    this._commitResults,
    this.testResult = const AdminCampaignTestResult.accepted(),
  });

  final List<AdminAudiencePreviewRequest> previewed = [];
  final bool expiredPreview;
  final Future<AdminAudiencePreview>? _previewFuture;
  final Future<AdminCampaignCommitResult>? _commitFuture;
  final List<Future<AdminCampaignCommitResult> Function()>? _commitResults;
  final AdminCampaignTestResult testResult;
  final List<AdminCampaignCommitCommand> commits = [];
  int commitCount = 0;
  int testSendCount = 0;

  @override
  Future<AdminAudiencePreview> preview(AdminAudiencePreviewRequest request) {
    previewed.add(request);
    return _previewFuture ??
        Future.value(_preview(request, expired: expiredPreview));
  }

  @override
  Future<AdminCampaignCommitResult> commit(AdminCampaignCommitCommand command) {
    commitCount++;
    commits.add(command);
    final results = _commitResults;
    if (results != null) return results[commitCount - 1]();
    return _commitFuture ??
        Future.value(const AdminCampaignCommitResult(jobId: 'job-1'));
  }

  @override
  Future<AdminCampaignTestResult> sendTest({
    required String recipientUserId,
    required AdminAudienceAction action,
  }) async {
    testSendCount++;
    return testResult;
  }
}

AdminAudiencePreview _preview(
  AdminAudiencePreviewRequest request, {
  bool expired = false,
}) => AdminAudiencePreview(
  snapshotId: 'snapshot-1',
  accountAudienceCount: 2,
  eligibleRecipientCount: 1,
  excludedCount: 1,
  deviceDeliveryCount: 1,
  expiresAt: expired
      ? DateTime.now().subtract(const Duration(minutes: 1))
      : DateTime.now().add(const Duration(minutes: 1)),
  exclusions: const [AdminAudienceExclusion(id: 'two', reason: 'opted out')],
  audience: request.audience,
  action: request.action,
  payloadHash: 'bound-payload',
  resource: AdminAudienceResource.accounts,
);
