import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes a valid email without provider-specific rewriting', () {
    final email = EmailAddress.tryParse('  Alice.Example+tag@Example.COM ');

    expect(email, isNotNull);
    expect(email!.value, 'alice.example+tag@example.com');
  });

  test(
    'request use case returns generic accepted outcome for a valid address',
    () async {
      final port = _FakeRequestPort();
      final useCase = RequestEmailLink(port);

      final result = await useCase('person@example.com');

      expect(result.status, EmailLinkRequestStatus.accepted);
      expect(result.email!.value, 'person@example.com');
      expect(port.requested, ['person@example.com']);
    },
  );

  test(
    'invalid email is rejected locally and never reaches the request port',
    () async {
      final port = _FakeRequestPort();

      final result = await RequestEmailLink(port)('not-an-email');

      expect(result.status, EmailLinkRequestStatus.invalidEmail);
      expect(port.requested, isEmpty);
    },
  );

  test(
    'request transport failures become a generic unavailable result',
    () async {
      final port = _FakeRequestPort()..failure = StateError('transport');

      final result = await RequestEmailLink(port)('person@example.com');

      expect(result.status, EmailLinkRequestStatus.unavailable);
    },
  );

  test('exchange preserves invalid, expired and used outcomes', () async {
    final token = EmailLinkToken.tryParse('opaque-token')!;
    for (final expected in [
      EmailLinkExchangeStatus.invalid,
      EmailLinkExchangeStatus.expired,
      EmailLinkExchangeStatus.used,
    ]) {
      final port = _FakeExchangePort()
        ..result = switch (expected) {
          EmailLinkExchangeStatus.invalid =>
            const EmailLinkExchangeResult.invalid(),
          EmailLinkExchangeStatus.expired =>
            const EmailLinkExchangeResult.expired(),
          EmailLinkExchangeStatus.used => const EmailLinkExchangeResult.used(),
          _ => throw StateError('unexpected test status'),
        };

      final result = await ExchangeEmailLink(port)(token);

      expect(result.status, expected);
      expect(port.tokens, [token]);
    }
  });

  test('exchange transport failures do not expose transport errors', () async {
    final port = _FakeExchangePort()..failure = StateError('secret transport');

    final result = await ExchangeEmailLink(port)(
      EmailLinkToken.tryParse('opaque-token')!,
    );

    expect(result.status, EmailLinkExchangeStatus.unavailable);
    expect(result.toString(), isNot(contains('secret transport')));
  });

  test(
    'admission rejects a stale generation before writing credentials',
    () async {
      final port = _FakeAdmissionPort(
        session: const EmailLoginSessionSnapshot(
          userId: null,
          generation: 4,
          cleanupRequired: false,
        ),
      )..generationCurrent = false;

      final result = await AdmitEmailLogin(port)(
        _exchange,
        expectedGeneration: 4,
      );

      expect(result.status, EmailLoginAdmissionStatus.staleGeneration);
      expect(port.admitted, isEmpty);
    },
  );

  test(
    'admission refuses cleanup-required sessions before writing credentials',
    () async {
      final port = _FakeAdmissionPort(
        session: const EmailLoginSessionSnapshot(
          userId: 'existing-user',
          generation: 4,
          cleanupRequired: true,
        ),
      );

      final result = await AdmitEmailLogin(port)(
        _exchange,
        expectedGeneration: 4,
      );

      expect(result.status, EmailLoginAdmissionStatus.cleanupRequired);
      expect(port.admitted, isEmpty);
    },
  );

  test(
    'admission forwards the canonical identity and captured generation',
    () async {
      final port = _FakeAdmissionPort(
        session: const EmailLoginSessionSnapshot(
          userId: 'existing-user',
          generation: 4,
          cleanupRequired: false,
        ),
      );

      final result = await AdmitEmailLogin(port)(
        _exchange,
        expectedGeneration: 4,
      );

      expect(result.status, EmailLoginAdmissionStatus.accepted);
      expect(port.admitted.single.exchange, _exchange);
      expect(port.admitted.single.expectedGeneration, 4);
    },
  );

  test('recovery validates input and maps typed server outcomes', () async {
    final port = _FakeRecoveryPort()
      ..result = const RecoveryCompletionResult.expiredToken();
    final useCase = CompleteEmailRecovery(port);

    final invalidPassword = await useCase(
      RecoveryToken.tryParse('recovery-token'),
      '',
    );
    final expired = await useCase(
      RecoveryToken.tryParse('recovery-token'),
      'a valid replacement password',
    );

    expect(invalidPassword.status, RecoveryCompletionStatus.invalidPassword);
    expect(expired.status, RecoveryCompletionStatus.expiredToken);
    expect(port.completed, hasLength(1));
  });

  test(
    'opaque tokens, credentials and passwords redact their string forms',
    () {
      const rawToken = 'raw-login-token';
      const rawRefresh = 'raw-refresh-token';
      const rawAccess = 'raw-access-token';
      const rawPassword = 'raw-recovery-password';
      final token = EmailLinkToken.tryParse(rawToken)!;
      const credentials = EmailLoginCredentials(
        accessToken: rawAccess,
        refreshToken: rawRefresh,
        userId: 'user-1',
      );
      const exchange = EmailLinkExchange(
        credentials: credentials,
        canonicalUsername: 'alice',
      );
      final password = RecoveryPassword.tryParse(rawPassword)!;

      expect(token.toString(), isNot(contains(rawToken)));
      expect(credentials.toString(), isNot(contains(rawAccess)));
      expect(credentials.toString(), isNot(contains(rawRefresh)));
      expect(exchange.toString(), isNot(contains(rawAccess)));
      expect(password.toString(), isNot(contains(rawPassword)));
    },
  );
}

