import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';

void main() {
  test('requests and returns XP for the signed-in account', () async {
    final requests = <http.Request>[];
    final container = _container(
      MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_xpJson(totalXp: 75, level: 3)), 200);
      }),
    );
    addTearDown(container.dispose);

    final xp = await container.read(userXpProvider('alice').future);

    expect(xp?.totalXp, 75);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v2/users/alice/xp');
  });

  test('surfaces an XP API failure', () async {
    final container = _container(
      MockClient((_) async => http.Response('Unavailable', 503)),
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      userXpProvider('alice'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(userXpProvider('alice').future),
      throwsA(isA<ApiException>()),
    );
  });

  test('discards an XP response when the account changes in flight', () async {
    final requestStarted = Completer<void>();
    final response = Completer<http.Response>();
    final globalData = _SwitchableGlobalDataService();
    final container = _container(
      MockClient((request) {
        expect(request.url.path, '/api/v2/users/alice/xp');
        requestStarted.complete();
        return response.future;
      }),
      globalDataService: globalData,
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      userXpProvider('alice'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final request = container.read(userXpProvider('alice').future);
    await requestStarted.future;

    globalData.switchTo(_globalData('bob', 'bob-token'));
    response.complete(
      http.Response(jsonEncode(_xpJson(totalXp: 10000, level: 14)), 200),
    );

    expect(await request, isNull);
    await container.pump();
    expect(await container.read(userXpProvider('alice').future), isNull);
  });

  test('does not request XP for another account', () async {
    var requests = 0;
    final container = _container(
      MockClient((_) async {
        requests++;
        return http.Response(jsonEncode(_xpJson()), 200);
      }),
    );
    addTearDown(container.dispose);

    final xp = await container.read(userXpProvider('another-user').future);

    expect(xp, isNull);
    expect(requests, 0);
  });
}

ProviderContainer _container(
  http.Client client, {
  _SwitchableGlobalDataService? globalDataService,
}) {
  final apiClient = ApiClient(basePath: 'http://localhost');
  apiClient.client = client;
  return ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      globalDataOnceProvider.overrideWithValue(
        _globalData('alice', 'alice-token'),
      ),
      if (globalDataService != null)
        globalDataServiceProvider.overrideWith(() => globalDataService),
      userApiProvider.overrideWithValue(UsersApi(apiClient)),
    ],
  );
}

GlobalDataDto _globalData(String userId, String refreshToken) => GlobalDataDto(
  userId: userId,
  refreshToken: refreshToken,
  cameras: const [],
);

Map<String, int> _xpJson({int totalXp = 0, int level = 1}) => {
  'totalXp': totalXp,
  'currentLevel': level,
  'currentLevelXp': totalXp,
  'nextLevelXp': totalXp,
};

class _SwitchableGlobalDataService extends GlobalDataService {
  void switchTo(GlobalDataDto data) {
    storageSession.revoke();
    storageSession = AccountSession(data.refreshToken?.isNotEmpty == true);
    state = data;
  }
}
