import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';

void main() {
  test('online pin creation refreshes group progression', () async {
    final fixture = await _Fixture.create(_Mutation.pin);
    addTearDown(fixture.dispose);
    final progression = fixture.container.listen(
      groupProgressionProvider('group-id'),
      (_, _) {},
    );
    fixture.keep(progression);
    await fixture.container.read(groupProgressionProvider('group-id').future);
    expect(fixture.groupProgressionRequests, 1);

    expect(await fixture.performAction(), isNull);
    await fixture.secondGroupProgressionRequestStarted.future.timeout(
      const Duration(seconds: 2),
    );
    await fixture.container.pump();
    final refreshed = await fixture.container.read(
      groupProgressionProvider('group-id').future,
    );

    expect(fixture.groupProgressionRequests, 2);
    expect(refreshed?.totalXp, 5);
  });

  test(
    'pin save returns while its first network upload is still pending',
    () async {
      final fixture = await _Fixture.create(_Mutation.pin, pauseMutation: true);
      addTearDown(fixture.dispose);

      final save = fixture.performAction();
      await fixture.mutationRequestStarted.future.timeout(
        const Duration(seconds: 2),
      );
      expect(
        await fixture.database.select(fixture.database.pendingPinCreates).get(),
        hasLength(1),
        reason: 'the request starts only after its durable outbox row is saved',
      );
      final returnedBeforeResponse = await Future.any([
        save.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 50), () => false),
      ]);

      fixture.completeMutationSuccess();
      expect(await save, isNull);
      await fixture.waitForPinUpload();

      expect(
        returnedBeforeResponse,
        isTrue,
        reason: 'the upload page should finish without waiting for the server',
      );
    },
  );

  test(
    'pin save returns after outbox commit without waiting for cache writes',
    () async {
      final fixture = await _Fixture.create(
        _Mutation.pin,
        pausePinCacheWrite: true,
      );
      addTearDown(fixture.dispose);

      final save = fixture.performAction();
      await fixture.pinCacheWriteStarted.future.timeout(
        const Duration(seconds: 2),
      );
      expect(
        await fixture.database.select(fixture.database.pendingPinCreates).get(),
        hasLength(1),
        reason: 'the complete post is durable before cache projection starts',
      );
      final uploadStartedBeforeCacheWrite = await Future.any([
        fixture.mutationRequestStarted.future.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
      ]);
      final returnedBeforeCacheWrite = await Future.any([
        save.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
      ]);

      fixture.releasePinCacheWrite.complete();
      await fixture.mutationRequestStarted.future.timeout(
        const Duration(seconds: 2),
      );
      expect(await save, isNull);
      await fixture.waitForPinUpload();

      expect(
        returnedBeforeCacheWrite,
        isTrue,
        reason: 'the approval page should leave after the outbox commit',
      );
      expect(
        uploadStartedBeforeCacheWrite,
        isTrue,
        reason: 'cache projection must not hold up the background POST',
      );
    },
  );

  test('deleting a failed upload waits for its pending cache write', () async {
    final fixture = await _Fixture.create(
      _Mutation.pin,
      pauseMutation: true,
      pausePinCacheWrite: true,
    );
    addTearDown(fixture.dispose);

    final save = fixture.performAction();
    await fixture.pinCacheWriteStarted.future.timeout(
      const Duration(seconds: 2),
    );
    await fixture.mutationRequestStarted.future.timeout(
      const Duration(seconds: 2),
    );
    expect(await save, isNull);

    final deleting = fixture.container
        .read(pinServiceProvider)
        .deletePinFromGroup('draft-pin');
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final row = await fixture.database
          .select(fixture.database.pendingPinCreates)
          .getSingleOrNull();
      if (row?.cancelRequested == true) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      (await fixture.database
              .select(fixture.database.pendingPinCreates)
              .getSingleOrNull())
          ?.cancelRequested,
      isTrue,
    );

    fixture.mutationResponse.complete(http.Response('Unavailable', 503));
    final deleteReturnedBeforeCacheWrite = await Future.any([
      deleting.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
    ]);
    expect(
      deleteReturnedBeforeCacheWrite,
      isFalse,
      reason: 'delete must wait for the in-flight cache projection',
    );

    fixture.releasePinCacheWrite.complete();
    expect(await deleting, isNull);
    expect(
      await fixture.container.read(pinRepositoryProvider).get('draft-pin'),
      isNull,
    );
  });

  for (final action in _Mutation.values) {
    test('${action.label} refreshes XP', () async {
      final fixture = await _Fixture.create(action);
      addTearDown(fixture.dispose);
      await fixture.prepare();

      expect(await fixture.performAction(), isNull);
      if (action == _Mutation.achievement) {
        final claimed = fixture.container
            .read(achievementsProvider)
            .value!
            .single;
        expect(claimed.claimed, isTrue);
        expect(claimed.rewardAvailable, isFalse);
      }
      await fixture.secondXpRequestStarted.future.timeout(
        const Duration(seconds: 2),
      );
      await fixture.container.pump();
      await fixture.container.read(userXpProvider('alice').future);

      expect(fixture.xpRequests, 2);
      expect(
        fixture.container.read(userXpProvider('alice')).value?.totalXp,
        25,
      );
      if (action == _Mutation.achievement) {
        final claimedAchievement = fixture.container
            .read(achievementsProvider)
            .value!
            .single;
        expect(claimedAchievement.claimed, isTrue);
        expect(claimedAchievement.rewardAvailable, isFalse);
      }
    });

    test('${action.label} API failure does not refresh XP', () async {
      final fixture = await _Fixture.create(action, mutationStatus: 503);
      addTearDown(fixture.dispose);
      await fixture.prepare();

      final result = await fixture.performAction();
      if (action == _Mutation.pin) {
        expect(result, isNull);
        await fixture.mutationRequestStarted.future.timeout(
          const Duration(seconds: 2),
        );
        final row = await fixture.waitForPinUploadError();
        expect(row, isNotNull);
        expect(row!.lastError, 'HTTP 503');
      } else {
        expect(result, isNotNull);
      }
      await fixture.container.pump();

      expect(fixture.xpRequests, 1);
    });

    test(
      '${action.label} finishing after an account switch is ignored',
      () async {
        final fixture = await _Fixture.create(action, pauseMutation: true);
        addTearDown(fixture.dispose);
        await fixture.prepare();

        final mutation = fixture.performAction();
        await fixture.mutationRequestStarted.future.timeout(
          const Duration(seconds: 2),
        );
        fixture.globalData.switchTo(_globalData('bob', 'bob-token'));
        fixture.completeMutationSuccess();

        if (action == _Mutation.pin) {
          expect(await mutation, isNull);
        } else {
          expect(await mutation, 'Session ended');
        }
        await fixture.container.pump();

        expect(fixture.xpRequests, 1);
        expect(
          await fixture.container.read(userXpProvider('alice').future),
          isNull,
        );
      },
    );
  }
}

