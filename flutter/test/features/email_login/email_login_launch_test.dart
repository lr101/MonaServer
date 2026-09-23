import 'package:buff_lisa/app/email_link_launch.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initial callback capture scrubs the URL before returning its token',
    () async {
      final port = _FakeLaunchPort(
        'https://consumer.example/#/email-login/callback?token=opaque-token',
      );

      final launch = await captureInitialEmailLink(launchPort: port);

      expect(launch?.hasUsableToken, isTrue);
      expect(launch?.token?.value, 'opaque-token');
      expect(port.scrubCalls, 1);
    },
  );

  test('ordinary hash route is not captured or scrubbed', () async {
    final port = _FakeLaunchPort('https://consumer.example/#/home');

    expect(await captureInitialEmailLink(launchPort: port), isNull);
    expect(port.scrubCalls, 0);
  });

  test(
    'malformed callback is still scrubbed without returning a token',
    () async {
      final port = _FakeLaunchPort(
        'https://consumer.example/#/email-login/callback?token=%ZZ',
      );

      final launch = await captureInitialEmailLink(launchPort: port);

      expect(launch?.status, EmailLinkLaunchStatus.malformed);
      expect(launch?.hasUsableToken, isFalse);
      expect(port.scrubCalls, 1);
    },
  );

  test('unparseable URL with a callback fragment is still scrubbed', () async {
    final port = _FakeLaunchPort(
      'https://[invalid#/email-login/callback?token=opaque-token',
    );

    final launch = await captureInitialEmailLink(launchPort: port);

    expect(launch?.status, EmailLinkLaunchStatus.malformed);
    expect(port.scrubCalls, 1);
  });
}

class _FakeLaunchPort implements EmailLinkLaunchPort {
  _FakeLaunchPort(this.location);

  @override
  final String? location;
  int scrubCalls = 0;

  @override
  Future<bool> scrub() async {
    scrubCalls++;
    return true;
  }
}
