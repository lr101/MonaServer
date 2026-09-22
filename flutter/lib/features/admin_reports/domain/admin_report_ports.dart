import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';

/// Feature-owned boundary. T10/T13 can map generated API types behind this
/// interface without exposing them to report presentation.
abstract interface class AdminReportsRepository
    implements AdminAudiencePreviewPort {
  Future<AdminReportPage> listReports(AdminReportQuery query);

  Future<AdminReport?> get(String reportId);

  Future<AdminReport> update(AdminReportUpdate update);

  Future<AdminReportNote> addNote(String reportId, String text);

  Future<AdminReportBulkOutcome> commitBulk(AdminReportBulkCommand command);
}
