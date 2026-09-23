import 'package:buff_lisa/core/session/session_status.dart';

/// Expiry asks for reauthentication; destructive cleanup is an explicit flow.
String? sessionRedirect({
  required SessionStatus status,
  required bool cleanupRequired,
  required String location,
}) {
  if (cleanupRequired && location != '/logout') return '/logout';
  if (status != SessionStatus.signedIn &&
      !{
        '/login',
        '/web',
        '/logout',
        '/email-login',
        '/email-login/callback',
      }.contains(location)) {
    return '/login';
  }
  if (status == SessionStatus.signedIn && location == '/login') return '/home';
  return null;
}
