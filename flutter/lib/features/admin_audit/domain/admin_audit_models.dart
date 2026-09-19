enum AdminAuditOutcome {
  completed,
  secured,
  queued,
  skipped,
  failed,
  cancelled,
  providerAccepted,
  unknownDelivery,
  unknown;

  static AdminAuditOutcome fromWire(String value) => switch (value) {
    'completed' => AdminAuditOutcome.completed,
    'secured' => AdminAuditOutcome.secured,
    'queued' => AdminAuditOutcome.queued,
    'skipped' => AdminAuditOutcome.skipped,
    'failed' => AdminAuditOutcome.failed,
    'cancelled' => AdminAuditOutcome.cancelled,
    'provider_accepted' => AdminAuditOutcome.providerAccepted,
    'unknown_delivery' => AdminAuditOutcome.unknownDelivery,
    _ => AdminAuditOutcome.unknown,
  };
}

/// A safe, displayable audit event. Secret-bearing values and provider payloads
/// have no representation in this model by design.
final class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.actorLabel,
    required this.targetLabel,
    required this.actionLabel,
    required this.outcome,
    required this.occurredAt,
  });

  final String id;
  final String actorLabel;
  final String targetLabel;
  final String actionLabel;
  final AdminAuditOutcome outcome;
  final DateTime occurredAt;

  String get summary =>
      '$actorLabel ${switch (outcome) {
        AdminAuditOutcome.completed => 'completed',
        AdminAuditOutcome.secured => 'secured',
        AdminAuditOutcome.queued => 'queued work for',
        AdminAuditOutcome.skipped => 'skipped',
        AdminAuditOutcome.failed => 'failed to process',
        AdminAuditOutcome.cancelled => 'cancelled work for',
        AdminAuditOutcome.providerAccepted => 'recorded provider acceptance for',
        AdminAuditOutcome.unknownDelivery => 'recorded unconfirmed delivery for',
        AdminAuditOutcome.unknown => 'recorded an unknown outcome for',
      }} $targetLabel';

  @override
  String toString() =>
      'AdminAuditEvent(id: $id, actor: $actorLabel, target: $targetLabel, action: $actionLabel, outcome: $outcome, occurredAt: $occurredAt)';
}

final class AdminAuditQuery {
  const AdminAuditQuery({
    this.cursor,
    this.targetUserId,
    this.action,
    this.limit = 25,
  });

  final String? cursor;
  final String? targetUserId;
  final String? action;
  final int limit;
}

final class AdminAuditPage {
  const AdminAuditPage({required this.items, this.nextCursor});

  final List<AdminAuditEvent> items;
  final String? nextCursor;
}

final class AdminAuditTransportException implements Exception {
  const AdminAuditTransportException(this.statusCode);

  final int statusCode;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin audit request failed ($statusCode)';
}
