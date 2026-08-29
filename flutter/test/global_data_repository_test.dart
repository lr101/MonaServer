import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/util/core/cache_migrator.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
            cacheCleaners: [
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
