import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:openapi/api.dart';

/// Admits an exchanged credential through the established consumer session
/// lifecycle. It never writes credentials itself.
class GlobalDataEmailLoginAdmissionAdapter implements EmailLoginAdmissionPort {
  GlobalDataEmailLoginAdmissionAdapter({
    required this.global,
    required this.currentData,
    this.revoker,
  });

  final GlobalDataService global;
  final GlobalDataDto Function() currentData;
  final Future<void> Function(EmailLoginCredentials credentials)? revoker;

  @override
  EmailLoginSessionSnapshot get session {
    final data = currentData();
    return EmailLoginSessionSnapshot(
      userId: data.userId,
      generation: global.generation,
      cleanupRequired: global.cleanupRequired,
    );
  }

  @override
  bool isGenerationCurrent(int expectedGeneration) =>
      global.generation == expectedGeneration;

  @override
  Future<EmailLoginAdmissionResult> admit(
    EmailLinkExchange exchange, {
    required int expectedGeneration,
  }) async {
    if (global.cleanupRequired) {
      return const EmailLoginAdmissionResult.cleanupRequired();
    }
    if (!isGenerationCurrent(expectedGeneration)) {
      return const EmailLoginAdmissionResult.staleGeneration();
    }
    try {
      final accepted = await global.updateData(
        TokenResponseDto(
          accessToken: exchange.credentials.accessToken,
          refreshToken: exchange.credentials.refreshToken,
          userId: exchange.credentials.userId,
        ),
        exchange.canonicalUsername,
        expectedGeneration: expectedGeneration,
      );
      return accepted
          ? const EmailLoginAdmissionResult.accepted()
          : const EmailLoginAdmissionResult.staleGeneration();
    } catch (_) {
      return const EmailLoginAdmissionResult.failed();
    }
  }

  @override
  Future<void> revokeRefreshCredential(
    EmailLoginCredentials credentials,
  ) async {
    try {
      await revoker?.call(credentials);
    } catch (_) {
      // The consumed email-link credential cannot be replayed. Revocation is
      // useful cleanup, but failures must not expose transport details.
    }
  }
}

typedef EmailLoginSessionAdapter = GlobalDataEmailLoginAdmissionAdapter;
