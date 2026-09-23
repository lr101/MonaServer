import 'package:openapi/api.dart' as openapi;

/// Maps the consumer issue form into the additive report contract while
/// retaining the existing text fields used by older servers and mail paths.
final class ReportIssueSubmission {
  const ReportIssueSubmission({
    required this.reporterUserId,
    required this.issueType,
    required this.message,
    this.userId,
    this.groupId,
    this.pinId,
  });

  final String reporterUserId;
  final String? userId;
  final String? groupId;
  final String? pinId;
  final String issueType;
  final String message;

  ReportIssueRequest toRequest() {
    final userTarget = _nonBlank(userId);
    final pinTarget = _nonBlank(pinId);
    return ReportIssueRequest(
      userId: reporterUserId,
      report:
          'userId: ${userId ?? 'null'}, groupId: ${groupId ?? 'null'}, pinId: ${pinId ?? 'null'}, issueType: $issueType',
      message: message,
      targetId: userTarget ?? pinTarget,
      // A missing kind retains compatibility for user targets. Pin targets
      // require their explicit kind; group context stays in legacy text.
      targetKind: userTarget == null && pinTarget != null ? 'pin' : null,
    );
  }

  /// Creates the generated wire DTO at the adapter boundary. The reporter ID
  /// remains the legacy compatibility field; the server still derives the
  /// authenticated reporter rather than trusting it as identity.
  openapi.ReportDto toReportDto() {
    final request = toRequest();
    return openapi.ReportDto(
      userId: request.userId,
      report: request.report,
      message: request.message,
      targetId: request.targetId,
      targetKind: request.targetKind,
    );
  }

  String? _nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final class ReportIssueRequest {
  const ReportIssueRequest({
    required this.userId,
    required this.report,
    required this.message,
    this.targetId,
    this.targetKind,
  });

  final String userId;
  final String report;
  final String message;
  final String? targetId;
  final String? targetKind;
}
