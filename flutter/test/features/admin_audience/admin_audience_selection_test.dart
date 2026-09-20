import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unnamed filters are account-scoped', () {
    const filter = AdminAudienceFilter(search: 'must-use-account-filter');

    expect(filter.resource, AdminAudienceResource.accounts);
    expect(filter.search, 'must-use-account-filter');
    expect(filter.hasCriteria, isTrue);
  });

  test('reports factory constructs the report resource', () {
    final filter = AdminAudienceFilter.reports(
      statuses: const {AdminAudienceReportStatus.open},
    );

    expect(filter.resource, AdminAudienceResource.reports);
  });

  test('account filters reject copy transitions to reports', () {
    const filter = AdminAudienceFilter(search: 'alice');

    expect(
      () => filter.copyWith(resource: AdminAudienceResource.reports),
      throwsArgumentError,
    );
  });

  test('report filters reject copy transitions to accounts', () {
    final filter = AdminAudienceFilter.reports(
      statuses: const {AdminAudienceReportStatus.open},
    );

    expect(
      () => filter.copyWith(resource: AdminAudienceResource.accounts),
      throwsArgumentError,
    );
  });

  test('report filters reject account-only copy criteria', () {
    final filter = AdminAudienceFilter.reports(
      statuses: const {AdminAudienceReportStatus.open},
    );

    expect(() => filter.copyWith(search: 'alice'), throwsArgumentError);
  });

  test('report criteria make a matching audience actionable', () {
    final audience = AdminAudienceSelection.filter(
      AdminAudienceFilter.reports(
        statuses: const {AdminAudienceReportStatus.open},
        types: const {'abuse'},
        assigneeUserId: '  user-1  ',
      ),
    );

    expect(audience.isActionable, isTrue);
    expect(audience.resource, AdminAudienceResource.reports);
    expect(
      audience.summary,
      'All reports matching status: open; type: abuse; assignee: user-1',
    );
  });

  test('each report criterion makes a matching audience actionable', () {
    final audiences = [
      AdminAudienceSelection.filter(
        AdminAudienceFilter.reports(
          statuses: const {AdminAudienceReportStatus.open},
        ),
      ),
      AdminAudienceSelection.filter(
        AdminAudienceFilter.reports(types: const {'abuse'}),
      ),
      AdminAudienceSelection.filter(
        AdminAudienceFilter.reports(assigneeUserId: 'user-1'),
      ),
      AdminAudienceSelection.filter(
        AdminAudienceFilter.reports(createdAfter: DateTime.utc(2026)),
      ),
    ];

    expect(audiences.every((audience) => audience.isActionable), isTrue);
  });

  test('changing report criteria invalidates an equal frozen audience', () {
    final filter = AdminAudienceFilter.reports(
      statuses: const {AdminAudienceReportStatus.open},
      types: const {'abuse'},
      assigneeUserId: 'user-1',
    );
    final changed = filter.copyWith(
      statuses: const {AdminAudienceReportStatus.resolved},
    );

    expect(changed.statuses, {AdminAudienceReportStatus.resolved});
    expect(changed.types, {'abuse'});
    expect(changed.assigneeUserId, 'user-1');
    expect(changed, isNot(equals(filter)));
    expect(
      AdminAudienceSelection.filter(changed),
      isNot(equals(AdminAudienceSelection.filter(filter))),
    );
  });

  test('report filters reject blank report types', () {
    expect(
      () => AdminAudienceFilter.reports(types: const {'   '}),
      throwsArgumentError,
    );
  });

  test('report filters reject report types longer than 64 characters', () {
    final tooLongType = List.filled(65, 'a').join();

    expect(
      () => AdminAudienceFilter.reports(types: {tooLongType}),
      throwsArgumentError,
    );
  });

  test('report filters reject more than 32 report types', () {
    final tooManyTypes = {
      for (var index = 0; index < 33; index++) 'type-$index',
    };

    expect(
      () => AdminAudienceFilter.reports(types: tooManyTypes),
      throwsArgumentError,
    );
  });

  test('report filters reject more than 32 repeated report types', () {
    final tooManyTypes = List.filled(33, 'abuse');

    expect(
      () => AdminAudienceFilter.reports(types: tooManyTypes),
      throwsArgumentError,
    );
  });

  test('account filters reject report-only copy criteria', () {
    const accountFilter = AdminAudienceFilter(search: 'alice');

    expect(
      () => accountFilter.copyWith(
        statuses: const {AdminAudienceReportStatus.open},
      ),
      throwsArgumentError,
    );
    expect(
      AdminAudienceSelection.filter(accountFilter).summary,
      'All accounts matching “alice”',
    );
  });

  test('report filters freeze normalized status and type state', () {
    final types = {' abuse '};
    final filter = AdminAudienceFilter.reports(
      statuses: const {
        AdminAudienceReportStatus.open,
        AdminAudienceReportStatus.resolved,
        AdminAudienceReportStatus.dismissed,
      },
      types: types,
    );

    types.add('spam');

    expect(filter.statuses, {
      AdminAudienceReportStatus.open,
      AdminAudienceReportStatus.resolved,
      AdminAudienceReportStatus.dismissed,
    });
    expect(filter.types, {'abuse'});
    expect(
      () => filter.statuses.add(AdminAudienceReportStatus.open),
      throwsUnsupportedError,
    );
    expect(() => filter.types.add('spam'), throwsUnsupportedError);
  });

  test('report summaries include date criteria', () {
    final audience = AdminAudienceSelection.filter(
      AdminAudienceFilter.reports(
        createdAfter: DateTime.utc(2026, 1, 2, 3, 4),
        createdBefore: DateTime.utc(2026, 1, 3, 3, 4),
      ),
    );

    expect(
      audience.summary,
      'All reports matching created after: 2026-01-02T03:04:00.000Z; '
      'created before: 2026-01-03T03:04:00.000Z',
    );
  });

  test(
    'selected IDs survive pagination and produce an actionable audience',
    () {
      final selection = AdminAudienceSelectionModel();

      selection.toggleSelected('user-1');
      selection.toggleSelected('user-2');

      expect(selection.selectedIds, {'user-1', 'user-2'});
      expect(
        selection.audience,
        AdminAudienceSelection.selected({'user-1', 'user-2'}),
      );
      expect(selection.audience.isActionable, isTrue);
    },
  );

  test('changing the matching filter invalidates selected IDs', () {
    final selection = AdminAudienceSelectionModel();
    selection.toggleSelected('user-1');

    selection.setFilter(const AdminAudienceFilter(search: 'alice'));

    expect(selection.selectedIds, isEmpty);
    expect(
      selection.audience,
      AdminAudienceSelection.filter(const AdminAudienceFilter(search: 'alice')),
    );
    expect(selection.filterRevision, 1);
  });

  test(
    'all matching is explicit and cannot be confused with an empty selection',
    () {
      final selection = AdminAudienceSelectionModel();

      selection.selectAllMatching();

      expect(selection.audience.kind, AdminAudienceSelectionKind.all);
      expect(selection.audience.isActionable, isTrue);
      expect(selection.audience.summary, 'All eligible accounts');
    },
  );

  test(
    'all matching preserves the visible search filter and account resource',
    () {
      final selection = AdminAudienceSelectionModel();
      selection.setFilter(
        const AdminAudienceFilter(search: 'alice', verifiedEmail: true),
      );

      selection.selectAllMatching();

      expect(selection.audience.kind, AdminAudienceSelectionKind.filter);
      expect(selection.audience.filter?.search, 'alice');
      expect(selection.audience.filter?.verifiedEmail, isTrue);
      expect(selection.audience.resource, AdminAudienceResource.accounts);
    },
  );

  test('an unconstrained matching filter is not actionable', () {
    final selection = AdminAudienceSelectionModel();

    selection.setFilter(const AdminAudienceFilter());
    selection.selectAllMatching();

    expect(selection.audience.kind, AdminAudienceSelectionKind.filter);
    expect(selection.audience.isActionable, isFalse);
  });

  test('clearing selection returns a non-actionable selected audience', () {
    final selection = AdminAudienceSelectionModel();
    selection.toggleSelected('user-1');

    selection.clear();

    expect(selection.audience.kind, AdminAudienceSelectionKind.selected);
    expect(selection.audience.isActionable, isFalse);
  });

  test(
    'preview confirmation requires the exact audience, action, and payload',
    () {
      final audience = AdminAudienceSelection.selected(const {
        'user-1',
      }, resource: AdminAudienceResource.accounts);
      const action = AdminAudienceAction(
        kind: AdminAudienceActionKind.loginLink,
      );
      final preview = AdminAudiencePreview(
        snapshotId: 'snapshot-1',
        accountAudienceCount: 1,
        eligibleRecipientCount: 1,
        excludedCount: 0,
        deviceDeliveryCount: 1,
        expiresAt: DateTime.utc(2026, 1, 1, 1),
        audience: audience,
        action: action,
        payloadHash: 'payload-hash-1',
        resource: AdminAudienceResource.accounts,
      );

      expect(
        preview.canConfirm(
          DateTime.utc(2026, 1, 1),
          audience,
          action,
          'payload-hash-1',
        ),
        isTrue,
      );
      expect(
        preview.canConfirm(
          DateTime.utc(2026, 1, 1),
          AdminAudienceSelection.selected(const {
            'user-1',
          }, resource: AdminAudienceResource.reports),
          action,
          'payload-hash-1',
        ),
        isFalse,
      );
      expect(
        preview.canConfirm(
          DateTime.utc(2026, 1, 1),
          audience,
          const AdminAudienceAction(kind: AdminAudienceActionKind.email),
          'payload-hash-1',
        ),
        isFalse,
      );
      expect(
        preview.canConfirm(
          DateTime.utc(2026, 1, 1),
          audience,
          action,
          'payload-hash-2',
        ),
        isFalse,
      );
    },
  );

  test('ready previews without server binding cannot be confirmed', () {
    final preview = AdminAudiencePreview(
      snapshotId: 'snapshot-1',
      accountAudienceCount: 1,
      eligibleRecipientCount: 1,
      excludedCount: 0,
      deviceDeliveryCount: 1,
      expiresAt: DateTime.utc(2026, 1, 1, 1),
    );

    expect(preview.canConfirm(DateTime.utc(2026, 1, 1)), isFalse);
  });
}
