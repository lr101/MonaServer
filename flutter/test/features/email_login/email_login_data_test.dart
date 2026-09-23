import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/email_login/data/email_login_api_adapter.dart';
import 'package:buff_lisa/features/email_login/data/email_login_providers.dart';
import 'package:buff_lisa/features/email_login/data/email_login_session_adapter.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'request adapter sends canonical email and accepts the generic result',
    () async {
      final api = _FakePublicAuthApi();
      final adapter = PublicAuthEmailLoginAdapter(api);

      await adapter.requestLoginLink(
        EmailAddress.tryParse(' Person@Example.com ')!,
      );

      expect(api.requestedEmail, 'person@example.com');
    },
  );

  test(
    'request adapter rejects a response that is not generically accepted',
    () async {
      final api = _FakePublicAuthApi()
        ..requestResult = EmailLinkRequestAcceptedDto(accepted: false);

      await expectLater(
        PublicAuthEmailLoginAdapter(api)
            .requestLoginLink(EmailAddress.tryParse('person@example.com')!),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'exchange adapter maps the generated credentials and username',
    () async {
      final api = _FakePublicAuthApi()..exchangeResult = _exchangeResponse();

      final result = await PublicAuthEmailLoginAdapter(api)
          .exchange(EmailLinkToken.tryParse('opaque-token')!);

      expect(result.status, EmailLinkExchangeStatus.success);
      expect(result.exchange!.canonicalUsername, 'canonical-name');
      expect(result.exchange!.credentials.userId, 'user-id');
      expect(api.exchangedToken, 'opaque-token');
    },
  );

  test(
    'exchange adapter rejects incomplete credentials without exposing them',
    () async {
      final api = _FakePublicAuthApi()
        ..exchangeResult = EmailLinkExchangeResponseDto(
          tokens: TokenResponseDto(
            accessToken: '',
            refreshToken: 'refresh-token',
            userId: 'user-id',
          ),
          username: 'canonical-name',
        );

      final result = await PublicAuthEmailLoginAdapter(api)
          .exchange(EmailLinkToken.tryParse('opaque-token')!);

      expect(result.status, EmailLinkExchangeStatus.unavailable);
      expect(result.toString(), isNot(contains('refresh-token')));
    },
  );

  test('exchange adapter maps public errors to bounded outcomes', () async {
    final api = _FakePublicAuthApi()
      ..exchangeError = ApiException(400, 'raw exchange detail');
    final adapter = PublicAuthEmailLoginAdapter(api);

    expect(
      (await adapter.exchange(EmailLinkToken.tryParse('opaque-token')!)).status,
      EmailLinkExchangeStatus.invalid,
    );
    api.exchangeError = ApiException(503, 'raw provider detail');
    final unavailable = await adapter.exchange(
      EmailLinkToken.tryParse('opaque-token')!,
    );
    expect(unavailable.status, EmailLinkExchangeStatus.unavailable);
    expect(unavailable.toString(), isNot(contains('raw provider detail')));
  });

  test(
    'recovery adapter maps the restricted request and bounded errors',
    () async {
      final api = _FakePublicAuthApi();
      final adapter = PublicAuthEmailLoginAdapter(api);
      final token = RecoveryToken.tryParse('recovery-token')!;
      final password = RecoveryPassword.tryParse('new password')!;

      expect(
        (await adapter.complete(token, password)).status,
        RecoveryCompletionStatus.completed,
      );
      expect(api.recoveryToken, 'recovery-token');
      expect(api.recoveryPassword, 'new password');

      api.recoveryError = ApiException(400, 'raw recovery detail');
      expect(
        (await adapter.complete(token, password)).status,
        RecoveryCompletionStatus.invalidToken,
      );
      api.recoveryError = ApiException(409, 'already consumed');
      expect(
        (await adapter.complete(token, password)).status,
        RecoveryCompletionStatus.usedToken,
      );
      api.recoveryError = ApiException(503, 'provider detail');
      final unavailable = await adapter.complete(token, password);
      expect(unavailable.status, RecoveryCompletionStatus.unavailable);
      expect(unavailable.toString(), isNot(contains('provider detail')));
    },
  );

  test(
    'session adapter admits the exchanged credentials at its generation',
    () async {
      final global = _FakeGlobalDataService(currentGeneration: 7);
      final adapter = GlobalDataEmailLoginAdmissionAdapter(
        global: global,
        currentData: _signedOutData,
      );

      final result = await adapter.admit(_exchange, expectedGeneration: 7);

      expect(result.status, EmailLoginAdmissionStatus.accepted);
      expect(global.updatedUsername, 'canonical-name');
      expect(global.updatedToken!.accessToken, 'access-token');
      expect(global.expectedGeneration, 7);
    },
  );

  test(
    'session adapter fences stale generations before writing credentials',
    () async {
      final global = _FakeGlobalDataService(currentGeneration: 8);
      final adapter = GlobalDataEmailLoginAdmissionAdapter(
        global: global,
        currentData: _signedOutData,
      );

      final result = await adapter.admit(_exchange, expectedGeneration: 7);

      expect(result.status, EmailLoginAdmissionStatus.staleGeneration);
      expect(global.updatedToken, isNull);
    },
  );

  test('session adapter makes failed revocation best effort', () async {
    String? submitted;
    final adapter = GlobalDataEmailLoginAdmissionAdapter(
      global: _FakeGlobalDataService(currentGeneration: 0),
      currentData: _signedOutData,
      revoker: (refreshToken) {
        submitted = refreshToken;
        return Future<void>.error(ApiException(503, 'revocation failed'));
      },
    );

    await adapter.revokeRefreshCredential('refresh-token');

    expect(submitted, 'refresh-token');
  });

  test('admission provider resolves the session API when revoking', () async {
    final first = _FakeSessionAuthApi();
    final second = _FakeSessionAuthApi();
    var current = first;
    final container = ProviderContainer(
      overrides: [
        globalDataServiceProvider.overrideWith(_ProviderGlobalDataService.new),
        sessionAuthApiProvider.overrideWith((ref) => current),
      ],
    );
    addTearDown(container.dispose);
    final port = container.read(emailLoginAdmissionPortProvider);

    current = second;
    container.invalidate(sessionAuthApiProvider);
    await port.revokeRefreshCredential('refresh-token');

    expect(first.revokedRefreshTokens, isEmpty);
    expect(second.revokedRefreshTokens, ['refresh-token']);
  });
}

EmailLinkExchangeResponseDto _exchangeResponse() =>
    EmailLinkExchangeResponseDto(
      tokens: TokenResponseDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-id',
      ),
      username: 'canonical-name',
    );

