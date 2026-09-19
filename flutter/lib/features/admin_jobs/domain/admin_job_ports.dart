import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';

abstract interface class AdminJobsRepository {
  Future<AdminJobPage> list(AdminJobQuery query);
  Future<AdminJobCommandResult> retry(String jobId);
  Future<AdminJobCommandResult> cancel(String jobId);
}
