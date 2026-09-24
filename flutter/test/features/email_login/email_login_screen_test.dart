import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/presentation/email_login_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('callback waits for an explicit confirmation before exchange', (
    tester,
  ) async {
    final exchange = _FakeExchangePort();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailLoginCallbackScreen(
          launch: EmailLinkLaunchData.captured(
            EmailLinkToken.tryParse('opaque-token')!,
          ),
          exchangePort: exchange,
          admissionPort: _FakeAdmissionPort(),
        ),
      ),
    );

    expect(exchange.calls, 0);
    await tester.tap(find.byKey(const Key('email-login-confirm')));
    await tester.pumpAndSettle();
    expect(exchange.calls, 1);
    expect(find.text('Signed in successfully.'), findsOneWidget);
  });

  testWidgets(
    'request screen keeps delivery result generic and supports resend',
    (tester) async {
      final request = _FakeRequestPort();
      await tester.pumpWidget(
        MaterialApp(home: EmailLinkRequestScreen(requestPort: request)),
      );

      await tester.enterText(
        find.byKey(const Key('email-login-email')),
        'person@example.com',
      );
      await tester.tap(find.byKey(const Key('email-login-request')));
      await tester.pumpAndSettle();

      expect(
        find.text('If an account is eligible, a sign-in link is on its way.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('email-login-resend')));
      await tester.pumpAndSettle();
      expect(request.calls, 2);
    },
  );

  for (final status in [
    EmailLinkExchangeStatus.expired,
    EmailLinkExchangeStatus.used,
    EmailLinkExchangeStatus.unavailable,
  ]) {
    testWidgets('callback renders $status without revealing its token', (
      tester,
    ) async {
      final exchange = _FakeExchangePort()..result = _resultFor(status);
      await tester.pumpWidget(
        MaterialApp(
          home: EmailLoginCallbackScreen(
            launch: EmailLinkLaunchData.captured(
              EmailLinkToken.tryParse('raw-opaque-token')!,
            ),
            exchangePort: exchange,
            admissionPort: _FakeAdmissionPort(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('email-login-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('email-login-request-new')), findsOneWidget);
      expect(find.textContaining('raw-opaque-token'), findsNothing);
    });
  }
}

EmailLinkExchangeResult _resultFor(EmailLinkExchangeStatus status) =>
    switch (status) {
      EmailLinkExchangeStatus.expired =>
        const EmailLinkExchangeResult.expired(),
      EmailLinkExchangeStatus.used => const EmailLinkExchangeResult.used(),
      EmailLinkExchangeStatus.unavailable =>
        const EmailLinkExchangeResult.unavailable(),
      _ => throw ArgumentError.value(status),
    };

class _FakeRequestPort implements EmailLinkRequestPort {
  int calls = 0;

  @override
  Future<void> requestLoginLink(EmailLoginIdentifier email) async => calls++;
}

class _FakeExchangePort implements EmailLinkExchangePort {
  int calls = 0;
  EmailLinkExchangeResult result = const EmailLinkExchangeResult.success(
    EmailLinkExchange(
      credentials: EmailLoginCredentials(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-id',
      ),
      canonicalUsername: 'person',
    ),
  );

  @override
  Future<EmailLinkExchangeResult> exchange(EmailLinkToken token) async {
    calls++;
    return result;
  }
}

class _FakeAdmissionPort implements EmailLoginAdmissionPort {
  @override
  EmailLoginSessionSnapshot get session => const EmailLoginSessionSnapshot(
    userId: null,
    generation: 0,
    cleanupRequired: false,
  );

  @override
  bool isGenerationCurrent(int expectedGeneration) => true;

  @override
  Future<EmailLoginAdmissionResult> admit(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  }) async => const EmailLoginAdmissionResult.accepted();

  @override
  Future<void> revokeRefreshCredential(
    EmailLoginCredentials credentials,
  ) async {}
}
