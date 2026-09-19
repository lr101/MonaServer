import 'package:buff_lisa/features/admin_security/domain/admin_security_models.dart';

abstract interface class AdminSecurityRepository {
  Future<AdminSecurityResult> submit(AdminSecurityActionRequest request);
}
