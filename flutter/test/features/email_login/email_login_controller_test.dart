import 'dart:async';

import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_use_cases.dart';
import 'package:buff_lisa/features/email_login/presentation/email_login_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the single-fragment callback and rejects a second fragment', () {
    final captured = EmailLinkLaunchParser.parse(
      'https://consumer.example/#/email-login/callback?token=opaque-token',
    );
    final malformed = EmailLinkLaunchParser.parse(
      'https://consumer.example/#/email-login/callback?token=opaque-token#token',
    );

    expect(captured.status, EmailLinkLaunchStatus.captured);
    expect(captured.token!.value, 'opaque-token');
    expect(malformed.status, EmailLinkLaunchStatus.malformed);
    expect(captured.toString(), isNot(contains('opaque-token')));
  });

  test(
    'capture reports scrub failure without returning a usable token',
    () async {
      final launchPort = _FakeLaunchPort(
        'https://consumer.example/#/email-login/callback?token=opaque-token',
      )..scrubResult = false;

      final result = await CaptureEmailLinkLaunch(launchPort)();

      expect(launchPort.scrubCalls, 1);
      expect(result.status, EmailLinkLaunchStatus.scrubFailed);
      expect(result.hasUsableToken, isFalse);
    },
  );

  test(
    'launch capture is one-shot and does not scrub or expose a second token',
    () async {
      final launchPort = _FakeLaunchPort(
        'https://consumer.example/#/email-login/callback?token=opaque-token',
      );
      final capture = CaptureEmailLinkLaunch(launchPort);

      final first = await capture();
      final second = await capture();

      expect(first.status, EmailLinkLaunchStatus.captured);
      expect(second.status, EmailLinkLaunchStatus.malformed);
      expect(second.hasUsableToken, isFalse);
      expect(launchPort.scrubCalls, 1);
    },
  );

  test('control characters in callback tokens make the launch malformed', () {
    final result = EmailLinkLaunchParser.parse(
      'https://consumer.example/#/email-login/callback?token=opaque%0Atoken',
    );

    expect(result.status, EmailLinkLaunchStatus.malformed);
  });

  test(
    'request controller coalesces duplicate submissions while pending',
    () async {
      final requestPort = _FakeRequestPort()..pending = Completer<void>();
      final controller = EmailLinkRequestController(requestPort);

      final first = controller.request(' person@example.com ');
      final second = controller.request('person@example.com');

      expect(requestPort.calls, 1);
      expect(identical(first, second), isTrue);
      requestPort.pending!.complete();

      expect((await first).status, EmailLinkRequestViewStatus.sent);
      expect(controller.state.status, EmailLinkRequestViewStatus.sent);
    },
  );

  test('callback remains confirmation-only until the user submits', () async {
    final exchangePort = _FakeExchangePort()
      ..result = const EmailLinkExchangeResult.success(_exchange);
    final controller = EmailLoginController(
      exchangePort: exchangePort,
      admissionPort: _FakeAdmissionPort(_signedOutSession),
    );
    controller.setLaunchData(
      EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
    );

    expect(controller.state.status, EmailLoginViewStatus.awaitingConfirmation);
    expect(exchangePort.calls, 0);

    final result = await controller.confirmSignIn();

    expect(exchangePort.calls, 1);
    expect(result.status, EmailLoginViewStatus.signedIn);
  });

  test('duplicate callback confirmation sends one exchange request', () async {
    final exchangePort = _FakeExchangePort()..pending = Completer();
    final controller = EmailLoginController(
      exchangePort: exchangePort,
      admissionPort: _FakeAdmissionPort(_signedOutSession),
    );
    controller.setLaunchData(
      EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
    );

    final first = controller.confirmSignIn();
    final second = controller.confirmSignIn();

    expect(exchangePort.calls, 1);
    expect(identical(first, second), isTrue);
    exchangePort.pending!.complete(
      const EmailLinkExchangeResult.success(_exchange),
    );

    expect((await first).status, EmailLoginViewStatus.signedIn);
  });

  test(
    'callback preserves typed invalid, expired and reused outcomes',
    () async {
      for (final fixture
          in <({EmailLinkExchangeResult result, EmailLoginViewStatus status})>[
            (
              result: const EmailLinkExchangeResult.invalid(),
              status: EmailLoginViewStatus.invalidLink,
            ),
            (
              result: const EmailLinkExchangeResult.expired(),
              status: EmailLoginViewStatus.expiredLink,
            ),
            (
              result: const EmailLinkExchangeResult.reused(),
              status: EmailLoginViewStatus.usedLink,
            ),
          ]) {
        final exchangePort = _FakeExchangePort()..result = fixture.result;
        final controller = EmailLoginController(
          exchangePort: exchangePort,
          admissionPort: _FakeAdmissionPort(_signedOutSession),
        );
        controller.setLaunchData(
          EmailLinkLaunchData.captured(
            EmailLinkToken.tryParse('opaque-token')!,
          ),
        );

        final result = await controller.confirmSignIn();

        expect(result.status, fixture.status);
      }
    },
  );

  test(
    'different-account exchange waits for confirmation before admission',
    () async {
      final exchangePort = _FakeExchangePort()
        ..result = const EmailLinkExchangeResult.success(_exchange);
      final admissionPort = _FakeAdmissionPort(_signedInSession);
      final controller = EmailLoginController(
        exchangePort: exchangePort,
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
      );

      final pendingSwitch = await controller.confirmSignIn();

      expect(
        pendingSwitch.status,
        EmailLoginViewStatus.awaitingAccountSwitchConfirmation,
      );
      expect(admissionPort.admissions, isEmpty);

      final declined = await controller.declineAccountSwitch();

      expect(declined.status, EmailLoginViewStatus.accountSwitchDeclined);
      expect(admissionPort.revokedRefreshTokens, ['refresh-token']);
      expect(admissionPort.session.userId, 'existing-user');
    },
  );

  test(
    'confirmed account switch admits with the captured generation',
    () async {
      final admissionPort = _FakeAdmissionPort(_signedInSession);
      final controller = EmailLoginController(
        exchangePort: _FakeExchangePort()
          ..result = const EmailLinkExchangeResult.success(_exchange),
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
      );

      await controller.confirmSignIn();
      final result = await controller.confirmAccountSwitch();

      expect(result.status, EmailLoginViewStatus.signedIn);
      expect(admissionPort.admissions.single.expectedGeneration, 12);
      expect(admissionPort.admissions.single.exchange, _exchange);
    },
  );

  test(
    'generation change while exchanging revokes credentials and fences state',
    () async {
      final exchangePort = _FakeExchangePort()..pending = Completer();
      final admissionPort = _FakeAdmissionPort(_signedOutSession);
      final controller = EmailLoginController(
        exchangePort: exchangePort,
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
      );

      final pending = controller.confirmSignIn();
      admissionPort.session = const EmailLoginSessionSnapshot(
        userId: null,
        generation: 13,
        cleanupRequired: false,
      );
      exchangePort.pending!.complete(
        const EmailLinkExchangeResult.success(_exchange),
      );

      final result = await pending;

      expect(result.status, EmailLoginViewStatus.staleGeneration);
      expect(controller.state.status, EmailLoginViewStatus.staleGeneration);
      expect(admissionPort.admissions, isEmpty);
      expect(admissionPort.revokedRefreshTokens, ['refresh-token']);
    },
  );

  test(
    'delayed stale-response revocation cannot clear a newer launch',
    () async {
      final exchangePort = _FakeExchangePort()
        ..result = const EmailLinkExchangeResult.success(_exchange);
      final admissionPort = _FakeAdmissionPort(_signedOutSession)
        ..revokeStarted = Completer<void>()
        ..pendingRevocation = Completer<void>();
      final controller = EmailLoginController(
        exchangePort: exchangePort,
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-one')!),
      );

      final pending = controller.confirmSignIn();
      admissionPort.session = const EmailLoginSessionSnapshot(
        userId: null,
        generation: 13,
        cleanupRequired: false,
      );
      await admissionPort.revokeStarted!.future;

      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-two')!),
      );
      admissionPort.pendingRevocation!.complete();

      expect((await pending).status, EmailLoginViewStatus.awaitingConfirmation);
      expect(
        controller.state.status,
        EmailLoginViewStatus.awaitingConfirmation,
      );

      final next = await controller.confirmSignIn();

      expect(next.status, EmailLoginViewStatus.signedIn);
      expect(exchangePort.tokens.map((token) => token.value), [
        'token-one',
        'token-two',
      ]);
    },
  );

  test(
    'failed admission revokes credentials without overwriting a newer launch',
    () async {
      final exchangePort = _FakeExchangePort()
        ..result = const EmailLinkExchangeResult.success(_exchange);
      final admissionPort = _FakeAdmissionPort(_signedOutSession)
        ..admissionResult = const EmailLoginAdmissionResult.failed()
        ..revokeStarted = Completer<void>()
        ..pendingRevocation = Completer<void>();
      final controller = EmailLoginController(
        exchangePort: exchangePort,
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-one')!),
      );

      final pending = controller.confirmSignIn();
      await admissionPort.revokeStarted!.future;

      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-two')!),
      );
      admissionPort.pendingRevocation!.complete();

      expect((await pending).status, EmailLoginViewStatus.awaitingConfirmation);
      expect(
        controller.state.status,
        EmailLoginViewStatus.awaitingConfirmation,
      );
      expect(admissionPort.revokedRefreshTokens, ['refresh-token']);

      admissionPort.admissionResult =
          const EmailLoginAdmissionResult.accepted();
      expect(
        (await controller.confirmSignIn()).status,
        EmailLoginViewStatus.signedIn,
      );
    },
  );

  test('decline revocation cannot overwrite a newer launch', () async {
    final exchangePort = _FakeExchangePort()
      ..result = const EmailLinkExchangeResult.success(_exchange);
    final admissionPort = _FakeAdmissionPort(_signedInSession)
      ..revokeStarted = Completer<void>()
      ..pendingRevocation = Completer<void>();
    final controller = EmailLoginController(
      exchangePort: exchangePort,
      admissionPort: admissionPort,
    );
    controller.setLaunchData(
      EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-one')!),
    );
    await controller.confirmSignIn();

    final declined = controller.declineAccountSwitch();
    await admissionPort.revokeStarted!.future;

    controller.setLaunchData(
      EmailLinkLaunchData.captured(EmailLinkToken.tryParse('token-two')!),
    );
    admissionPort.pendingRevocation!.complete();

    expect((await declined).status, EmailLoginViewStatus.awaitingConfirmation);
    expect(controller.state.status, EmailLoginViewStatus.awaitingConfirmation);
    expect(
      (await controller.confirmSignIn()).status,
      EmailLoginViewStatus.awaitingAccountSwitchConfirmation,
    );
    expect(exchangePort.tokens.map((token) => token.value), [
      'token-one',
      'token-two',
    ]);
  });

  test(
    'duplicate account-switch admission shares one pending submission',
    () async {
      final admissionPort = _FakeAdmissionPort(_signedInSession)
        ..pendingAdmission = Completer<EmailLoginAdmissionResult>();
      final controller = EmailLoginController(
        exchangePort: _FakeExchangePort()
          ..result = const EmailLinkExchangeResult.success(_exchange),
        admissionPort: admissionPort,
      );
      controller.setLaunchData(
        EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
      );
      await controller.confirmSignIn();

      final first = controller.confirmAccountSwitch();
      final second = controller.confirmAccountSwitch();

      expect(admissionPort.admissions, hasLength(1));
      expect(identical(first, second), isTrue);
      admissionPort.pendingAdmission!.complete(
        const EmailLoginAdmissionResult.accepted(),
      );

      expect((await first).status, EmailLoginViewStatus.signedIn);
    },
  );

  test('late exchange after cancellation cannot write state', () async {
    final exchangePort = _FakeExchangePort()..pending = Completer();
    final admissionPort = _FakeAdmissionPort(_signedOutSession);
    final controller = EmailLoginController(
      exchangePort: exchangePort,
      admissionPort: admissionPort,
    );
    controller.setLaunchData(
      EmailLinkLaunchData.captured(EmailLinkToken.tryParse('opaque-token')!),
    );

    final pending = controller.confirmSignIn();
    await controller.cancel();
    exchangePort.pending!.complete(
      const EmailLinkExchangeResult.success(_exchange),
    );

    await pending;
    expect(controller.state.status, EmailLoginViewStatus.idle);
    expect(admissionPort.admissions, isEmpty);
    expect(admissionPort.revokedRefreshTokens, ['refresh-token']);
  });

  test(
    'recovery controller keeps token private and maps typed outcomes',
    () async {
      final recoveryPort = _FakeRecoveryPort();
      final controller = EmailRecoveryController(recoveryPort);
      controller.setToken('raw-recovery-token');

      final result = await controller.submit('a valid replacement password');

      expect(result.status, EmailRecoveryViewStatus.completed);
      expect(
        controller.state.toString(),
        isNot(contains('raw-recovery-token')),
      );
      expect(recoveryPort.tokens.single.value, 'raw-recovery-token');

      recoveryPort.result = const RecoveryCompletionResult.expiredToken();
      controller.setToken('another-token');
      expect(
        (await controller.submit('another valid password')).status,
        EmailRecoveryViewStatus.expiredToken,
      );
    },
  );

  test('duplicate recovery submission shares one pending request', () async {
    final recoveryPort = _FakeRecoveryPort()..pending = Completer();
    final controller = EmailRecoveryController(recoveryPort);
    controller.setToken('raw-recovery-token');

    final first = controller.submit('a valid replacement password');
    final second = controller.submit('a valid replacement password');

    expect(recoveryPort.calls, 1);
    expect(identical(first, second), isTrue);
    recoveryPort.pending!.complete(const RecoveryCompletionResult.completed());

    expect((await first).status, EmailRecoveryViewStatus.completed);
  });
}