const _exchange = EmailLinkExchange(
  credentials: EmailLoginCredentials(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    userId: 'user-id',
  ),
  canonicalUsername: 'canonical-name',
);

GlobalDataDto _signedOutData() =>
    const GlobalDataDto(userId: null, refreshToken: null, cameras: []);

class _FakePublicAuthApi extends PublicAuthApi {
  _FakePublicAuthApi() : super(ApiClient(basePath: 'https://api.example'));

  String? requestedEmail;
  EmailLinkRequestAcceptedDto? requestResult = EmailLinkRequestAcceptedDto(
    accepted: true,
  );
  Object? exchangeError;
  EmailLinkExchangeResponseDto? exchangeResult;
  String? exchangedToken;
  Object? recoveryError;
  String? recoveryToken;
  String? recoveryPassword;

  @override
  Future<EmailLinkRequestAcceptedDto?> requestEmailLink(
    EmailLinkRequestDto request,
  ) async {
    requestedEmail = request.email;
    return requestResult;
  }

  @override
  Future<EmailLinkExchangeResponseDto?> exchangeEmailLink(
    EmailLinkExchangeRequestDto request,
  ) async {
    if (exchangeError != null) throw exchangeError!;
    exchangedToken = request.token;
    return exchangeResult;
  }

  @override
  Future<void> completeRecovery(RecoveryCompleteRequestDto request) async {
    if (recoveryError != null) throw recoveryError!;
    recoveryToken = request.token;
    recoveryPassword = request.password;
  }
}

class _FakeGlobalDataService extends GlobalDataService {
  _FakeGlobalDataService({required this.currentGeneration});

  int currentGeneration;
  TokenResponseDto? updatedToken;
  String? updatedUsername;
  int? expectedGeneration;

  @override
  int get generation => currentGeneration;

  @override
  bool get cleanupRequired => false;

  @override
  Future<bool> updateData(
    TokenResponseDto token,
    String username, {
    int? expectedGeneration,
  }) async {
    updatedToken = token;
    updatedUsername = username;
    this.expectedGeneration = expectedGeneration;
    return true;
  }
}

class _ProviderGlobalDataService extends GlobalDataService {
  @override
  GlobalDataDto build() => _signedOutData();

  @override
  bool get cleanupRequired => false;
}

class _FakeSessionAuthApi extends SessionAuthApi {
  _FakeSessionAuthApi() : super(ApiClient(basePath: 'https://api.example'));

  final revokedRefreshTokens = <String>[];

  @override
  Future<void> revokeOwnSession(SessionRevokeRequestDto request) async {
    revokedRefreshTokens.add(request.refreshToken);
  }
}
