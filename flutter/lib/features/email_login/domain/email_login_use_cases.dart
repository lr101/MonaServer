import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';

final class RequestEmailLink {
  RequestEmailLink(this._port);

  final EmailLinkRequestPort _port;

  Future<EmailLinkRequestResult> call(
    String? rawIdentifier, {
    bool asUsername = false,
  }) async {
    final identifier = EmailLoginIdentifier.tryParse(
      rawIdentifier,
      asUsername: asUsername,
    );
    if (identifier == null) return const EmailLinkRequestResult.invalidEmail();
    try {
      await _port.requestLoginLink(identifier);
      return EmailLinkRequestResult.accepted(identifier);
    } on EmailLoginFeatureUnavailableException {
      return const EmailLinkRequestResult.featureUnavailable();
    } catch (_) {
      return const EmailLinkRequestResult.unavailable();
    }
  }
}

final class ExchangeEmailLink {
  ExchangeEmailLink(this._port);

  final EmailLinkExchangePort _port;

  Future<EmailLinkExchangeResult> call(EmailLinkToken token) async {
    try {
      final result = await _port.exchange(token);
      if (result.status == EmailLinkExchangeStatus.success &&
          result.exchange == null) {
        return const EmailLinkExchangeResult.unavailable();
      }
      return result;
    } catch (_) {
      return const EmailLinkExchangeResult.unavailable();
    }
  }
}

/// Captures and scrubs launch data without redeeming it. Redemption is owned
/// by the callback controller after an explicit user confirmation.
final class CaptureEmailLinkLaunch {
  CaptureEmailLinkLaunch(this._port);

  final EmailLinkLaunchPort _port;
  bool _called = false;

  Future<EmailLinkLaunchData> call() async {
    if (_called) return const EmailLinkLaunchData.malformed();
    _called = true;
    final parsed = EmailLinkLaunchParser.parse(_port.location);
    bool scrubbed;
    try {
      scrubbed = await _port.scrub();
    } catch (_) {
      scrubbed = false;
    }
    if (!scrubbed) return const EmailLinkLaunchData.scrubFailed();
    return parsed;
  }
}

final class AdmitEmailLogin {
  AdmitEmailLogin(this._port);

  final EmailLoginAdmissionPort _port;

  Future<EmailLoginAdmissionResult> call(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  }) async {
    try {
      if (!_port.isGenerationCurrent(expectedGeneration) ||
          _port.session.generation != expectedGeneration) {
        return const EmailLoginAdmissionResult.staleGeneration();
      }
      if (_port.session.cleanupRequired) {
        return const EmailLoginAdmissionResult.cleanupRequired();
      }
      return await _port.admit(
        exchange,
        expectedGeneration: expectedGeneration,
      );
    } catch (_) {
      return const EmailLoginAdmissionResult.failed();
    }
  }
}

final class RevokeEmailLoginCredential {
  RevokeEmailLoginCredential(this._port);

  final EmailLoginAdmissionPort _port;

  Future<void> call(EmailLoginCredentials credentials) async {
    try {
      await _port.revokeRefreshCredential(credentials);
    } catch (_) {
      // Revocation is intentionally best effort. The consumed link cannot be
      // replayed, and no transport detail belongs in UI state or diagnostics.
    }
  }
}

final class CompleteEmailRecovery {
  CompleteEmailRecovery(this._port);

  final EmailRecoveryPort _port;

  Future<RecoveryCompletionResult> call(
    RecoveryToken? token,
    String? rawPassword,
  ) async {
    final password = RecoveryPassword.tryParse(rawPassword);
    if (token == null) {
      return const RecoveryCompletionResult.invalidToken();
    }
    if (password == null) {
      return const RecoveryCompletionResult.invalidPassword();
    }
    try {
      return await _port.complete(token, password);
    } catch (_) {
      return const RecoveryCompletionResult.unavailable();
    }
  }
}
