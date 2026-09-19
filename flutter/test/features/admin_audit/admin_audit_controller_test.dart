import 'dart:async';

import 'package:buff_lisa/features/admin_audit/domain/admin_audit_models.dart';
import 'package:buff_lisa/features/admin_audit/domain/admin_audit_ports.dart';
import 'package:buff_lisa/features/admin_audit/presentation/admin_audit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'audit events contain actor target time and outcome without secret values',
    () {
      final event = AdminAuditEvent(
        id: 'event-1',
        actorLabel: 'operator',
        targetLabel: 'account-1',
        actionLabel: 'Compromise account',
        outcome: AdminAuditOutcome.secured,
        occurredAt: DateTime.utc(2026, 9, 19, 12),
      );

      expect(event.summary, 'operator secured account-1');
      expect(event.toString(), isNot(contains('token')));
      expect(event.toString(), isNot(contains('password')));
    },
  );

  test('loads the next audit page with the returned cursor', () async {
    final repository = _AuditRepository();
    final controller = AdminAuditController(repository);

    await controller.load();
    await controller.loadNextPage();

    expect(repository.queries.map((query) => query.cursor), [null, 'next']);
    expect(controller.state.events, hasLength(2));
  });

  test(
    'session expiry ignores a late audit response and stops more reads',
    () async {
      final page = Completer<AdminAuditPage>();
      final repository = _AuditRepository(firstPage: page.future);
      final controller = AdminAuditController(repository);

      final load = controller.load();
      controller.expireSession();
      page.complete(AdminAuditPage(items: [_event('event-1')]));
      await load;
      await controller.load();

      expect(controller.state.events, isEmpty);
      expect(repository.queries, hasLength(1));
    },
  );
}

final class _AuditRepository implements AdminAuditRepository {
  _AuditRepository({this._firstPage});

  final Future<AdminAuditPage>? _firstPage;
  final List<AdminAuditQuery> queries = [];

  @override
  Future<AdminAuditPage> list(AdminAuditQuery query) {
    queries.add(query);
    if (queries.length == 1 && _firstPage != null) return _firstPage;
    return Future.value(
      AdminAuditPage(
        items: [_event('event-${queries.length}')],
        nextCursor: queries.length == 1 ? 'next' : null,
      ),
    );
  }
}

AdminAuditEvent _event(String id) => AdminAuditEvent(
  id: id,
  actorLabel: 'operator',
  targetLabel: 'account',
  actionLabel: 'Revoke sessions',
  outcome: AdminAuditOutcome.completed,
  occurredAt: DateTime.utc(2026, 9, 19, 12),
);
