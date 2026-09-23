import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';

/// Sends a public email-link request. The port intentionally has no account
/// lookup result: the server's accepted response is generic for all addresses.
abstract interface class EmailLinkRequestPort {
  Future<void> requestLoginLink(EmailAddress email);
}

/// Exchanges an opaque token only after the user explicitly presses the
/// callback confirmation action. Opening a link never calls this port.
abstract interface class EmailLinkExchangePort {
  Future<EmailLinkExchangeResult> exchange(EmailLinkToken token);
}

/// One-shot browser launch access used before the normal router/bootstrap.
///
/// The web adapter owns the platform-specific location API and must remove the
/// fragment from browser history/address state. The domain only receives the
/// location and a success bit; it never logs or renders the raw value.
abstract interface class EmailLinkLaunchPort {
  String? get location;

  Future<bool> scrub();
}

/// Admits an exchanged session into the existing consumer session.
///
/// The eventual production adapter must delegate to
/// `GlobalDataService.updateData` with the authoritative canonical username
/// and `expectedGeneration`. That preserves same-account drafts, waits for
/// different-account cleanup and keeps failed credential writes recoverable.
/// It must not write credentials directly. Synchronization remains owned by
/// `AppSyncLifecycle` after admission.
abstract interface class EmailLoginAdmissionPort {
  EmailLoginSessionSnapshot get session;

  bool isGenerationCurrent(int expectedGeneration);

  Future<EmailLoginAdmissionResult> admit(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  });

  /// Best-effort revocation for an exchanged refresh credential that cannot be
  /// admitted, for example after a declined account switch or stale response.
  Future<void> revokeRefreshCredential(String refreshToken);
}

/// Completes restricted recovery without creating a normal access token.
abstract interface class EmailRecoveryPort {
  Future<RecoveryCompletionResult> complete(
    RecoveryToken token,
    RecoveryPassword password,
  );
}
