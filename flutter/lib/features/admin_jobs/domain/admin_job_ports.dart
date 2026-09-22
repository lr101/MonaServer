import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';

abstract interface class AdminJobsRepository {
  Future<AdminJobPage> listJobs(AdminJobQuery query);
  Future<AdminJobCommandResult> retry(AdminJobCommand command);
  Future<AdminJobCommandResult> cancel(AdminJobCommand command);
}
