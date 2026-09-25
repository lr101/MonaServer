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
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';

void main() {
  for (final action in _Mutation.values) {
    test('${action.label} refreshes XP', () async {
      final fixture = await _Fixture.create(action);
      addTearDown(fixture.dispose);
      await fixture.prepare();

      expect(await fixture.performAction(), isNull);
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
    });

    test('${action.label} API failure does not refresh XP', () async {
      final fixture = await _Fixture.create(action, mutationStatus: 503);
      addTearDown(fixture.dispose);
      await fixture.prepare();

      expect(await fixture.performAction(), isNotNull);
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
  });

  final _Mutation action;
  final AppDatabase database;
  final ProviderContainer container;
  final ApiClient apiClient;
  final _SwitchableGlobalDataService globalData;
  final bool pauseMutation;
  final int mutationStatus;
  final mutationRequestStarted = Completer<void>();
  final secondXpRequestStarted = Completer<void>();
  final mutationResponse = Completer<http.Response>();
  int xpRequests = 0;

  static Future<_Fixture> create(
    _Mutation action, {
    bool pauseMutation = false,
    int mutationStatus = 200,
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(database);
    final pins = PinRepository(database);
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
    );
  }

  Future<void> prepare() async {
    final groups = container.listen(userGroupServiceProvider, (_, _) {});
    final xp = container.listen(userXpProvider('alice'), (_, _) {});
    await container.read(userGroupServiceProvider.future);
    await container.read(userXpProvider('alice').future);
    if (action == _Mutation.achievement) {
      await container.read(achievementsProvider.future);
    }
    // These subscriptions are held until dispose so mutation invalidations
    // rebuild the existing XP provider instead of relying on auto-disposal.
    _subscriptions.addAll([groups, xp]);
  }

  final _subscriptions = <ProviderSubscription<dynamic>>[];

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
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    container.dispose();
    apiClient.client.close();
    await database.close();
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
