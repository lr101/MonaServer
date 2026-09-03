import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'fetches pins for the requested user when the current user has cached pins',
    () async {
      final repository = FakePinRepository({
        'current-user': [_pin('current-pin', 'current-user')],
        'profile-user': [],
      });
      final api = RecordingPinsApi();
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('current-user'),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      container.listen(pinUserServiceProvider('profile-user'), (_, _) {});

      await expectLater(
        api.requestStarted.future.timeout(const Duration(milliseconds: 100)),
        completes,
      );
      expect(api.requestedUserId, 'profile-user');
    },
  );

  test(
    'fetches public group pins when the group pin provider is loaded',
    () async {
      final repository = FakePinRepository({});
      final api = RecordingPinsApi();
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        pinGroupServiceUnfilteredProvider('group'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await api.requestStarted.future.timeout(
        const Duration(milliseconds: 100),
      );

      expect(api.requestedGroupId, 'group');
      expect(api.requestedUserId, isNull);
    },
  );

  test(
    'refreshes cached public group pins when the provider is loaded',
    () async {
      final repository = FakePinRepository(
        {},
        pinsByGroup: {
          'group': [
            _pin('cached-pin', 'creator', lastSynced: DateTime.utc(2024, 1, 1)),
          ],
        },
      );
      final api = RecordingPinsApi();
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        pinGroupServiceUnfilteredProvider('group'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await api.requestStarted.future.timeout(
        const Duration(milliseconds: 100),
      );

      expect(api.requestedGroupId, 'group');
      expect(api.requestedUpdatedAfter, DateTime.utc(2024, 1, 1));
    },
  );

  test('keeps cached public group pins when refresh fails', () async {
    final repository = FakePinRepository(
      {},
      pinsByGroup: {
        'group': [
          _pin('cached-pin', 'creator', lastSynced: DateTime.utc(2024, 1, 1)),
        ],
      },
    );
    final api = RecordingPinsApi(error: StateError('offline'));
    final container = ProviderContainer(
      overrides: [
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        pinRepositoryProvider.overrideWithValue(repository),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      pinGroupServiceUnfilteredProvider('group'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final pins = await container.read(
      pinGroupServiceUnfilteredProvider('group').future,
    );
    await api.requestStarted.future.timeout(const Duration(milliseconds: 100));
    await Future<void>.delayed(Duration.zero);

    expect(pins.map((pin) => pin.pinId), ['cached-pin']);
    expect(
      container.read(pinGroupServiceUnfilteredProvider('group')).hasError,
      isFalse,
    );
  });

  test('applies deleted public group pins during a lazy refresh', () async {
    final repository = FakePinRepository(
      {},
      pinsByGroup: {
        'group': [
          _pin('cached-pin', 'creator', lastSynced: DateTime.utc(2024, 1, 1)),
        ],
      },
    );
    final api = RecordingPinsApi(
      response: PinsSyncDto(deleted: ['deleted-pin']),
    );
    final container = ProviderContainer(
      overrides: [
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        pinRepositoryProvider.overrideWithValue(repository),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      pinGroupServiceUnfilteredProvider('group'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await repository.deleteStarted.future.timeout(
      const Duration(milliseconds: 100),
    );

    expect(repository.deletedIds, ['deleted-pin']);
  });

  test('refreshes group pins even when the group is joined', () async {
    final groupUpdates = StreamController<List<GroupEntity>>();
    addTearDown(groupUpdates.close);
    final remoteResponse = Completer<PinsSyncDto?>();
    final repository = FakePinRepository({});
    final api = RecordingPinsApi(responseOverride: () => remoteResponse.future);
    final container = ProviderContainer(
      overrides: [
        userGroupServiceProvider.overrideWith(
          () => _ControllableUserGroupService(groupUpdates.stream),
        ),
        pinRepositoryProvider.overrideWithValue(repository),
        pinApiProvider.overrideWithValue(api),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      pinGroupServiceUnfilteredProvider('group'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await api.requestStarted.future.timeout(const Duration(milliseconds: 100));
    groupUpdates.add([_joinedGroup()]);
    await Future<void>.delayed(Duration.zero);
    remoteResponse.complete(
      PinsSyncDto(
        items: [
          PinWithOptionalImageDto(
            id: 'remote-pin',
            creationDate: DateTime(2024),
            latitude: 0.0,
            longitude: 0.0,
            creationUser: 'creator',
            groupId: 'group',
            description: null,
          ),
        ],
      ),
    );
    await repository.putStarted.future.timeout(
      const Duration(milliseconds: 100),
    );

    expect(repository.putItems.single.pinId, 'remote-pin');
    expect(repository.putItems.single.keepAlive, isTrue);
    expect(repository.putItems.single.onlySession, isFalse);
  });

  test(
    'loads unjoined group pins without waiting for a membership snapshot',
    () async {
      final groupUpdates = StreamController<List<GroupEntity>>();
      addTearDown(groupUpdates.close);
      final repository = FakePinRepository({});
      final api = RecordingPinsApi(
        response: PinsSyncDto(items: [_remotePin()]),
      );
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(
            () => _ControllableUserGroupService(groupUpdates.stream),
          ),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        pinGroupServiceUnfilteredProvider('group'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await repository.putStarted.future.timeout(
        const Duration(milliseconds: 100),
      );

      expect(repository.putItems.single.keepAlive, isFalse);
      expect(repository.putItems.single.onlySession, isTrue);
    },
  );

  test('publishes fetched unjoined pins to the group tab provider', () async {
    final repository = _LivePinRepository();
    final api = RecordingPinsApi(response: PinsSyncDto(items: [_remotePin()]));
    final container = ProviderContainer(
      overrides: [
        userGroupServiceProvider.overrideWith(
          () => _ControllableUserGroupService(const Stream.empty()),
        ),
        pinRepositoryProvider.overrideWithValue(repository),
        pinApiProvider.overrideWithValue(api),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repository.close);

    final fetchedPins = Completer<List<PinEntity>>();
    final subscription = container.listen(pinGroupServiceProvider('group'), (
      _,
      next,
    ) {
      final pins = next.value;
      if (pins != null && pins.isNotEmpty && !fetchedPins.isCompleted) {
        fetchedPins.complete(pins);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    await api.requestStarted.future.timeout(const Duration(milliseconds: 100));
    await repository.putStarted.future.timeout(
      const Duration(milliseconds: 100),
    );
    await repository.putCompleted.future.timeout(
      const Duration(milliseconds: 100),
    );
    final pins = await fetchedPins.future.timeout(
      const Duration(milliseconds: 100),
    );

    expect(pins.single.pinId, 'remote-pin');
    expect(pins.single.onlySession, isTrue);
  });

  test(
    'promotes cached pins when membership arrives after a public refresh',
    () async {
      final groupUpdates = StreamController<List<GroupEntity>>();
      addTearDown(groupUpdates.close);
      final repository = _LivePinRepository();
      var requestCount = 0;
      final api = RecordingPinsApi(
        responseOverride: () async {
          requestCount++;
          return requestCount == 1
              ? PinsSyncDto(items: [_remotePin()])
              : PinsSyncDto();
        },
      );
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(
            () => _ControllableUserGroupService(groupUpdates.stream),
          ),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repository.close);

      final subscription = container.listen(
        pinGroupServiceUnfilteredProvider('group'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await repository.putCompleted.future.timeout(
        const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.keepAliveUpdateStarted.isCompleted, isFalse);

      groupUpdates.add([_joinedGroup()]);
      await repository.keepAliveUpdateStarted.future.timeout(
        const Duration(milliseconds: 100),
      );

      expect(repository.promotedKeepAlive, isTrue);
      expect(repository.promotedOnlySession, isFalse);
    },
  );

  test(
    'promotes pins when the group joins during a public refresh write',
    () async {
      final groupUpdates = StreamController<List<GroupEntity>>();
      addTearDown(groupUpdates.close);
      final repository = FakePinRepository(
        {},
        onPutMultiple: () async {
          groupUpdates.add([_joinedGroup()]);
          await Future<void>.delayed(Duration.zero);
        },
      );
      final api = RecordingPinsApi(
        response: PinsSyncDto(items: [_remotePin()]),
      );
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(
            () => _ControllableUserGroupService(groupUpdates.stream),
          ),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        pinGroupServiceUnfilteredProvider('group'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await api.requestStarted.future.timeout(
        const Duration(milliseconds: 100),
      );
      groupUpdates.add([]);
      await repository.keepAliveUpdateStarted.future.timeout(
        const Duration(milliseconds: 100),
      );

      expect(repository.promotedKeepAlive, isTrue);
      expect(repository.promotedOnlySession, isFalse);
    },
  );
}

PinEntity _pin(String pinId, String creator, {DateTime? lastSynced}) {
  return PinEntity(
    pinId: pinId,
    latitude: 0,
    longitude: 0,
    creationDate: DateTime(2024),
    creator: creator,
    groupId: 'group',
    lastSynced: lastSynced,
    ttl: DateTime(2024),
    onlySession: false,
  );
}

class RecordingPinsApi extends PinsApi {
  RecordingPinsApi({this.response, this.error, this.responseOverride})
    : super(ApiClient());

  final requestStarted = Completer<void>();
  String? requestedUserId;
  String? requestedGroupId;
  DateTime? requestedUpdatedAfter;
  final PinsSyncDto? response;
  final Object? error;
  final Future<PinsSyncDto?> Function()? responseOverride;

  @override
  Future<PinsSyncDto?> getPinImagesByIds({
    List<String>? ids,
    String? groupId,
    String? userId,
    bool? withImage,
    int? compression,
    int? height,
    int? page,
    int? size,
    DateTime? updatedAfter,
  }) async {
    requestedUserId = userId;
    requestedGroupId = groupId;
    requestedUpdatedAfter = updatedAfter;
    if (!requestStarted.isCompleted) requestStarted.complete();
    if (error != null) throw error!;
    if (responseOverride != null) return responseOverride!();
    return response ?? PinsSyncDto();
  }
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _ControllableUserGroupService extends UserGroupService {
  _ControllableUserGroupService(this._groups);

  final Stream<List<GroupEntity>> _groups;

  @override
  Stream<List<GroupEntity>> build() => _groups;
}

GroupEntity _joinedGroup() => GroupEntity(
  groupId: 'group',
  name: 'Joined group',
  visibility: 0,
  userIsMember: true,
  keepAlive: true,
  ttl: DateTime(2024),
  onlySession: false,
);

PinWithOptionalImageDto _remotePin() => PinWithOptionalImageDto(
  id: 'remote-pin',
  creationDate: DateTime(2024),
  latitude: 0.0,
  longitude: 0.0,
  creationUser: 'creator',
  groupId: 'group',
);

class _LivePinRepository extends FakePinRepository {
  _LivePinRepository() : super({}, pinsByGroup: {});

  final _groupStreams = <String, StreamController<List<PinEntity>>>{};
  final putCompleted = Completer<void>();

  @override
  Stream<List<PinEntity>> getPinsByGroup(String groupId) {
    final updates = _groupStreams.putIfAbsent(
      groupId,
      () => StreamController<List<PinEntity>>.broadcast(),
    );
    return Stream.multi((controller) {
      controller.add(List.of(pinsByGroup[groupId] ?? const []));
      final subscription = updates.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<void> putMultiple(List<PinEntity> items) async {
    await super.putMultiple(items);
    for (final item in items) {
      (pinsByGroup[item.groupId] ??= []).add(item);
    }
    for (final item in items) {
      _groupStreams[item.groupId]?.add(
        List.of(pinsByGroup[item.groupId] ?? const []),
      );
    }
    if (!putCompleted.isCompleted) putCompleted.complete();
  }

  Future<void> close() async {
    for (final stream in _groupStreams.values) {
      await stream.close();
    }
  }
}

class FakePinRepository implements IPinRepository {
  FakePinRepository(
    this._pinsByUser, {
    this.pinsByGroup = const {},
    this.onPutMultiple,
  });

  final Map<String, List<PinEntity>> _pinsByUser;
  final Map<String, List<PinEntity>> pinsByGroup;
  final Future<void> Function()? onPutMultiple;
  final List<String> deletedIds = [];
  final List<PinEntity> putItems = [];
  final deleteStarted = Completer<void>();
  final putStarted = Completer<void>();
  final keepAliveUpdateStarted = Completer<void>();
  bool? promotedKeepAlive;
  bool? promotedOnlySession;

  @override
  Stream<List<PinEntity>> getPinsByUser(String userId) {
    return Stream.value(List.of(_pinsByUser[userId] ?? const []));
  }

  @override
  Future<void> putMultiple(List<PinEntity> items) async {
    putItems.addAll(items);
    if (!putStarted.isCompleted) putStarted.complete();
    for (final item in items) {
      (_pinsByUser[item.creator] ??= []).add(item);
    }
    await onPutMultiple?.call();
  }

  @override
  Future<void> put(PinEntity item) async {
    (_pinsByUser[item.creator] ??= []).add(item);
  }

  @override
  Stream<PinEntity?> watchById(String id) => Stream.value(null);

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    deletedIds.addAll(ids);
    if (!deleteStarted.isCompleted) deleteStarted.complete();
  }

  @override
  Future<PinEntity?> get(String id) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<PinEntity>> getAll() async =>
      _pinsByUser.values.expand((e) => e).toList();

  @override
  Future<List<PinEntity?>> getList(List<String> ids) async => [];

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Stream<List<PinEntity>> getPinsByGroup(String groupId) =>
      Stream.value(List.of(pinsByGroup[groupId] ?? const []));

  @override
  Future<void> deleteByGroupId(String groupId) async {}

  @override
  Future<void> replacePin(String oldPinId, PinEntity newPin) async {}

  @override
  Future<void> updateKeepAlive(
    String groupId,
    bool keepAlive,
    bool onlySession,
  ) async {
    promotedKeepAlive = keepAlive;
    promotedOnlySession = onlySession;
    if (!keepAliveUpdateStarted.isCompleted) {
      keepAliveUpdateStarted.complete();
    }
  }
}
