import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/email_login/data/email_login_api_adapter.dart';
import 'package:buff_lisa/features/email_login/data/email_login_launch_adapter.dart';
import 'package:buff_lisa/features/email_login/data/email_login_session_adapter.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_ports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

/// Filled by composition before normal routing begins. A scrubbed reload has
/// no callback token to replay.
final emailLinkLaunchDataProvider = Provider<EmailLinkLaunchData?>(
  (ref) => null,
);

final emailLinkLaunchPortProvider = Provider<EmailLinkLaunchPort>(
  (ref) => createEmailLinkLaunchPort(),
);

final publicAuthEmailLoginAdapterProvider =
    Provider<PublicAuthEmailLoginAdapter>((ref) {
      return PublicAuthEmailLoginAdapter(ref.watch(publicAuthApiProvider));
    });

final emailLinkRequestPortProvider = Provider<EmailLinkRequestPort>(
  (ref) => ref.watch(publicAuthEmailLoginAdapterProvider),
);

final emailLinkExchangePortProvider = Provider<EmailLinkExchangePort>(
  (ref) => ref.watch(publicAuthEmailLoginAdapterProvider),
);

final emailRecoveryPortProvider = Provider<EmailRecoveryPort>(
  (ref) => ref.watch(publicAuthEmailLoginAdapterProvider),
);

final emailLoginAdmissionPortProvider = Provider<EmailLoginAdmissionPort>((
  ref,
) {
  final global = ref.read(globalDataServiceProvider.notifier);
  return GlobalDataEmailLoginAdmissionAdapter(
    global: global,
    currentData: () => ref.read(globalDataServiceProvider),
    revoker: (credentials) async {
      final auth = HttpBearerAuth()..accessToken = credentials.accessToken;
      final client = ApiClient(
        basePath: ref.read(globalDataServiceProvider).host,
        authentication: auth,
      );
      try {
        await SessionAuthApi(client).revokeOwnSession(
          SessionRevokeRequestDto(refreshToken: credentials.refreshToken),
        );
      } finally {
        client.client.close();
      }
    },
  );
});
