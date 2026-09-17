import 'admin_user_models.dart';

abstract interface class AdminUsersRepository {
  Future<AdminUserPage> listUsers(AdminUserQuery query);

  Future<AdminUserDetails?> getUser(String userId);
}
