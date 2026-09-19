enum AdminJobStatus {
  pending,
  running,
  completed,
  completedWithErrors,
  paused,
  cancelled,
}

final class AdminJobRecord {
  const AdminJobRecord({
    required this.id,
    required this.actionLabel,
    required this.status,
    required this.pendingCount,
    required this.completedCount,
    required this.failedCount,
    required this.unknownDeliveryCount,
    required this.cancellationRequested,
  });

  final String id;
  final String actionLabel;
  final AdminJobStatus status;
  final int pendingCount;
  final int completedCount;
  final int failedCount;
  final int unknownDeliveryCount;
  final bool cancellationRequested;

  String get statusExplanation => switch (status) {
    AdminJobStatus.pending => 'Waiting to start.',
    AdminJobStatus.running => 'Processing eligible recipients.',
    AdminJobStatus.completed => 'Completed.',
    AdminJobStatus.completedWithErrors =>
      'Completed with errors: $failedCount recipient${failedCount == 1 ? '' : 's'} failed.',
    AdminJobStatus.paused =>
      'Paused until an authorized administrator resumes it.',
    AdminJobStatus.cancelled =>
      'Cancelled. Work already accepted by a provider cannot be unsent.',
  };

  String? get deliveryExplanation => unknownDeliveryCount == 0
      ? null
      : '$unknownDeliveryCount ${unknownDeliveryCount == 1 ? 'delivery is' : 'deliveries are'} uncertain after provider acceptance. Retrying may duplicate ${unknownDeliveryCount == 1 ? 'it' : 'them'}.';
}

final class AdminJobPage {
  const AdminJobPage({required this.items, this.nextCursor});

  final List<AdminJobRecord> items;
  final String? nextCursor;
}

final class AdminJobQuery {
  const AdminJobQuery({this.cursor, this.limit = 25});

  final String? cursor;
  final int limit;
}

final class AdminJobCommandResult {
  const AdminJobCommandResult({required this.jobId});

  final String jobId;
}

final class AdminJobsTransportException implements Exception {
  const AdminJobsTransportException(this.statusCode);

  final int statusCode;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin jobs request failed ($statusCode)';
}
