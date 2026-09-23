import 'package:buff_lisa/features/email_login/data/email_login_launch_adapter.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_use_cases.dart';

export 'package:buff_lisa/features/email_login/domain/email_login_models.dart'
    show EmailLinkLaunchData;

/// Captures a login callback before normal startup and removes its browser
/// fragment before a router or history entry can retain an opaque token.
Future<EmailLinkLaunchData?> captureInitialEmailLink({
  EmailLinkLaunchPort? launchPort,
}) async {
  final port = launchPort ?? createEmailLinkLaunchPort();
  if (!EmailLinkLaunchParser.isCallbackLocation(port.location)) return null;
  try {
    return await CaptureEmailLinkLaunch(port)();
  } catch (_) {
    return const EmailLinkLaunchData.scrubFailed();
  }
}
