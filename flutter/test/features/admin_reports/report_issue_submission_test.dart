import 'package:buff_lisa/widgets/report_issue/report_issue_submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a structured user target while retaining legacy context text', () {
    final request = const ReportIssueSubmission(
      reporterUserId: 'current-user',
      userId: 'target-user',
      groupId: 'group-1',
      pinId: 'pin-1',
      issueType: 'Impersonation',
      message: 'Details',
    ).toRequest();

    expect(request.targetId, 'target-user');
    expect(request.targetKind, isNull);
    expect(
      request.report,
      'userId: target-user, groupId: group-1, pinId: pin-1, issueType: Impersonation',
    );
    expect(request.userId, 'current-user');
  });

  test('uses a pin target and omits unavailable structured fields', () {
    final pin = const ReportIssueSubmission(
      reporterUserId: 'current-user',
      pinId: 'pin-1',
      issueType: 'Abuse',
      message: 'Details',
    ).toRequest();
    final legacy = const ReportIssueSubmission(
      reporterUserId: 'current-user',
      groupId: 'group-1',
      issueType: 'Abuse',
      message: 'Details',
    ).toRequest();

    expect(pin.targetId, 'pin-1');
    expect(pin.targetKind, 'pin');
    expect(legacy.targetId, isNull);
    expect(legacy.targetKind, isNull);
    expect(legacy.report, contains('groupId: group-1'));
  });

  test('maps the additive fields into the generated report DTO', () {
    final dto = const ReportIssueSubmission(
      reporterUserId: 'current-user',
      userId: 'target-user',
      issueType: 'Impersonation',
      message: 'Details',
    ).toReportDto();

    expect(dto.userId, 'current-user');
    expect(dto.targetId, 'target-user');
    expect(dto.targetKind, isNull);
    expect(dto.report, contains('issueType: Impersonation'));
    expect(dto.message, 'Details');
  });
}
