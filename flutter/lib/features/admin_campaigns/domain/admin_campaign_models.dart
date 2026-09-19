import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';

enum AdminCampaignKind { email, push, loginLink }

/// The editable, non-secret content for one administrative communication.
final class AdminCampaignDraft {
  const AdminCampaignDraft._({
    required this.kind,
    this.subject,
    this.title,
    this.body,
  });

  const AdminCampaignDraft.email({
    required String subject,
    required String body,
  }) : this._(kind: AdminCampaignKind.email, subject: subject, body: body);

  const AdminCampaignDraft.push({required String title, required String body})
    : this._(kind: AdminCampaignKind.push, title: title, body: body);

  const AdminCampaignDraft.loginLink()
    : this._(kind: AdminCampaignKind.loginLink);

  final AdminCampaignKind kind;
  final String? subject;
  final String? title;
  final String? body;

  bool get isValid {
    final hasSubject = subject?.trim().isNotEmpty == true;
    final hasTitle = title?.trim().isNotEmpty == true;
    final hasBody = body?.trim().isNotEmpty == true;
    return switch (kind) {
      AdminCampaignKind.email => hasSubject && hasBody,
      AdminCampaignKind.push => hasTitle && hasBody,
      AdminCampaignKind.loginLink => true,
    };
  }

  AdminAudienceAction get action => switch (kind) {
    AdminCampaignKind.email => AdminAudienceAction(
      kind: AdminAudienceActionKind.email,
      subject: subject?.trim(),
      body: body?.trim(),
    ),
    AdminCampaignKind.push => AdminAudienceAction(
      kind: AdminAudienceActionKind.push,
      title: title?.trim(),
      body: body?.trim(),
    ),
    AdminCampaignKind.loginLink => const AdminAudienceAction(
      kind: AdminAudienceActionKind.loginLink,
    ),
  };
}

enum AdminCampaignTestDelivery { idle, accepted, unavailable, failed }

final class AdminCampaignTestResult {
  const AdminCampaignTestResult._(this.delivery);

  const AdminCampaignTestResult.accepted()
    : this._(AdminCampaignTestDelivery.accepted);

  const AdminCampaignTestResult.unavailable()
    : this._(AdminCampaignTestDelivery.unavailable);

  const AdminCampaignTestResult.failed()
    : this._(AdminCampaignTestDelivery.failed);

  final AdminCampaignTestDelivery delivery;
}

final class AdminCampaignCommitResult {
  const AdminCampaignCommitResult({required this.jobId});

  final String jobId;
}

/// Retains the exact backend commit and key for an uncertain retry.
final class AdminCampaignCommitCommand {
  const AdminCampaignCommitCommand({
    required this.commit,
    required this.idempotencyKey,
  });

  final AdminAudienceCommitRequest commit;
  final String idempotencyKey;
}

final class AdminCampaignTransportException implements Exception {
  const AdminCampaignTransportException(this.statusCode);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'Admin campaign request failed ($statusCode)';
}