const _exchange = EmailLinkExchange(
  credentials: EmailLoginCredentials(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    userId: 'new-user',
  ),
  canonicalUsername: 'new-user-name',
);

class _FakeRequestPort implements EmailLinkRequestPort {
  final requested = <String>[];
  Object? failure;

  @override
  Future<void> requestLoginLink(EmailAddress email) async {
    if (failure != null) throw failure!;
    requested.add(email.value);
  }
}

class _FakeExchangePort implements EmailLinkExchangePort {
  final tokens = <EmailLinkToken>[];
  EmailLinkExchangeResult result = const EmailLinkExchangeResult.unavailable();
  Object? failure;

  @override
  Future<EmailLinkExchangeResult> exchange(EmailLinkToken token) async {
    tokens.add(token);
    if (failure != null) throw failure!;
    return result;
  }
}

class _FakeAdmissionPort implements EmailLoginAdmissionPort {
  _FakeAdmissionPort({required this.session});

  @override
  EmailLoginSessionSnapshot session;
  bool generationCurrent = true;
  final admitted = <({EmailLinkExchange exchange, int expectedGeneration})>[];

  @override
  bool isGenerationCurrent(int expectedGeneration) =>
      generationCurrent && session.generation == expectedGeneration;

  @override
  Future<EmailLoginAdmissionResult> admit(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  }) async {
    admitted.add((exchange: exchange, expectedGeneration: expectedGeneration));
    return const EmailLoginAdmissionResult.accepted();
  }

  @override
  Future<void> revokeRefreshCredential(String refreshToken) async {}
}

class _FakeRecoveryPort implements EmailRecoveryPort {
  final completed = <({RecoveryToken token, RecoveryPassword password})>[];
  RecoveryCompletionResult result = const RecoveryCompletionResult.completed();

  @override
  Future<RecoveryCompletionResult> complete(
    RecoveryToken token,
    RecoveryPassword password,
  ) async {
    completed.add((token: token, password: password));
    return result;
  }
}
