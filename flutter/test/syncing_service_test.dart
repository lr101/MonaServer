import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/app/lifecycle/sync_lifecycle.dart';
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dotenv.loadFromString(envString: 'API_HOST=http://localhost');
  });

  test(
    'observing or rebuilding sync state does not start remote work',
    () async {
      final f = await _fixture();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(f.api.calls, 0);
      expect(f.container.read(syncingServiceProvider), SyncState.init);
      f.container.invalidate(syncingServiceProvider);
      await f.container.pump();
      expect(f.api.calls, 0);
      await f.container.read(syncingServiceProvider.notifier).syncToBackend();
      expect(f.api.calls, 1);
      expect(f.container.read(syncingServiceProvider), SyncState.finished);
    },
  );

  test(
    'cache facade rebuild keeps coordinator ownership and serializes restart',
    () async {
      final f = await _fixture();
      final coordinator = f.container.read(syncCoordinatorProvider);
      f.api.response = Completer<SyncDto?>();
      final old = coordinator.setSession(
        f.container.read(accountSessionProvider),
      );
      await f.api.started.future;
      f.container.invalidate(accountDatabaseProvider);
      await f.container.pump();
      expect(f.container.read(syncCoordinatorProvider), same(coordinator));
      final next = coordinator.restart();
      expect(f.api.calls, 1);
      f.api.response!.complete(SyncDto(groupUpdates: []));
      await Future.wait([old, next]);
      expect(f.api.calls, 2);
      expect(f.container.read(syncingServiceProvider), SyncState.finished);
    },
  );

  test('a superseded metadata response cannot delete cached pins', () async {
    final f = await _fixture();
    await f.container.read(pinRepositoryProvider).put(_draft());
    f.api.response = Completer<SyncDto?>();
    final subscription = f.container.listen(syncingServiceProvider, (_, _) {});
    addTearDown(subscription.close);
    var current = true;
    final pending = f.container
        .read(syncingServiceProvider.notifier)
        .syncToBackend(isActive: () => current);
    await f.api.started.future;
    current = false;
    f.api.response!.complete(SyncDto(groupUpdates: [], deletedPins: ['draft']));
    await pending;
    expect(
      (await f.db.select(f.db.pinEntities).get()).map((pin) => pin.pinId),
      ['draft'],
    );
  });

  test(
    'a late upload result cannot replace a draft after its run is revoked',
    () async {
      final f = await _fixture();
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      var current = true;
      final pending = f.container
          .read(syncingServiceProvider.notifier)
          .syncToBackend(isActive: () => current);
      await f.api.uploadStarted.future;
      current = false;
      f.api.upload!.complete(
        PinWithOptionalImageDto(
          id: 'server-pin',
          latitude: 1,
          longitude: 2,
          creationDate: DateTime.utc(2026),
          creationUser: 'alice',
          groupId: 'group',
        ),
      );
      await pending;
      expect(
        (await f.db.select(f.db.pinEntities).get()).map((pin) => pin.pinId),
        ['draft'],
      );
      expect(await f.db.select(f.db.imageEntities).get(), hasLength(1));
    },
  );

  test(
    'upload failures retain the draft, fail the run, and do not log payloads',
    () async {
      final f = await _fixture();
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final output = <String>[];
      await runZoned(
        () async {
          final pending = expectLater(
            f.container.read(syncingServiceProvider.notifier).syncToBackend(),
            throwsA(isA<ApiException>()),
          );
          await f.api.uploadStarted.future;
          f.api.upload!.completeError(ApiException(503, 'sensitive payload'));
          await pending;
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) {
            output.add(line);
          },
        ),
      );
      expect(f.container.read(syncingServiceProvider), SyncState.failed);
      expect(await f.db.select(f.db.pinEntities).get(), hasLength(1));
      expect(output, isEmpty);
    },
  );

  test('finds local groups that are absent from the server sync', () {
    final response = SyncDto(
      groupUpdates: [
        SyncDtoGroupUpdatesInner(
          group: GroupDto(id: 'kept', name: 'Kept', visibility: 0),
        ),
      ],
    );

    expect(removedUserGroupIds(['kept', 'removed'], response), {'removed'});
  });
}

class _NoUser extends UserService {
  @override
  Stream<UserEntity?> build(String userId) => Stream.value(null);
}

class _Pins extends PinsApi {
  int calls = 0;
  Completer<SyncDto?>? response;
  Completer<PinWithOptionalImageDto?>? upload;
  final started = Completer<void>();
  final uploadStarted = Completer<void>();
  @override
  Future<PinWithOptionalImageDto?> createPin(PinRequestDto request) {
    uploadStarted.complete();
    return upload!.future;
  }

  @override
  Future<SyncDto?> callSync({DateTime? lastSeen}) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (response != null) return response!.future;
    return SyncDto(groupUpdates: []);
  }
}

Future<({ProviderContainer container, AppDatabase db, _Pins api})>
_fixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final api = _Pins();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      driftRepoProvider.overrideWithValue(db),
      globalDataOnceProvider.overrideWithValue(
        const GlobalDataDto(
          userId: 'alice',
          refreshToken: 'alice-refresh',
          cameras: [],
        ),
      ),
      pinApiProvider.overrideWithValue(api),
      userServiceProvider('alice').overrideWith(_NoUser.new),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, db: db, api: api);
}

PinEntity _draft() => PinEntity(
  pinId: 'draft',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creator: 'alice',
  groupId: 'group',
  ttl: DateTime.utc(2099),
  onlySession: false,
  keepAlive: true,
);