const _signedOutSession = EmailLoginSessionSnapshot(
  userId: null,
  generation: 12,
  cleanupRequired: false,
);

const _signedInSession = EmailLoginSessionSnapshot(
  userId: 'existing-user',
  generation: 12,
  cleanupRequired: false,
);

const _exchange = EmailLinkExchange(
  credentials: EmailLoginCredentials(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    userId: 'new-user',
  ),
  canonicalUsername: 'new-user-name',
);

class _FakeLaunchPort implements EmailLinkLaunchPort {
  _FakeLaunchPort(this.location);

  @override
  final String location;
  bool scrubResult = true;
  int scrubCalls = 0;

  @override
  Future<bool> scrub() async {
    scrubCalls++;
    return scrubResult;
  }
}

class _FakeRequestPort implements EmailLinkRequestPort {
  int calls = 0;
  Completer<void>? pending;

  @override
  Future<void> requestLoginLink(EmailAddress email) async {
    calls++;
    if (pending != null) await pending!.future;
  }
}

class _FakeExchangePort implements EmailLinkExchangePort {
  int calls = 0;
  final tokens = <EmailLinkToken>[];
  Completer<EmailLinkExchangeResult>? pending;
  EmailLinkExchangeResult result = const EmailLinkExchangeResult.unavailable();

