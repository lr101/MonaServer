import 'package:flutter/widgets.dart';

import '../../features/admin_session/domain/admin_session_controller.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import 'admin_api_adapter.dart';
import 'admin_app.dart';

/// Builds only the admin composition root. The API adapter is disposed with
/// the app, and no consumer startup work is reachable from this function.
Widget createAdminApplication({String? apiHost}) {
  final adapter = AdminApiAdapter(
    basePath:
        apiHost ??
        const String.fromEnvironment(
          'API_HOST',
          defaultValue: 'https://stick-it.lr-projects.de',
        ),
  );
  return AdminApp(
    sessionController: AdminSessionController(adapter),
    usersRepository: adapter,
    onDispose: adapter.close,
  );
}

// Kept as a named entry-point helper so tests and alternate hosts can create
// the admin app without touching the consumer bootstrap.
AdminUsersRepository createAdminUsersRepository(AdminApiAdapter adapter) =>
    adapter;
