import 'dart:io';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/util/core/cache_migrator.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> values;

  FakeSecureStorage(this.values);

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class FailingSecureStorage extends FakeSecureStorage {
  FailingSecureStorage(super.values);

  @override
  Future<void> delete({required String key}) async {
    if (key == GlobalDataRepository.tokenKey) {
      throw StateError('token deletion failed');
    }
    await super.delete(key: key);
  }
}

class SuccessfulUsersApi extends UsersApi {
  SuccessfulUsersApi() : super(ApiClient(basePath: 'https://example.test'));

  bool deleted = false;

  @override
  Future<void> deleteUser(String userId, {int? body}) async {
    deleted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  test('logout removes account data but keeps application settings', () async {
    SharedPreferences.setMockInitialValues({
      GlobalDataRepository.descriptionKey: 'Account biography',
      GlobalDataRepository.profileImageKey: 'profile-image',
      GlobalDataRepository.xpKey: 42,
      GlobalDataRepository.lastSeenKey: 1,
      GlobalDataRepository.themeKey: true,
      'hiveVersion': 2,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = FakeSecureStorage({
      GlobalDataRepository.usernameKey: 'alice',
      GlobalDataRepository.userIdKey: 'user-1',
      GlobalDataRepository.tokenKey: 'secret-token',
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(globalDataRepositoryProvider).logout();

    expect(storage.values, isEmpty);
    expect(prefs.containsKey(GlobalDataRepository.descriptionKey), isFalse);
    expect(prefs.containsKey(GlobalDataRepository.profileImageKey), isFalse);
    expect(prefs.containsKey(GlobalDataRepository.xpKey), isFalse);
    expect(prefs.containsKey(GlobalDataRepository.lastSeenKey), isFalse);
    expect(prefs.getBool(GlobalDataRepository.themeKey), isTrue);
    expect(prefs.getInt('hiveVersion'), 2);
  });

  test('service logout removes account-owned Drift and image data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.groupEntities)
        .insert(
          GroupEntitiesCompanion.insert(
            ttl: DateTime(2026),
            groupId: 'group-1',
            name: 'Account group',
            visibility: 1,
            userIsMember: true,
          ),
        );
    await database
        .into(database.imageEntities)
        .insert(
          ImageEntitiesCompanion.insert(
            ttl: DateTime(2026),
            id: 'image-1',
            type: ImageType.pin,
          ),
        );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
        driftRepoProvider.overrideWithValue(database),
        accountDataCleanupProvider.overrideWithValue(
          AccountDataCleanup(
            cacheCleaners: () => [
              () => database.delete(database.groupEntities).go(),
              () => database.delete(database.imageEntities).go(),
            ],
            sessionDataCleaner: () async {},
          ),
        ),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'user-1',
            refreshToken: 'secret-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(globalDataServiceProvider.notifier).logout();

    expect(await database.select(database.groupEntities).get(), isEmpty);
    expect(await database.select(database.imageEntities).get(), isEmpty);
  });

  test('production cleanup removes account-owned pin-like rows', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.pinLikeEntities)
        .insert(
          PinLikeEntitiesCompanion.insert(
            ttl: DateTime(2026),
            id: 'pin-1',
            likeCount: 1,
            likePhotographyCount: 1,
            likeLocationCount: 0,
            likeArtCount: 0,
            hasLike: true,
            hasLikePhotography: true,
            hasLikeLocation: false,
            hasLikeArt: false,
          ),
        );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
        driftRepoProvider.overrideWithValue(database),
        pinApiProvider.overrideWithValue(
          PinsApi(ApiClient(basePath: 'https://example.test')),
        ),
        groupApiProvider.overrideWithValue(
          GroupsApi(ApiClient(basePath: 'https://example.test')),
        ),
        userApiProvider.overrideWithValue(
          UsersApi(ApiClient(basePath: 'https://example.test')),
        ),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'user-1',
            refreshToken: 'secret-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    try {
      await container.read(accountDataCleanupProvider).clearCache();
    } catch (_) {
      // Platform-backed external cache cleanup is outside this database test.
    }

    expect(await database.select(database.pinLikeEntities).get(), isEmpty);
  });

  test('logout keeps authentication when cache cleanup fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sessionData = ['credential'];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
        accountDataCleanupProvider.overrideWithValue(
          AccountDataCleanup(
            cacheCleaners: () => [
              () async => throw StateError('tile cache failed'),
            ],
            sessionDataCleaner: () async {
              sessionData.clear();
            },
          ),
        ),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'deleted-user',
            refreshToken: 'secret-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final global = container.read(globalDataServiceProvider.notifier);

    await expectLater(global.logout(), throwsA(isA<StateError>()));

    expect(sessionData, ['credential']);
    expect(container.read(globalDataServiceProvider).userId, 'deleted-user');
    expect(
      container.read(globalDataServiceProvider).refreshToken,
      'secret-token',
    );
  });

