import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

class DelayedUsersApi extends UsersApi {
  final requestStarted = Completer<void>();
  final response = Completer<UserInfoDto?>();

  @override
  Future<UserInfoDto?> getUser(String userId) {
    requestStarted.complete();
    return response.future;
  }
}

void main() {
  test(
    'a user fetch started before logout cannot repopulate the cache',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final usersApi = DelayedUsersApi();
      final sessionGuard = AccountDataSessionGuard();
      final container = ProviderContainer(
        overrides: [
          driftRepoProvider.overrideWithValue(database),
          userApiProvider.overrideWithValue(usersApi),
          accountDataSessionGuardProvider.overrideWithValue(sessionGuard),
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'current-user',
              refreshToken: 'refresh-token',
              cameras: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        userServiceProvider('remote-user'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await usersApi.requestStarted.future;

      final cleanup = AccountDataCleanup(
        cacheCleaners: () => [container.read(userRepositoryProvider).deleteAll],
        sessionDataCleaner: () async {},
        sessionGuard: sessionGuard,
      );
      await cleanup.clearCache();

      usersApi.response.complete(
        UserInfoDto(username: 'remote-user', userId: 'remote-user'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await container.read(userRepositoryProvider).getAll(), isEmpty);
    },
  );
}
