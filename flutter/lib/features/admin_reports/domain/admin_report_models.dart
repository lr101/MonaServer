import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';

enum AdminReportStatus { open, resolved, dismissed }

final class AdminReportsTransportException implements Exception {
  const AdminReportsTransportException(this.statusCode);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => 'Admin reports request failed ($statusCode)';
}

final class AdminReportTarget {
  const AdminReportTarget({
    required this.userId,
    required this.username,
    required this.deleted,
  });

  final String? userId;
  final String? username;
  final bool deleted;

  /// A text-only description that remains safe when a related account no
  /// longer exists. It intentionally never tries to navigate to a target.
  String get displayText {
    if (deleted) return 'Deleted or unavailable target';
    final name = username?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = userId?.trim();
    return id == null || id.isEmpty ? 'No related target' : 'Target $id';
  }
}

final class AdminReportNote {
  const AdminReportNote({
    required this.id,
    required this.actorUserId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String actorUserId;
  final String text;
  final DateTime createdAt;
}

final class AdminReport {
  AdminReport({
    required this.id,
    required this.text,
    required this.reporterUserId,
    required this.reporterUsername,
    required this.target,
    required this.status,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.assigneeUserId,
    this.legacyMessage,
    List<AdminReportNote> notes = const [],
  }) : notes = List.unmodifiable(notes);

  final String id;
  final String text;
  final String reporterUserId;
  final String? reporterUsername;
  final AdminReportTarget target;
  final AdminReportStatus status;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assigneeUserId;
  final String? legacyMessage;
  final List<AdminReportNote> notes;

  AdminReport copyWith({
    String? text,
    String? reporterUsername,
    AdminReportTarget? target,
    AdminReportStatus? status,
    int? revision,
    DateTime? updatedAt,
    String? assigneeUserId,
    bool clearAssigneeUserId = false,
    String? legacyMessage,
    bool clearLegacyMessage = false,
    List<AdminReportNote>? notes,
  }) => AdminReport(
    id: id,
    text: text ?? this.text,
    reporterUserId: reporterUserId,
    reporterUsername: reporterUsername ?? this.reporterUsername,
    target: target ?? this.target,
    status: status ?? this.status,
    revision: revision ?? this.revision,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    assigneeUserId: clearAssigneeUserId
        ? null
        : assigneeUserId ?? this.assigneeUserId,
    legacyMessage: clearLegacyMessage
        ? null
        : legacyMessage ?? this.legacyMessage,
    notes: notes ?? this.notes,
  );
}

final class AdminReportPage {
  AdminReportPage({required List<AdminReport> items, this.nextCursor})
    : items = List.unmodifiable(items);

  final List<AdminReport> items;
  final String? nextCursor;
}

final class AdminReportQuery {
  const AdminReportQuery({
    this.search = '',
    this.status,
    this.cursor,
    this.limit = 25,
  });

  final String search;
  final AdminReportStatus? status;
  final String? cursor;
  final int limit;

  AdminAudienceFilter get audienceFilter => AdminAudienceFilter.reports(
    statuses: status == null ? const {} : {status!.toAudienceStatus},
  );

  AdminReportQuery copyWith({
    String? search,
    AdminReportStatus? status,
    bool clearStatus = false,
    String? cursor,
    bool clearCursor = false,
    int? limit,
  }) => AdminReportQuery(
    search: search ?? this.search,
    status: clearStatus ? null : status ?? this.status,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    limit: limit ?? this.limit,
  );
}

final class AdminReportUpdate {
  const AdminReportUpdate({
    required this.reportId,
    required this.expectedRevision,
    required this.status,
    this.assigneeUserId,
    this.clearAssignee = false,
    this.note,
  });

  final String reportId;
  final int expectedRevision;
  final AdminReportStatus status;
  final String? assigneeUserId;
  final bool clearAssignee;
  final String? note;
}

final class AdminReportBulkCommand {
  const AdminReportBulkCommand({required this.commit, required this.status});

  final AdminAudienceCommitRequest commit;
  final AdminReportStatus status;
}

final class AdminReportBulkOutcome {
  const AdminReportBulkOutcome({required this.changed, required this.skipped});

  final int changed;
  final int skipped;
}

extension on AdminReportStatus {
  AdminAudienceReportStatus get toAudienceStatus {
    switch (this) {
      case AdminReportStatus.open:
        return AdminAudienceReportStatus.open;
      case AdminReportStatus.resolved:
        return AdminAudienceReportStatus.resolved;
      case AdminReportStatus.dismissed:
        return AdminAudienceReportStatus.dismissed;
    }
  }
}