  @override
  Future<EmailLinkExchangeResult> exchange(EmailLinkToken token) async {
    calls++;
    tokens.add(token);
    if (pending != null) return pending!.future;
    return result;
  }
}

class _FakeAdmissionPort implements EmailLoginAdmissionPort {
  _FakeAdmissionPort(this.session);

  @override
  EmailLoginSessionSnapshot session;
  final admissions = <({EmailLinkExchange exchange, int expectedGeneration})>[];
  final revokedRefreshTokens = <String>[];
  EmailLoginAdmissionResult admissionResult =
      const EmailLoginAdmissionResult.accepted();
  Completer<EmailLoginAdmissionResult>? pendingAdmission;
  Completer<void>? revokeStarted;
  Completer<void>? pendingRevocation;

  @override
  bool isGenerationCurrent(int expectedGeneration) =>
      session.generation == expectedGeneration;

  @override
  Future<EmailLoginAdmissionResult> admit(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  }) async {
    admissions.add((
      exchange: exchange,
      expectedGeneration: expectedGeneration,
    ));
    if (pendingAdmission != null) return pendingAdmission!.future;
    return admissionResult;
  }

  @override
  Future<void> revokeRefreshCredential(String refreshToken) async {
    revokedRefreshTokens.add(refreshToken);
    if (revokeStarted != null && !revokeStarted!.isCompleted) {
      revokeStarted!.complete();
    }
    if (pendingRevocation != null) await pendingRevocation!.future;
  }
}

class _FakeRecoveryPort implements EmailRecoveryPort {
  int calls = 0;
  final tokens = <RecoveryToken>[];
  Completer<RecoveryCompletionResult>? pending;
  RecoveryCompletionResult result = const RecoveryCompletionResult.completed();

  @override
  Future<RecoveryCompletionResult> complete(
    RecoveryToken token,
    RecoveryPassword password,
  ) async {
    calls++;
    tokens.add(token);
    if (pending != null) return pending!.future;
    return result;
  }
}