  test('logout surfaces secure credential deletion failures', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FailingSecureStorage({
      GlobalDataRepository.usernameKey: 'alice',
      GlobalDataRepository.userIdKey: 'user-1',
      GlobalDataRepository.tokenKey: 'secret-token',
    });
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(storage),
        accountDataCleanupProvider.overrideWithValue(
          AccountDataCleanup(
            cacheCleaners: () => [],
            sessionDataCleaner: () =>
                container.read(globalDataRepositoryProvider).logout(),
          ),
        ),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'user-1',
            refreshToken: 'secret-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(globalDataServiceProvider.notifier).logout(),
      throwsA(isA<StateError>()),
    );

    expect(storage.values[GlobalDataRepository.tokenKey], 'secret-token');
    expect(container.read(globalDataServiceProvider).userId, 'user-1');
  });

  test(
    'logout resets keep-alive hidden filters for the next account',
    () async {
      SharedPreferences.setMockInitialValues({
        GlobalDataRepository.hiddenUsersKey: ['hidden-user'],
        GlobalDataRepository.hiddenPostsKey: ['hidden-post'],
      });
      final prefs = await SharedPreferences.getInstance();
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
          accountDataCleanupProvider.overrideWithValue(
            AccountDataCleanup(
              cacheCleaners: () => [],
              sessionDataCleaner: () =>
                  container.read(globalDataRepositoryProvider).logout(),
            ),
          ),
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-1',
              refreshToken: 'secret-token',
              cameras: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(hiddenUserServiceProvider), ['hidden-user']);
      expect(container.read(hiddenPostsServiceProvider), ['hidden-post']);

      await container.read(globalDataServiceProvider.notifier).logout();

      expect(container.read(hiddenUserServiceProvider), isEmpty);
      expect(container.read(hiddenPostsServiceProvider), isEmpty);
    },
  );

  test(
    'account deletion surfaces local cleanup failure after clearing auth',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final usersApi = SuccessfulUsersApi();
      final sessionData = ['credential'];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
          userApiProvider.overrideWithValue(usersApi),
          accountDataCleanupProvider.overrideWithValue(
            AccountDataCleanup(
              cacheCleaners: () => [
                () async => throw StateError('tile cache failed'),
              ],
              sessionDataCleaner: () async {
                sessionData.clear();
              },
            ),
          ),
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'deleted-user',
              refreshToken: 'secret-token',
              cameras: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final message = await container
          .read(authServiceProvider.notifier)
          .deleteAccount(123);

      expect(usersApi.deleted, isTrue);
      expect(
        message,
        'Your account was deleted, but local cleanup failed. Please restart the app.',
      );
      expect(sessionData, isEmpty);
      expect(container.read(globalDataServiceProvider).userId, isNull);
    },
  );

  test('completed cache migration remains a no-op after logout', () async {
    SharedPreferences.setMockInitialValues({
      GlobalDataRepository.themeKey: true,
      'hiveVersion': 2,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage({})),
      ],
    );
    addTearDown(container.dispose);

    await container.read(globalDataRepositoryProvider).logout();
    await CacheMigrator(prefs: prefs, latestVersion: 2).noDatabaseMigrate();

    expect(prefs.getInt('hiveVersion'), 2);
    expect(prefs.getBool(GlobalDataRepository.themeKey), isTrue);
  });
}
