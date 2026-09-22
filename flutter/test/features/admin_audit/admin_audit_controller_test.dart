import 'dart:async';

import 'package:buff_lisa/features/admin_audit/domain/admin_audit_models.dart';
import 'package:buff_lisa/features/admin_audit/domain/admin_audit_ports.dart';
import 'package:buff_lisa/features/admin_audit/presentation/admin_audit_controller.dart';
import 'package:buff_lisa/features/admin_audit/presentation/admin_audit_screen.dart';
import 'package:flutter/material.dart';
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
    'maps provider delivery outcomes and unknown values to safe display',
    () {
      expect(
        AdminAuditOutcome.fromWire('provider_accepted'),
        AdminAuditOutcome.providerAccepted,
      );
      expect(
        AdminAuditOutcome.fromWire('unknown_delivery'),
        AdminAuditOutcome.unknownDelivery,
      );
      expect(
        AdminAuditOutcome.fromWire('future_outcome'),
        AdminAuditOutcome.unknown,
      );

      final unknownDelivery = _event(
        'delivery-1',
        outcome: AdminAuditOutcome.unknownDelivery,
      );
      final unknown = _event('unknown-1', outcome: AdminAuditOutcome.unknown);
      expect(
        unknownDelivery.summary,
        'operator recorded unconfirmed delivery for account',
      );
      expect(
        unknown.summary,
        'operator recorded an unknown outcome for account',
      );
    },
  );

  testWidgets('renders provider and forward-compatible audit outcomes', (
    tester,
  ) async {
    final controller = AdminAuditController(
      _AuditRepository(
        firstPage: AdminAuditPage(
          items: [
            _event('accepted', outcome: AdminAuditOutcome.providerAccepted),
            _event('delivery', outcome: AdminAuditOutcome.unknownDelivery),
            _event('unknown', outcome: AdminAuditOutcome.unknown),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminAuditScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('operator recorded provider acceptance for account'),
      findsOneWidget,
    );
    expect(
      find.text('operator recorded unconfirmed delivery for account'),
      findsOneWidget,
    );
    expect(
      find.text('operator recorded an unknown outcome for account'),
      findsOneWidget,
    );
  });

  test(
    'session expiry ignores a late audit response and stops more reads',
    () async {
      final page = Completer<AdminAuditPage>();
      final repository = _AuditRepository(pendingFirstPage: page.future);
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
  _AuditRepository({this.pendingFirstPage, this.firstPage});

  final Future<AdminAuditPage>? pendingFirstPage;
  final AdminAuditPage? firstPage;
  final List<AdminAuditQuery> queries = [];

  @override
  Future<AdminAuditPage> listAudit(AdminAuditQuery query) {
    queries.add(query);
    if (queries.length == 1 && pendingFirstPage != null) {
      return pendingFirstPage!;
    }
    if (queries.length == 1 && firstPage != null)
      return Future.value(firstPage);
    return Future.value(
      AdminAuditPage(
        items: [_event('event-${queries.length}')],
        nextCursor: queries.length == 1 ? 'next' : null,
      ),
    );
  }
}

AdminAuditEvent _event(
  String id, {
  AdminAuditOutcome outcome = AdminAuditOutcome.completed,
}) => AdminAuditEvent(
  id: id,
  actorLabel: 'operator',
  targetLabel: 'account',
  actionLabel: 'Revoke sessions',
  outcome: outcome,
  occurredAt: DateTime.utc(2026, 9, 19, 12),
);
