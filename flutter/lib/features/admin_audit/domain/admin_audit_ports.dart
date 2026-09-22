import 'package:buff_lisa/features/admin_audit/domain/admin_audit_models.dart';

abstract interface class AdminAuditRepository {
  Future<AdminAuditPage> listAudit(AdminAuditQuery query);
}
