import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';

/// Native builds do not receive browser email-link callbacks.
class NativeEmailLinkLaunchPort implements EmailLinkLaunchPort {
  const NativeEmailLinkLaunchPort();

  @override
  String? get location => null;

  @override
  Future<bool> scrub() async => true;
}

EmailLinkLaunchPort createEmailLinkLaunchPort() =>
    const NativeEmailLinkLaunchPort();