enum _Mutation { pin, group, achievement }

extension on _Mutation {
  String get label => switch (this) {
    _Mutation.pin => 'pin creation',
    _Mutation.group => 'group creation',
    _Mutation.achievement => 'achievement claim',
  };
}

class _Fixture {
  _Fixture({
    required this.action,
    required this.database,
    required this.container,
    required this.apiClient,
    required this.globalData,
    required this.pauseMutation,
    required this.mutationStatus,
    required this.pinCacheWriteStarted,
    required this.releasePinCacheWrite,
  });

  final _Mutation action;
  final AppDatabase database;
  final ProviderContainer container;
  final ApiClient apiClient;
  final _SwitchableGlobalDataService globalData;
  final bool pauseMutation;
  final int mutationStatus;
  final Completer<void> pinCacheWriteStarted;
  final Completer<void> releasePinCacheWrite;
  final mutationRequestStarted = Completer<void>();
  final secondXpRequestStarted = Completer<void>();
  final mutationResponse = Completer<http.Response>();
  final secondGroupProgressionRequestStarted = Completer<void>();
  int xpRequests = 0;
  int groupProgressionRequests = 0;

  static Future<_Fixture> create(
    _Mutation action, {
    bool pauseMutation = false,
    bool pausePinCacheWrite = false,
    int mutationStatus = 200,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(database);
    final pinCacheWriteStarted = Completer<void>();
    final releasePinCacheWrite = Completer<void>();
    final pins = pausePinCacheWrite
        ? _DelayedPinRepository(
            database,
            pinCacheWriteStarted,
            releasePinCacheWrite,
          )
        : PinRepository(database);
    await Future.wait([groups.ready, pins.ready]);
    final globalData = _SwitchableGlobalDataService();
    late _Fixture fixture;
    final client = ApiClient(basePath: 'http://localhost');
    client.client = MockClient((request) => fixture.handle(request));
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        globalDataOnceProvider.overrideWithValue(
          _globalData('alice', 'alice-token'),
        ),
        globalDataServiceProvider.overrideWith(() => globalData),
        driftRepoProvider.overrideWithValue(database),
        accountDatabaseProvider.overrideWithValue(database),
        groupRepositoryProvider.overrideWithValue(groups),
        pinRepositoryProvider.overrideWithValue(pins),
        pinApiProvider.overrideWithValue(PinsApi(client)),
        groupApiProvider.overrideWithValue(GroupsApi(client)),
        memberApiProvider.overrideWithValue(MembersApi(client)),
        userApiProvider.overrideWithValue(UsersApi(client)),
      ],
    );
    return fixture = _Fixture(
      action: action,
      database: database,
      container: container,
      apiClient: client,
      globalData: globalData,
      pauseMutation: pauseMutation,
      mutationStatus: mutationStatus,
      pinCacheWriteStarted: pinCacheWriteStarted,
      releasePinCacheWrite: releasePinCacheWrite,
    );
  }

  Future<void> prepare() async {
    final groups = container.listen(userGroupServiceProvider, (_, _) {});
    final xp = container.listen(userXpProvider('alice'), (_, _) {});
    final achievements = action == _Mutation.achievement
        ? container.listen(achievementsProvider, (_, _) {})
        : null;
    await container.read(userGroupServiceProvider.future);
    await container.read(userXpProvider('alice').future);
    if (action == _Mutation.achievement) {
      await container.read(achievementsProvider.future);
    }
    // Keep providers used by mutations alive as a visible page would.
    _subscriptions.addAll([groups, xp, if (achievements != null) achievements]);
  }

  Future<void> waitForPinUpload() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final rows = await database.select(database.pendingPinCreates).get();
      if (rows.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('The successful background upload did not clear its outbox row.');
  }

  Future<PendingPinCreateDb?> waitForPinUploadError() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      final row = await database
          .select(database.pendingPinCreates)
          .getSingleOrNull();
      if (row?.lastError != null) return row;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return database.select(database.pendingPinCreates).getSingleOrNull();
  }

  final _subscriptions = <ProviderSubscription<dynamic>>[];

  void keep(ProviderSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  Future<String?> performAction() => switch (action) {
    _Mutation.pin =>
      container
          .read(pinServiceProvider)
          .addPinToGroup(_draftPin(), Uint8List.fromList([1, 2, 3])),
    _Mutation.group =>
      container
          .read(userGroupServiceProvider.notifier)
          .createGroup(
            CreateGroupDto(
              description: '',
              name: 'New group',
              profileImage: '',
              visibility: 0,
              groupAdmin: 'alice',
              userId: 'alice',
            ),
          ),
    _Mutation.achievement =>
      container.read(achievementsProvider.notifier).claimAchievement(3),
  };

  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'GET' &&
        request.url.path == '/api/v2/groups/group-id/progression') {
      groupProgressionRequests++;
      if (groupProgressionRequests == 2 &&
          !secondGroupProgressionRequestStarted.isCompleted) {
        secondGroupProgressionRequestStarted.complete();
      }
      final totalXp = groupProgressionRequests == 1 ? 0 : 5;
      return http.Response(
        jsonEncode({
          'groupId': 'group-id',
          'totalXp': totalXp,
          'currentLevel': 1,
          'currentLevelXp': totalXp,
          'nextLevelXp': 50,
        }),
        200,
      );
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v2/users/alice/xp') {
      xpRequests++;
      if (xpRequests == 2 && !secondXpRequestStarted.isCompleted) {
        secondXpRequestStarted.complete();
      }
      final totalXp = xpRequests == 1 ? 0 : 25;
      return http.Response(
        jsonEncode({
          'totalXp': totalXp,
          'currentLevel': totalXp == 0 ? 1 : 2,
          'currentLevelXp': totalXp,
          'nextLevelXp': totalXp == 0 ? 25 : 75,
        }),
        200,
      );
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v2/users/alice/achievements') {
      return http.Response(
        jsonEncode([
          {
            'achievementId': 3,
            'claimed': false,
            'thresholdValue': 1,
            'currentValue': 1,
            'thresholdUp': true,
          },
        ]),
        200,
      );
    }
    if (_isMutationRequest(request)) {
      if (!mutationRequestStarted.isCompleted) {
        mutationRequestStarted.complete();
      }
      if (pauseMutation) return mutationResponse.future;
      return _mutationResponse(mutationStatus);
    }
    return http.Response('Not found', 404);
  }

  bool _isMutationRequest(http.Request request) => switch (action) {
    _Mutation.pin =>
      request.method == 'POST' && request.url.path == '/api/v2/pins',
    _Mutation.group =>
      request.method == 'POST' && request.url.path == '/api/v2/groups',
    _Mutation.achievement =>
      request.method == 'POST' &&
          request.url.path == '/api/v2/users/alice/achievements/3',
  };

  http.Response _mutationResponse(int status) {
    if (status >= 400) return http.Response('Unavailable', status);
    return switch (action) {
      _Mutation.pin => http.Response(
        jsonEncode({
          'id': 'created-pin',
          'creationDate': '2026-01-01T00:00:00Z',
          'latitude': 1.0,
          'longitude': 2.0,
          'creationUser': 'alice',
          'groupId': 'group-id',
        }),
        status,
      ),
      _Mutation.group => http.Response(
        jsonEncode({
          'id': 'created-group',
          'name': 'New group',
          'visibility': 0,
        }),
        status,
      ),
      _Mutation.achievement => http.Response('', status),
    };
  }

  void completeMutationSuccess() =>
      mutationResponse.complete(_mutationResponse(200));

  Future<void> dispose() async {
    if (!releasePinCacheWrite.isCompleted) releasePinCacheWrite.complete();
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    container.dispose();
    apiClient.client.close();
    await database.close();
  }
}

class _DelayedPinRepository extends PinRepository {
  _DelayedPinRepository(super.db, this.started, this.release);

  final Completer<void> started;
  final Completer<void> release;

  @override
  Future<void> put(PinEntity item) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.put(item);
  }
}

GlobalDataDto _globalData(String userId, String refreshToken) => GlobalDataDto(
  userId: userId,
  refreshToken: refreshToken,
  cameras: const [],
);

PinEntity _draftPin() => PinEntity(
  pinId: 'draft-pin',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creator: 'alice',
  groupId: 'group-id',
  ttl: DateTime.utc(2099),
  onlySession: false,
);

class _SwitchableGlobalDataService extends GlobalDataService {
  void switchTo(GlobalDataDto data) {
    storageSession.revoke();
    storageSession = AccountSession(data.refreshToken?.isNotEmpty == true);
    state = data;
  }
}
