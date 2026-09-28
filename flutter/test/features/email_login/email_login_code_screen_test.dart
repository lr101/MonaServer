import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/presentation/email_login_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'accepted email request hands its identifier to code navigation',
    (tester) async {
      EmailLoginIdentifier? requestedIdentifier;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailLinkRequestScreen(
            requestPort: _FakeRequestPort(),
            onCodeEntry: (identifier) => requestedIdentifier = identifier,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('email-login-email')),
        'person@example.com',
      );
      await tester.tap(find.byKey(const Key('email-login-request')));
      await tester.pumpAndSettle();

      expect(requestedIdentifier?.value, 'person@example.com');
    },
  );

  testWidgets('code page submits its code and admits the returned session', (
    tester,
  ) async {
    final exchange = _FakeCodeExchangePort();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailLoginCodeScreen(
          identifier: EmailLoginIdentifier.tryParse('person@example.com')!,
          codeExchangePort: exchange,
          admissionPort: _FakeAdmissionPort(),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('email-login-code')), 'a2b4c6');
    await tester.tap(find.byKey(const Key('email-login-code-submit')));
    await tester.pumpAndSettle();

    expect(exchange.identifier?.value, 'person@example.com');
    expect(exchange.code?.value, 'A2B4C6');
    expect(find.text('Signed in successfully.'), findsOneWidget);
  });
}

class _FakeRequestPort implements EmailLinkRequestPort {
  @override
  Future<void> requestLoginLink(EmailLoginIdentifier identifier) async {}
}

class _FakeCodeExchangePort implements EmailLoginCodeExchangePort {
  EmailLoginIdentifier? identifier;
  EmailLoginCode? code;

  @override
  Future<EmailLinkExchangeResult> exchangeCode(
    EmailLoginIdentifier identifier,
    EmailLoginCode code,
  ) async {
    this.identifier = identifier;
    this.code = code;
    return const EmailLinkExchangeResult.success(
      EmailLinkExchange(
        credentials: EmailLoginCredentials(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          userId: 'user-id',
        ),
        canonicalUsername: 'person',
      ),
    );
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
