import 'package:flutter/widgets.dart';

import '../../features/admin_users/domain/admin_user_ports.dart';
import '../../features/admin_session/domain/admin_session_ports.dart';
import '../../features/admin_session/presentation/admin_session_controller.dart';
import 'admin_api_adapter.dart';
import 'admin_app.dart';

/// Builds only the admin composition root. The API adapter is disposed with
/// the app, and no consumer startup work is reachable from this function.
Widget createAdminApplication({
  String? apiHost,
  AdminSessionTransport? sessionTransport,
  AdminUsersRepository? usersRepository,
  bool autoRestore = true,
  VoidCallback? onDispose,
}) {
  if ((sessionTransport == null) != (usersRepository == null)) {
    throw ArgumentError(
      'Admin session and users dependencies must be supplied together.',
    );
  }
  final suppliedSessionTransport = sessionTransport;
  final suppliedUsersRepository = usersRepository;
  AdminApiAdapter? adapter;
  if (suppliedSessionTransport == null) {
    adapter = AdminApiAdapter(
      basePath:
          apiHost ??
          const String.fromEnvironment(
            'API_HOST',
            defaultValue: 'https://stick-it.lr-projects.de',
          ),
    );
  }
  final resolvedSessionTransport = suppliedSessionTransport ?? adapter!;
  final resolvedUsersRepository = suppliedUsersRepository ?? adapter!;
  return AdminApp(
    sessionController: AdminSessionController(resolvedSessionTransport),
    usersRepository: resolvedUsersRepository,
    autoRestore: autoRestore,
    onDispose: onDispose ?? adapter?.close,
  );
}
