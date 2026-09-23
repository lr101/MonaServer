import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:openapi/api.dart';

/// Converts the generated public-auth client into the bounded email-login
/// ports. Generated DTOs and transport details do not escape this boundary.
class PublicAuthEmailLoginAdapter
    implements EmailLinkRequestPort, EmailLinkExchangePort, EmailRecoveryPort {
  PublicAuthEmailLoginAdapter(this._api);

  final PublicAuthApi _api;

  @override
  Future<void> requestLoginLink(EmailAddress email) async {
    final response = await _api.requestEmailLink(
      EmailLinkRequestDto(email: email.value),
    );
    if (response?.accepted != true) {
      throw StateError('email-link request was not accepted');
    }
  }

  @override
  Future<EmailLinkExchangeResult> exchange(EmailLinkToken token) async {
    try {
      final response = await _api.exchangeEmailLink(
        EmailLinkExchangeRequestDto(token: token.value),
      );
      if (response == null ||
          !_hasUsableCredentials(response.tokens) ||
          response.username.trim().isEmpty) {
        return const EmailLinkExchangeResult.unavailable();
      }
      return EmailLinkExchangeResult.success(
        EmailLinkExchange(
          credentials: EmailLoginCredentials(
            accessToken: response.tokens.accessToken,
            refreshToken: response.tokens.refreshToken,
            userId: response.tokens.userId,
          ),
          canonicalUsername: response.username,
        ),
      );
    } on ApiException catch (error) {
      return switch (error.code) {
        400 => const EmailLinkExchangeResult.invalid(),
        _ => const EmailLinkExchangeResult.unavailable(),
      };
    } catch (_) {
      return const EmailLinkExchangeResult.unavailable();
    }
  }

  @override
  Future<RecoveryCompletionResult> complete(
    RecoveryToken token,
    RecoveryPassword password,
  ) async {
    try {
      await _api.completeRecovery(
        RecoveryCompleteRequestDto(
          token: token.value,
          password: password.value,
        ),
      );
      return const RecoveryCompletionResult.completed();
    } on ApiException catch (error) {
      return switch (error.code) {
        400 => const RecoveryCompletionResult.invalidToken(),
        409 => const RecoveryCompletionResult.usedToken(),
        _ => const RecoveryCompletionResult.unavailable(),
      };
    } catch (_) {
      return const RecoveryCompletionResult.unavailable();
    }
  }

  static bool _hasUsableCredentials(TokenResponseDto credentials) =>
      credentials.accessToken.isNotEmpty &&
      credentials.refreshToken.isNotEmpty &&
      credentials.userId.isNotEmpty;
}

typedef EmailLoginApiAdapter = PublicAuthEmailLoginAdapter;
