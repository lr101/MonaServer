import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/core/session/session_status.dart';
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_like_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/account_cleanup_service.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/util/routing/routing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class MemorySecureStorage implements ISecureStorage {
  final values = <String, String>{
    'userId': 'alice',
    'auth': 'alice-token',
    'username': 'Alice',
  };
  String? failingWriteKey;
  String? failingDeleteKey;
  Completer<void>? pendingWrite;
  final writeStarted = Completer<void>();
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    if (key == failingWriteKey) throw StateError('secure storage unavailable');
    if (!writeStarted.isCompleted) writeStarted.complete();
    await pendingWrite?.future;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    if (key == failingDeleteKey) throw StateError('secure storage unavailable');
    values.remove(key);
  }
}

class Fixture {
  Fixture(this.container, this.db, this.storage, this.prefs);
  final ProviderContainer container;
  final AppDatabase db;
  final MemorySecureStorage storage;
  final SharedPreferences prefs;
  GlobalDataService get global =>
      container.read(globalDataServiceProvider.notifier);

  static Future<Fixture> create({
    Future<void> Function()? clearPlatformCaches,
    http.Client? userClient,
    FailedPreferencesStore? preferencesStore,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final storage = MemorySecureStorage();
    SharedPreferences.setMockInitialValues({
      'profileImageKey': 'AQID',
      'lastSeenKey': 123,
    });
    if (preferencesStore != null) {
      SharedPreferencesStorePlatform.instance = preferencesStore;
      SharedPreferences.resetStatic();
    }
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient();
    if (userClient != null) api.client = userClient;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        driftRepoProvider.overrideWithValue(db),
        clearPlatformCachesProvider.overrideWithValue(
          clearPlatformCaches ?? () async {},
        ),
        secureStorageProvider.overrideWithValue(storage),
        userApiProvider.overrideWithValue(UsersApi(api)),
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(
            userId: 'alice',
            refreshToken: 'alice-token',
            cameras: [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return Fixture(container, db, storage, prefs);
  }
}

class FailedPreferencesStore extends InMemorySharedPreferencesStore {
  FailedPreferencesStore()
    : super.withData({'flutter.profileImageKey': 'AQID'});
  String? failedRemoval;
  bool failMarkerWrite = false;
  @override
  Future<bool> remove(String key) =>
      key == failedRemoval ? Future.value(false) : super.remove(key);
  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      failMarkerWrite && key == 'flutter.accountCleanupPending'
      ? Future.value(false)
      : super.setValue(valueType, key, value);
}

class PendingLocation extends GeolocatorPlatform {
  final started = Completer<void>();
  late final positions = StreamController<Position>.broadcast(
    onListen: () {
      if (!started.isCompleted) started.complete();
    },
  );
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positions.stream;
}

PinLikeEntity like() => PinLikeEntity(
  ttl: DateTime.now().add(const Duration(days: 1)),
  onlySession: false,
  id: 'pin',
  likeCount: 1,
  likePhotographyCount: 0,
  likeLocationCount: 0,
  likeArtCount: 0,
  hasLike: true,
  hasLikePhotography: false,
  hasLikeLocation: false,
  hasLikeArt: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    dotenv.loadFromString(envString: 'API_HOST=http://localhost');
  });

  test('HTTP refresh rejection expires the real account and prevents the protected send', () async {
    var protectedSends = 0;
    await http.runWithClient(
      () async {
        final f = await Fixture.create();
        final client = f.container.read(openApiConfigProvider);
        await expectLater(
          client.client.get(Uri.parse('http://localhost/api/v2/pins')),
          throwsA(
            anyOf(
              isA<InvalidRefreshCredentialsException>(),
              isA<http.ClientException>(),
            ),
          ),
        );
        await f.container.pump();
        expect(
          f.container.read(globalDataServiceProvider).sessionStatus,
          SessionStatus.expired,
        );
        expect(f.storage.values['auth'], isNull);
        expect(protectedSends, 0);
      },
      () => MockClient((request) async {
        if (request.url.path.contains('refresh')) {
          return http.Response(
            '{}',
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        protectedSends++;
        return http.Response('{}', 200);
      }),
    );
  });

  testWidgets(
    'the owned router refreshes on expiry and redirects a protected route',
    (tester) async {
      final f = await Fixture.create();
      final router = f.container.read(routerProvider);
      router.go('/settings');
      var notifications = 0;
      router.routeInformationProvider.addListener(() {
        notifications++;
      });
      await f.global.expireSession(expectedGeneration: f.global.generation);
      expect(notifications, greaterThan(0));
      expect(f.container.read(routerProvider), same(router));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final matches = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
            router.routeInformationProvider.value,
            tester.element(find.byType(SizedBox)),
          );
      expect(matches.uri.path, '/login');
    },
  );

  test(
    'expiry revokes account work but retains drafts and the account identity',
    () async {
      final f = await Fixture.create();
      final active = f.global.storageSession;
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('offline-pin', Uint8List.fromList([1, 2, 3]), true);
      final expired = await f.global.expireSession(
        expectedGeneration: f.global.generation,
      );
      expect(expired, isTrue);
      expect(active.isActive, isFalse);
      expect(f.global.storageSession.isActive, isFalse);
      expect(
        f.container.read(globalDataServiceProvider).sessionStatus,
        SessionStatus.expired,
      );
      expect(f.container.read(globalDataServiceProvider).userId, 'alice');
      expect(f.container.read(globalDataServiceProvider).refreshToken, isNull);
      expect(f.storage.values['auth'], isNull);
      expect(f.storage.values['userId'], 'alice');
      expect(await f.db.select(f.db.imageEntities).get(), hasLength(1));
      expect(f.global.cleanupRequired, isFalse);
      final restored = await GlobalDataRepository.get(f.prefs, f.storage);
      expect(restored.sessionStatus, SessionStatus.expired);
    },
  );

  test(
    'late credential rejection cannot expire a replacement session',
    () async {
      final f = await Fixture.create();
      final oldGeneration = f.global.generation;
      await f.global.updateData(
        TokenResponseDto(
          userId: 'alice',
          refreshToken: 'new-refresh',
          accessToken: 'new-access',
        ),
        'Alice',
      );
      expect(
        await f.global.expireSession(expectedGeneration: oldGeneration),
        isFalse,
      );
      expect(
        f.container.read(globalDataServiceProvider).sessionStatus,
        SessionStatus.signedIn,
      );
      expect(f.storage.values['auth'], 'new-refresh');
    },
  );

  test(
    'failed same-account reauthentication keeps the paused drafts',
    () async {
      final f = await Fixture.create();
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('offline-pin', Uint8List.fromList([1, 2, 3]), true);
      await f.global.expireSession(expectedGeneration: f.global.generation);
      f.storage.failingWriteKey = 'auth';
      await expectLater(
        f.global.updateData(
          TokenResponseDto(
            userId: 'alice',
            refreshToken: 'new-refresh',
            accessToken: 'new-access',
          ),
          'Alice',
        ),
        throwsStateError,
      );
      expect(
        f.container.read(globalDataServiceProvider).sessionStatus,
        SessionStatus.expired,
      );
      expect(await f.db.select(f.db.imageEntities).get(), hasLength(1));
      expect(f.storage.values['auth'], isNull);
      expect(f.global.cleanupRequired, isFalse);
    },
  );

  test('restart stays expired when secure-storage deletion fails', () async {
    final f = await Fixture.create();
    f.storage.failingDeleteKey = 'auth';
    await expectLater(
      f.global.expireSession(expectedGeneration: f.global.generation),
      throwsStateError,
    );
    expect(f.storage.values['auth'], 'alice-token');
    await f.prefs.reload();
    final restored = await GlobalDataRepository.get(f.prefs, f.storage);
    expect(restored.sessionStatus, SessionStatus.expired);
    expect(restored.refreshToken, isNull);
    expect(restored.userId, 'alice');
    // Successful reauthentication clears the marker and restores normally.
    f.storage.failingDeleteKey = null;
    await f.global.updateData(
      TokenResponseDto(
        userId: 'alice',
        refreshToken: 'new-refresh',
        accessToken: 'new-access',
      ),
      'Alice',
    );
    await f.prefs.reload();
    expect(
      (await GlobalDataRepository.get(f.prefs, f.storage)).sessionStatus,
      SessionStatus.signedIn,
    );
  });

  for (final sameAccount in [true, false]) {
    test(
      'login after expiry ${sameAccount ? "retains same-account" : "clears other-account"} drafts',
      () async {
        final f = await Fixture.create();
        await f.container
            .read(pinImageRepositoryProvider)
            .addImage('offline-pin', Uint8List.fromList([1, 2, 3]), true);
        await f.global.expireSession(expectedGeneration: f.global.generation);
        final accepted = await f.global.updateData(
          TokenResponseDto(
            userId: sameAccount ? 'alice' : 'bob',
            refreshToken: 'fresh-refresh',
            accessToken: 'fresh-access',
          ),
          sameAccount ? 'Alice' : 'Bob',
        );
        expect(accepted, isTrue);
        expect(
          f.container.read(globalDataServiceProvider).sessionStatus,
          SessionStatus.signedIn,
        );
        expect(f.global.storageSession.isActive, isTrue);
        expect(
          await f.db.select(f.db.imageEntities).get(),
          hasLength(sameAccount ? 1 : 0),
        );
      },
    );
  }

  test(
    'logout erases retained pictures and pin likes through the service',
    () async {
      final f = await Fixture.create();
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('offline-pin', Uint8List.fromList([1, 2, 3]), true);
      await f.container.read(pinLikeRepositoryProvider).put(like());
      await f.global.logout();
      expect(await f.db.select(f.db.imageEntities).get(), isEmpty);
      expect(await f.db.select(f.db.pinLikeEntities).get(), isEmpty);
      expect(f.prefs.getKeys(), isEmpty);
      expect(f.storage.values, isEmpty);
      expect(f.container.read(globalDataServiceProvider).userId, isNull);
    },
  );

  test('logout clears account filters already held in memory', () async {
    final f = await Fixture.create();
    await f.prefs.setStringList('hiddenUsers', ['private-user']);
    await f.prefs.setStringList('hiddenPosts', ['private-pin']);
    expect(f.container.read(hiddenUserServiceProvider), ['private-user']);
    expect(f.container.read(hiddenPostsServiceProvider), ['private-pin']);
    await f.global.logout();
    expect(f.container.read(hiddenUserServiceProvider), isEmpty);
    expect(f.container.read(hiddenPostsServiceProvider), isEmpty);
  });

  test(
    'startup does not restore credentials while cleanup is pending',
    () async {
      final f = await Fixture.create();
      await f.prefs.setBool('accountCleanupPending', true);
      final data = await GlobalDataRepository.get(f.prefs, f.storage);
      expect(data.userId, isNull);
      expect(data.refreshToken, isNull);
    },
  );

  test(
    'cleanup waits for an old transaction before clearing its writes',
    () async {
      final f = await Fixture.create();
      final db = f.container.read(accountDatabaseProvider);
      final started = Completer<void>();
      final release = Completer<void>();
      final transaction = db.transaction(() async {
        await PinLikeRepository(db).put(like());
        started.complete();
        await release.future;
        await PinLikeRepository(db).put(like());
      });
      await started.future;
      var finished = false;
      final logout = f.global.logout().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      release.complete();
      await transaction;
      await logout;
      expect(await f.db.select(f.db.pinLikeEntities).get(), isEmpty);
    },
  );

  test('failed preference removal keeps cleanup pending and retry reloads persisted keys', () async {
    final store = FailedPreferencesStore()
      ..failedRemoval = 'flutter.profileImageKey';
    final f = await Fixture.create(preferencesStore: store);
    await expectLater(f.global.logout(), throwsStateError);
    expect(f.global.cleanupRequired, isTrue);
    expect(f.prefs.getBool('accountCleanupPending'), isTrue);
    expect(f.storage.values, isEmpty);
    store.failedRemoval = null;
    await f.global.logout();
    await f.prefs.reload();
    expect(f.prefs.getKeys(), isEmpty);
  });

  test('failed marker write still attempts local erasure and cannot admit another account', () async {
    final store = FailedPreferencesStore()..failMarkerWrite = true;
    final f = await Fixture.create(preferencesStore: store);
    await f.container.read(pinLikeRepositoryProvider).put(like());
    await expectLater(f.global.logout(), throwsStateError);
    expect(f.storage.values, isEmpty);
    expect(await f.db.select(f.db.pinLikeEntities).get(), isEmpty);
    expect(f.global.cleanupRequired, isTrue);
  });

  test(
    'cache-only cleanup updates image streams while keeping credentials',
    () async {
      final f = await Fixture.create();
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('pin', Uint8List.fromList([1]), true);
      final imageProvider = StreamProvider<Uint8List?>(
        (ref) => ref.watch(pinImageRepositoryProvider).watchImageBytes('pin'),
      );
      final subscription = f.container.listen(imageProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await f.container.read(imageProvider.future), [1]);
      await f.container.read(accountCleanupProvider).clearCaches();
      await f.container.pump();
      expect(await f.container.read(imageProvider.future), isNull);
      expect(f.container.read(globalDataServiceProvider).userId, 'alice');
      expect(f.storage.values['auth'], 'alice-token');
    },
  );

  test('a delayed GPS result cannot restore location after logout', () async {
    final f = await Fixture.create();
    final original = GeolocatorPlatform.instance;
    final location = PendingLocation();
    GeolocatorPlatform.instance = location;
    addTearDown(() {
      GeolocatorPlatform.instance = original;
    });
    addTearDown(() {
      f.container.dispose();
      return location.positions.close();
    });
    final subscription = f.container.listen(currentLocationProvider, (_, _) {});
    addTearDown(subscription.close);
    await location.started.future;
    await f.global.logout();
    location.positions.add(
      Position(
        latitude: 49,
        longitude: 8,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(f.prefs.getDouble('lastKnownLat'), isNull);
    expect(f.prefs.getDouble('lastKnownLong'), isNull);
  });

  test('old repositories cannot write into the next account', () async {
    final f = await Fixture.create();
    final oldLikes = f.container.read(pinLikeRepositoryProvider);
    await oldLikes.put(like());
    await f.global.logout();
    await f.global.updateData(
      TokenResponseDto(
        accessToken: 'access',
        userId: 'bob',
        refreshToken: 'bob-token',
      ),
      'Bob',
    );
    await oldLikes.put(like());
    expect(await f.db.select(f.db.pinLikeEntities).get(), isEmpty);
    await f.container.read(pinLikeRepositoryProvider).put(like());
    expect(await f.db.select(f.db.pinLikeEntities).get(), hasLength(1));
    expect(await oldLikes.getAll(), isEmpty);
    await oldLikes.deleteAll();
    expect(await f.db.select(f.db.pinLikeEntities).get(), hasLength(1));
  });

  test('download completing after logout cannot restore pictures', () async {
    final f = await Fixture.create();
    final started = Completer<void>();
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final images = f.container.read(pinImageRepositoryProvider);
        final download = images.fetchImageFromUrl(
          'pin',
          'https://example.com/picture',
          true,
        );
        await started.future;
        await f.global.logout();
        response.complete(http.Response.bytes([4, 5, 6], 200));
        expect(await download, isNull);
        expect(await f.db.select(f.db.imageEntities).get(), isEmpty);
      },
      () => MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
  });

  test(
    'logout clears credentials after an already started login write',
    () async {
      final f = await Fixture.create();
      f.storage.pendingWrite = Completer<void>();
      final login = f.global.updateData(
        TokenResponseDto(
          accessToken: 'access',
          userId: 'bob',
          refreshToken: 'bob-token',
        ),
        'Bob',
      );
      await f.storage.writeStarted.future;
      final logout = f.global.logout();
      expect(f.container.read(globalDataServiceProvider).userId, isNull);
      f.storage.pendingWrite!.complete();
      await Future.wait([login, logout]);
      expect(f.storage.values, isEmpty);
      expect(f.container.read(globalDataServiceProvider).userId, isNull);
    },
  );

  test(
    'failed credential persistence cannot restore a partial login on restart',
    () async {
      final f = await Fixture.create();
      await f.global.logout();
      f.storage.failingWriteKey = 'auth';
      await expectLater(
        f.global.updateData(
          TokenResponseDto(
            accessToken: 'access',
            userId: 'bob',
            refreshToken: 'bob-token',
          ),
          'Bob',
        ),
        throwsStateError,
      );
      expect(f.storage.values, isEmpty);
      final restarted = await GlobalDataRepository.get(f.prefs, f.storage);
      expect(restarted.userId, isNull);
    },
  );

  test('account deletion clears local pictures after remote success', () async {
    final f = await Fixture.create(
      userClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/users/alice'));
        return http.Response('', 204);
      }),
    );
    await f.container
        .read(pinImageRepositoryProvider)
        .addImage('offline-pin', Uint8List.fromList([1]), true);
    expect(
      await f.container
          .read(authServiceProvider.notifier)
          .deleteAccount(123456),
      isNull,
    );
    expect(await f.db.select(f.db.imageEntities).get(), isEmpty);
    expect(f.storage.values, isEmpty);
  });

  test(
    'a user refresh started before logout cannot use rebuilt repositories',
    () async {
      final started = Completer<void>();
      final oldResponse = Completer<http.Response>();
      var first = true;
      final f = await Fixture.create(
        userClient: MockClient((_) async {
          if (first) {
            first = false;
            started.complete();
            return oldResponse.future;
          }
          return http.Response(
            jsonEncode(
              UserInfoDto(userId: 'alice', username: 'Current').toJson(),
            ),
            200,
          );
        }),
      );
      final subscription = f.container.listen(
        userServiceProvider('alice'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await started.future;
      await f.global.logout();
      await f.global.updateData(
        TokenResponseDto(
          accessToken: 'access',
          userId: 'bob',
          refreshToken: 'bob-token',
        ),
        'Bob',
      );
      f.container.read(userServiceProvider('alice'));
      final repo = f.container.read(userRepositoryProvider);
      await repo
          .watchById('alice')
          .firstWhere((user) => user?.username == 'Current');
      oldResponse.complete(
        http.Response(
          jsonEncode(
            UserInfoDto(
              userId: 'alice',
              username: 'Old private profile',
            ).toJson(),
          ),
          200,
        ),
      );
      // Drain the response and its local database continuation.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await repo.get('alice'))?.username, 'Current');
    },
  );

  test('cleanup failure still signs out and allows cleanup retry', () async {
    var failing = true;
    final f = await Fixture.create(
      clearPlatformCaches: () async {
        if (failing) throw StateError('cache unavailable');
      },
    );
    await f.container.read(pinLikeRepositoryProvider).put(like());
    await expectLater(f.global.logout(), throwsStateError);
    expect(f.storage.values, isEmpty);
    expect(await f.db.select(f.db.pinLikeEntities).get(), isEmpty);
    expect(f.container.read(globalDataServiceProvider).userId, isNull);
    await expectLater(
      f.global.updateData(
        TokenResponseDto(
          accessToken: 'access',
          userId: 'bob',
          refreshToken: 'bob-token',
        ),
        'Bob',
      ),
      throwsStateError,
    );
    expect(f.storage.values, isEmpty);
    expect(f.prefs.getBool('accountCleanupPending'), isTrue);
    failing = false;
    await f.global.logout();
    expect(f.prefs.getKeys(), isEmpty);
  });
}
