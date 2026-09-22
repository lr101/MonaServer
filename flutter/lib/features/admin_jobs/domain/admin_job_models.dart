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
    this.accountAudienceCount = 0,
    this.eligibleRecipientCount = 0,
    this.excludedAudienceCount = 0,
    this.deviceDeliveryCount = 0,
    this.hasProgressDetails = true,
    this.updatedAt,
  });

  final String id;
  final String actionLabel;
  final AdminJobStatus status;
  final int pendingCount;
  final int completedCount;
  final int failedCount;
  final int unknownDeliveryCount;
  final bool cancellationRequested;

  /// These are the server's audience snapshot counts, not delivery progress.
  final int accountAudienceCount;
  final int eligibleRecipientCount;
  final int excludedAudienceCount;
  final int deviceDeliveryCount;
  final bool hasProgressDetails;
  final DateTime? updatedAt;

  String get statusExplanation => switch (status) {
    AdminJobStatus.pending => 'Waiting to start.',
    AdminJobStatus.running => 'Processing eligible recipients.',
    AdminJobStatus.completed => 'Completed.',
    AdminJobStatus.completedWithErrors =>
      hasProgressDetails
          ? 'Completed with errors: $failedCount recipient${failedCount == 1 ? '' : 's'} failed.'
          : 'Completed with errors. Detailed recipient progress is unavailable.',
    AdminJobStatus.paused =>
      'Paused until an authorized administrator resumes it.',
    AdminJobStatus.cancelled =>
      'Cancelled. Work already accepted by a provider cannot be unsent.',
  };

  String? get deliveryExplanation =>
      !hasProgressDetails || unknownDeliveryCount == 0
      ? null
      : '$unknownDeliveryCount ${unknownDeliveryCount == 1 ? 'delivery has' : 'deliveries have'} unconfirmed provider acceptance. Retrying may duplicate ${unknownDeliveryCount == 1 ? 'it' : 'them'}.';

  String freshnessDescription(DateTime refreshedAt) {
    final timestamp = updatedAt;
    if (timestamp == null) return 'Update time unavailable.';
    final age = refreshedAt.difference(timestamp);
    if (age <= Duration.zero) return 'Updated during this refresh.';
    final minutes = age.inMinutes;
    if (minutes < 1) return 'Updated less than a minute before this refresh.';
    return 'Updated $minutes minute${minutes == 1 ? '' : 's'} before this refresh.';
  }
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

/// A command's key survives an ambiguous transport result for safe replay.
final class AdminJobCommand {
  const AdminJobCommand({required this.jobId, required this.idempotencyKey});

  final String jobId;
  final String idempotencyKey;
}

final class AdminJobsTransportException implements Exception {
  const AdminJobsTransportException(this.statusCode);

  final int statusCode;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin jobs request failed ($statusCode)';
}
