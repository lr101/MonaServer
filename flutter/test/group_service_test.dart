import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'unjoined group details do not wait for the user group stream',
    () async {
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(
            _UserGroupServiceWithoutInitialValue.new,
          ),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(
            _FakeGroupsApi(_groupWithoutImages()),
          ),
          pinGroupServiceProvider('group-id')
              .overrideWith((ref) => Future.value(<PinEntity>[])),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        groupDetailsProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final details = await container
          .read(groupDetailsProvider('group-id').future)
          .timeout(const Duration(milliseconds: 100));

      expect(details.group?.groupId, 'group-id');
      expect(details.group?.userIsMember, isFalse);
    },
  );

  test(
    'unjoined private group details do not wait for the user group stream',
    () async {
      final container = ProviderContainer(
        overrides: [
          userGroupServiceProvider.overrideWith(
            _UserGroupServiceWithoutInitialValue.new,
          ),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(
            _FakeGroupsApi(_privateGroupWithoutImages()),
          ),
          pinGroupServiceProvider('group-id')
              .overrideWith((ref) => Future.value(<PinEntity>[])),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        groupDetailsProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final details = await container
          .read(groupDetailsProvider('group-id').future)
          .timeout(const Duration(milliseconds: 100));

      expect(details.group?.groupId, 'group-id');
      expect(details.group?.visibility, 1);
      expect(details.group?.userIsMember, isFalse);
    },
  );

  test(
    'shared group details expose metadata without waiting for pins or media',
    () async {
      final pendingPins = Completer<List<PinEntity>>();
      final pendingProfile = StreamController<Uint8List?>();
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(
            _FakeGroupsApi(_groupWithImages()),
          ),
          pinGroupServiceProvider('group-id')
              .overrideWith((ref) => pendingPins.future),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => pendingProfile.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() {
        if (!pendingPins.isCompleted) pendingPins.complete([]);
        if (!pendingProfile.isClosed) pendingProfile.close();
      });

      final subscription = container.listen(
        groupDetailsProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final details = await container
          .read(groupDetailsProvider('group-id').future)
          .timeout(const Duration(milliseconds: 100));

      expect(details.group?.groupId, 'group-id');
      expect(details.pins.isLoading, isTrue);
      expect(details.mediaStatus, GroupMediaStatus.loading);
    },
  );

  test(
    'watching group metadata does not start an untracked network request',
    () async {
      final groupsApi = _FakeGroupsApi(_groupWithImages());
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(groupsApi),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        groupServiceProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(groupsApi.getRequests, 0);
    },
  );

  test(
    'shared group details replays data when dependencies are already warm',
    () async {
      final group = GroupEntity(
        groupId: 'group-id',
        name: 'Group',
        visibility: 0,
        userIsMember: false,
        ttl: DateTime.now(),
        onlySession: true,
      );
      final pins = [
        PinEntity(
          pinId: 'pin-id',
          latitude: 0,
          longitude: 0,
          creationDate: DateTime(2025),
          creator: 'user-id',
          groupId: 'group-id',
          ttl: DateTime.now(),
          onlySession: true,
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          groupMetadataProvider('group-id')
              .overrideWith((ref) => Stream.value(group)),
          pinGroupServiceProvider('group-id')
              .overrideWith((ref) => Future.value(pins)),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream.value(Uint8List.fromList([1]))),
        ],
      );
      addTearDown(container.dispose);

      final metadataSubscription = container.listen(
        groupMetadataProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      final pinsSubscription = container.listen(
        pinGroupServiceProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      final profileSubscription = container.listen(
        groupProfilePictureByIdProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(metadataSubscription.close);
      addTearDown(pinsSubscription.close);
      addTearDown(profileSubscription.close);

      await container.read(groupMetadataProvider('group-id').future);
      await container.read(pinGroupServiceProvider('group-id').future);
      await container.read(groupProfilePictureByIdProvider('group-id').future);

      final states = <GroupDetailsState>[];
      final detailsSubscription = container.listen(
        groupDetailsProvider('group-id'),
        (_, next) {
          if (next.hasValue) states.add(next.value!);
        },
        fireImmediately: true,
      );
      addTearDown(detailsSubscription.close);
      final details = await container
          .read(groupDetailsProvider('group-id').future)
          .timeout(const Duration(milliseconds: 100));

      expect(details.group?.groupId, 'group-id');
      await Future<void>.delayed(Duration.zero);
      expect(states.last.pins.value, pins);
      expect(states.last.profileImage.value, isNotNull);
    },
  );

  test('shared group pin state remains newest-first', () async {
    final older = PinEntity(
      pinId: 'older',
      latitude: 0,
      longitude: 0,
      creationDate: DateTime(2024),
      creator: 'user-id',
      groupId: 'group-id',
      ttl: DateTime.now(),
      onlySession: true,
    );
    final newer = PinEntity(
      pinId: 'newer',
      latitude: 0,
      longitude: 0,
      creationDate: DateTime(2025),
      creator: 'user-id',
      groupId: 'group-id',
      ttl: DateTime.now(),
      onlySession: true,
    );
    final container = ProviderContainer(
      overrides: [
        groupDetailsProvider('group-id').overrideWith(
          (ref) => Stream.value(
            GroupDetailsState(
              group: null,
              pins: AsyncData([older, newer]),
              profileImage: const AsyncData(null),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      groupDetailsPinsProvider('group-id'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(groupDetailsPinsProvider('group-id'))
          .value
          ?.map((pin) => pin.pinId),
      ['newer', 'older'],
    );
  });

  test(
    'metadata requests are explicit and return the canonical group entity',
    () async {
      final groupsApi = _FakeGroupsApi(_groupWithImages());
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(groupsApi),
        ],
      );
      addTearDown(container.dispose);

      final metadataStates = <GroupEntity?>[];
      final metadataSubscription = container.listen(
        groupMetadataProvider('group-id'),
        (_, next) {
          if (next.hasValue) metadataStates.add(next.value);
        },
        fireImmediately: true,
      );
      addTearDown(metadataSubscription.close);

      final group = await container.read(
        groupMetadataProvider('group-id').future,
      );

      expect(group?.groupId, 'group-id');
      expect(groupsApi.getRequests, 1);
      expect(metadataStates, hasLength(1));
    },
  );

  test(
    'emits a terminal empty value when group metadata is unavailable',
    () async {
      final groupsApi = _FakeGroupsApi(null);
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          groupApiProvider.overrideWithValue(groupsApi),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        groupMetadataProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final group = await container.read(
        groupMetadataProvider('group-id').future,
      );

      expect(group, isNull);
      expect(groupsApi.getRequests, 1);
    },
  );

  test(
    'removes a stale session-only group when metadata is unavailable',
    () async {
      final groupRepository = _FakeGroupRepository();
      await groupRepository.put(
        GroupEntity(
          groupId: 'group-id',
          name: 'Stale group',
          visibility: 0,
          userIsMember: false,
          ttl: DateTime(2025),
          onlySession: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          groupApiProvider.overrideWithValue(_FakeGroupsApi(null)),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        groupMetadataProvider('group-id'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final group = await container.read(
        groupMetadataProvider('group-id').future,
      );

      expect(group, isNull);
      expect(await groupRepository.get('group-id'), isNull);
    },
  );

  test('joins a group with one pin synchronization request', () async {
    final pinsApi = _FakePinsApi();
    final service = await _createService(
      membersApi: _FakeMembersApi(_groupWithImages()),
      pinsApi: pinsApi,
    );

    final result = await service.joinGroup('group-id');

    expect(result, isNull);
    expect(pinsApi.requests, 1);
  });

  test('prefetches joined group media after joining completes', () async {
    final profileCache = _FakeImageRepository.pending();
    final profileSmallCache = _FakeImageRepository.pending();
    final pinImageCache = _FakeImageRepository.pending();
    final service = await _createService(
      membersApi: _FakeMembersApi(_groupWithImages()),
      profileCache: profileCache,
      profileSmallCache: profileSmallCache,
      pinImageCache: pinImageCache,
    );
    var completed = false;

    final join = service.joinGroup('group-id').then((_) => completed = true);
    await _nextEventLoop();

    expect(profileCache.overrideIds, ['group-id']);
    expect(profileSmallCache.overrideIds, ['group-id']);
    expect(pinImageCache.overrideIds, ['group-id']);
    expect(completed, isTrue);

    profileCache.complete();
    await _nextEventLoop();
    profileSmallCache.complete();
    await _nextEventLoop();
    pinImageCache.complete();
    await join;
    expect(completed, isTrue);
  });

  test('joining a group does not wait for background media prefetch', () async {
    final profileCache = _FakeImageRepository.pending();
    final profileSmallCache = _FakeImageRepository.pending();
    final pinImageCache = _FakeImageRepository.pending();
    final service = await _createService(
      membersApi: _FakeMembersApi(_groupWithImages()),
      profileCache: profileCache,
      profileSmallCache: profileSmallCache,
      pinImageCache: pinImageCache,
    );

    final result = await service
        .joinGroup('group-id')
        .timeout(const Duration(milliseconds: 100));

    expect(result, isNull);
    expect(profileCache.overrideIds, ['group-id']);
    expect(profileSmallCache.overrideIds, ['group-id']);
    expect(pinImageCache.overrideIds, ['group-id']);

    profileCache.complete();
    profileSmallCache.complete();
    pinImageCache.complete();
  });

  test(
    'background media prefetch limits work to one group at a time',
    () async {
      final profileCache = _FakeImageRepository.pending();
      final profileSmallCache = _FakeImageRepository.pending();
      final pinImageCache = _FakeImageRepository.pending();
      final trigger = Provider.family<void, GroupDto>((ref, group) {
        prefetchGroupMediaInBackground(ref, group, keepAlive: true);
      });
      final container = ProviderContainer(
        overrides: [
          groupProfileRepoProvider.overrideWithValue(profileCache),
          groupProfileSmallRepoProvider.overrideWithValue(profileSmallCache),
          groupPinImageRepoProvider.overrideWithValue(pinImageCache),
        ],
      );
      addTearDown(container.dispose);

      container.read(trigger(_groupWithImages(id: 'group-1')));
      container.read(trigger(_groupWithImages(id: 'group-2')));
      await Future<void>.delayed(Duration.zero);

      expect(profileCache.overrideIds, ['group-1']);
      expect(profileSmallCache.overrideIds, ['group-1']);
      expect(pinImageCache.overrideIds, ['group-1']);

      profileCache.complete();
      profileSmallCache.complete();
      pinImageCache.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(profileCache.overrideIds, ['group-1', 'group-2']);
      expect(profileSmallCache.overrideIds, ['group-1', 'group-2']);
      expect(pinImageCache.overrideIds, ['group-1', 'group-2']);
    },
  );

  test('prefetches group media after an update completes', () async {
    final profileCache = _FakeImageRepository.pending();
    final profileSmallCache = _FakeImageRepository.pending();
    final pinImageCache = _FakeImageRepository.pending();
    final service = await _createService(
      groupsApi: _FakeGroupsApi(_groupWithImages()),
      profileCache: profileCache,
      profileSmallCache: profileSmallCache,
      pinImageCache: pinImageCache,
    );
    var completed = false;

    final update = service
        .updateGroup(UpdateGroupDto(name: 'Updated'), 'group-id')
        .then((_) => completed = true);
    await _nextEventLoop();

    expect(profileCache.overrideIds, ['group-id']);
    expect(profileSmallCache.overrideIds, ['group-id']);
    expect(pinImageCache.overrideIds, ['group-id']);
    expect(completed, isTrue);

    profileCache.complete();
    await _nextEventLoop();
    profileSmallCache.complete();
    await _nextEventLoop();
    pinImageCache.complete();
    await update;
    expect(completed, isTrue);
  });

  test('joins a group without image URLs', () async {
    final profileCache = _FakeImageRepository();
    final profileSmallCache = _FakeImageRepository();
    final pinImageCache = _FakeImageRepository();
    final service = await _createService(
      membersApi: _FakeMembersApi(_groupWithoutImages()),
      profileCache: profileCache,
      profileSmallCache: profileSmallCache,
      pinImageCache: pinImageCache,
    );

    final result = await service.joinGroup('group-id');

    expect(result, isNull);
    expect(profileCache.overrideIds, isEmpty);
    expect(profileSmallCache.overrideIds, isEmpty);
    expect(pinImageCache.overrideIds, isEmpty);
  });

  test('does not fail a group synchronization when background media prefetch fails', () async {
    final service = await _createService(
      membersApi: _FakeMembersApi(_groupWithImages()),
      profileCache: _FakeImageRepository.failure(
        Exception('cache write failed'),
      ),
    );

    final result = await service.joinGroup('group-id');

    expect(result, isNull);
  });

  test(
    'hydrates an unjoined public group without synchronizing pins',
    () async {
      final groupRepository = _FakeGroupRepository();
      final pinRepository = _FakePinRepository();
      final groupsApi = _FakeGroupsApi(_groupWithImages());
      final pinsApi = _FakePinsApi();
      final profileCache = _FakeImageRepository();
      final profileSmallCache = _FakeImageRepository();
      final pinImageCache = _FakeImageRepository();
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          pinRepositoryProvider.overrideWithValue(pinRepository),
          groupApiProvider.overrideWithValue(groupsApi),
          pinApiProvider.overrideWithValue(pinsApi),
          groupProfileRepoProvider.overrideWithValue(profileCache),
          groupProfileSmallRepoProvider.overrideWithValue(profileSmallCache),
          groupPinImageRepoProvider.overrideWithValue(pinImageCache),
        ],
      );
      addTearDown(container.dispose);
      final userGroupsSubscription = container.listen(
        userGroupServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(userGroupsSubscription.close);
      await container.read(userGroupServiceProvider.future);

      final readyProvider = groupDetailsReadyProvider('group-id');
      final readySubscription = container.listen(
        readyProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(readySubscription.close);
      final group = await container
          .read(readyProvider.future)
          .timeout(const Duration(milliseconds: 100));

      expect(group?.groupId, 'group-id');
      expect(group?.onlySession, isTrue);
      expect(group?.userIsMember, isFalse);
      expect(groupsApi.getRequests, 1);
      expect(pinsApi.requests, 0);
      expect(pinRepository.putItems, isEmpty);
      expect(profileCache.overrideIds, isEmpty);
      expect(profileSmallCache.overrideIds, isEmpty);
      expect(pinImageCache.overrideIds, isEmpty);
    },
  );

  test(
    'does not wait for public pin synchronization before detail readiness',
    () async {
      final releasePins = Completer<PinsSyncDto?>();
      final pinsApi = _FakePinsApi(getPinsOverride: () => releasePins.future);
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
          pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
          groupApiProvider.overrideWithValue(
            _FakeGroupsApi(_groupWithImages()),
          ),
          pinApiProvider.overrideWithValue(pinsApi),
          groupProfileRepoProvider.overrideWithValue(_FakeImageRepository()),
          groupProfileSmallRepoProvider.overrideWithValue(
            _FakeImageRepository(),
          ),
          groupPinImageRepoProvider.overrideWithValue(_FakeImageRepository()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(() {
        if (!releasePins.isCompleted) releasePins.complete(PinsSyncDto());
      });

      final userGroupsSubscription = container.listen(
        userGroupServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(userGroupsSubscription.close);
      await container.read(userGroupServiceProvider.future);

      final readyProvider = groupDetailsReadyProvider('group-id');
      final readySubscription = container.listen(
        readyProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(readySubscription.close);

      final group = await container
          .read(readyProvider.future)
          .timeout(const Duration(milliseconds: 100));

      expect(group?.groupId, 'group-id');
      expect(pinsApi.requests, 0);
    },
  );

  test('does not prefetch public images during detail hydration', () async {
    final profileCache = _FakeImageRepository.pending();
    final profileSmallCache = _FakeImageRepository.pending();
    final pinImageCache = _FakeImageRepository.pending();
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('user-id'),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
        pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
        groupApiProvider.overrideWithValue(_FakeGroupsApi(_groupWithImages())),
        pinApiProvider.overrideWithValue(_FakePinsApi()),
        groupProfileRepoProvider.overrideWithValue(profileCache),
        groupProfileSmallRepoProvider.overrideWithValue(profileSmallCache),
        groupPinImageRepoProvider.overrideWithValue(pinImageCache),
      ],
    );
    addTearDown(container.dispose);

    final userGroupsSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(userGroupsSubscription.close);
    await container.read(userGroupServiceProvider.future);

    final readyProvider = groupDetailsReadyProvider('group-id');
    final readySubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(readySubscription.close);

    final group = await container
        .read(readyProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(group?.groupId, 'group-id');
    expect(profileCache.overrideIds, isEmpty);
    expect(profileSmallCache.overrideIds, isEmpty);
    expect(pinImageCache.overrideIds, isEmpty);
  });

  test(
    'does not prefetch joined group images during detail hydration',
    () async {
      final groupRepository = _FakeGroupRepository();
      await groupRepository.put(
        GroupEntity(
          groupId: 'group-id',
          name: 'Cached group',
          visibility: 0,
          userIsMember: true,
          ttl: DateTime(2025),
          onlySession: true,
        ),
      );
      final profileCache = _FakeImageRepository.pending();
      final profileSmallCache = _FakeImageRepository.pending();
      final pinImageCache = _FakeImageRepository.pending();
      final groupsApi = _FakeGroupsApi(_groupWithImages());
      final pinsApi = _FakePinsApi();
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('user-id'),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
          groupApiProvider.overrideWithValue(groupsApi),
          pinApiProvider.overrideWithValue(pinsApi),
          groupProfileRepoProvider.overrideWithValue(profileCache),
          groupProfileSmallRepoProvider.overrideWithValue(profileSmallCache),
          groupPinImageRepoProvider.overrideWithValue(pinImageCache),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(profileCache.complete);
      addTearDown(profileSmallCache.complete);
      addTearDown(pinImageCache.complete);

      final userGroupsSubscription = container.listen(
        userGroupServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(userGroupsSubscription.close);
      await container.read(userGroupServiceProvider.future);

      final readyProvider = groupDetailsReadyProvider('group-id');
      final readySubscription = container.listen(
        readyProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(readySubscription.close);

      final group = await container
          .read(readyProvider.future)
          .timeout(const Duration(milliseconds: 100));

      expect(group?.userIsMember, isTrue);
      expect(groupsApi.getRequests, 1);
      expect(pinsApi.requests, 0);
      expect(profileCache.overrideIds, isEmpty);
      expect(profileSmallCache.overrideIds, isEmpty);
      expect(pinImageCache.overrideIds, isEmpty);
    },
  );

  test('refreshes a cached session-only group when its details open', () async {
    final groupRepository = _FakeGroupRepository();
    await groupRepository.put(
      GroupEntity(
        groupId: 'group-id',
        name: 'Cached group',
        visibility: 0,
        userIsMember: false,
        ttl: DateTime(2025),
        onlySession: true,
      ),
    );
    final groupsApi = _FakeGroupsApi(
      GroupDto(id: 'group-id', name: 'Remote group', visibility: 0),
    );
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('user-id'),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupRepositoryProvider.overrideWithValue(groupRepository),
        pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
        groupApiProvider.overrideWithValue(groupsApi),
        pinApiProvider.overrideWithValue(_FakePinsApi()),
        groupProfileRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupProfileSmallRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupPinImageRepoProvider.overrideWithValue(_FakeImageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final userGroupsSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(userGroupsSubscription.close);
    await container.read(userGroupServiceProvider.future);

    final readyProvider = groupDetailsReadyProvider('group-id');
    final readySubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(readySubscription.close);
    final group = await container
        .read(readyProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(group?.name, 'Remote group');
    expect(groupsApi.getRequests, 1);
  });

  test('refreshes details when the route is opened again', () async {
    final groupsApi = _FakeGroupsApi(_groupWithoutImages());
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('user-id'),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
        pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
        groupApiProvider.overrideWithValue(groupsApi),
        pinApiProvider.overrideWithValue(_FakePinsApi()),
        groupProfileRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupProfileSmallRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupPinImageRepoProvider.overrideWithValue(_FakeImageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final userGroupsSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(userGroupsSubscription.close);
    await container.read(userGroupServiceProvider.future);

    final groupServiceSubscription = container.listen(
      groupServiceProvider('group-id'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(groupServiceSubscription.close);

    final readyProvider = groupDetailsReadyProvider('group-id');
    final firstRouteSubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(readyProvider.future);
    expect(groupsApi.getRequests, 1);

    firstRouteSubscription.close();
    await Future<void>.delayed(Duration.zero);

    final secondRouteSubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(secondRouteSubscription.close);
    await container.read(readyProvider.future);

    expect(groupsApi.getRequests, 2);
  });

  test('preserves membership changed during hydration', () async {
    final groupRepository = _FakeGroupRepository();
    await groupRepository.put(
      GroupEntity(
        groupId: 'group-id',
        name: 'Cached group',
        visibility: 0,
        userIsMember: false,
        ttl: DateTime(2025),
        onlySession: true,
      ),
    );
    final remoteGroup = _groupWithoutImages();
    final remoteResponse = Completer<GroupDto?>();
    final requestStarted = Completer<void>();
    final groupsApi = _FakeGroupsApi(
      remoteGroup,
      getGroupOverride: () {
        if (!requestStarted.isCompleted) requestStarted.complete();
        return remoteResponse.future;
      },
    );
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('user-id'),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupRepositoryProvider.overrideWithValue(groupRepository),
        pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
        groupApiProvider.overrideWithValue(groupsApi),
        pinApiProvider.overrideWithValue(_FakePinsApi()),
        groupProfileRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupProfileSmallRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupPinImageRepoProvider.overrideWithValue(_FakeImageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final userGroupsSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(userGroupsSubscription.close);
    await container.read(userGroupServiceProvider.future);

    final readyProvider = groupDetailsReadyProvider('group-id');
    final readySubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(readySubscription.close);
    final hydration = container.read(readyProvider.future);
    await requestStarted.future;

    await groupRepository.put(
      GroupEntity(
        groupId: 'group-id',
        name: 'Joined group',
        visibility: 0,
        userIsMember: true,
        ttl: DateTime.now(),
        onlySession: false,
        keepAlive: true,
        isActivated: true,
      ),
    );
    remoteResponse.complete(remoteGroup);

    final group = await hydration;

    expect(group?.name, 'Group');
    expect(group?.userIsMember, isTrue);
    expect(group?.onlySession, isFalse);
    expect(group?.keepAlive, isTrue);
  });

  test('retries metadata hydration after a transient failure', () async {
    var attempts = 0;
    final error = StateError('temporary metadata failure');
    final groupsApi = _FakeGroupsApi(
      _groupWithoutImages(),
      getGroupOverride: () async {
        attempts++;
        if (attempts <= 1) throw error;
        return _groupWithoutImages();
      },
    );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        userIdProvider.overrideWithValue('user-id'),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
        pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
        groupApiProvider.overrideWithValue(groupsApi),
        pinApiProvider.overrideWithValue(_FakePinsApi()),
        groupProfileRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupProfileSmallRepoProvider.overrideWithValue(_FakeImageRepository()),
        groupPinImageRepoProvider.overrideWithValue(_FakeImageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final userGroupsSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(userGroupsSubscription.close);
    await container.read(userGroupServiceProvider.future);

    final groupSubscription = container.listen(
      groupServiceProvider('group-id'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(groupSubscription.close);

    final readyProvider = groupDetailsReadyProvider('group-id');
    final firstRouteSubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await expectLater(
      container.read(readyProvider.future),
      throwsA(same(error)),
    );

    firstRouteSubscription.close();
    await Future<void>.delayed(Duration.zero);

    final secondRouteSubscription = container.listen(
      readyProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(secondRouteSubscription.close);
    final group = await container.read(readyProvider.future);

    expect(group?.name, 'Group');
    expect(groupsApi.getRequests, 2);
  });
}

Future<UserGroupService> _createService({
  MembersApi? membersApi,
  GroupsApi? groupsApi,
  PinsApi? pinsApi,
  IImageRepository? profileCache,
  IImageRepository? profileSmallCache,
  IImageRepository? pinImageCache,
}) async {
  final container = ProviderContainer(
    overrides: [
      userIdProvider.overrideWithValue('user-id'),
      groupRepositoryProvider.overrideWithValue(_FakeGroupRepository()),
      pinRepositoryProvider.overrideWithValue(_FakePinRepository()),
      memberApiProvider.overrideWithValue(membersApi ?? _FakeMembersApi(null)),
      groupApiProvider.overrideWithValue(groupsApi ?? _FakeGroupsApi(null)),
      pinApiProvider.overrideWithValue(pinsApi ?? _FakePinsApi()),
      groupProfileRepoProvider.overrideWithValue(
        profileCache ?? _FakeImageRepository(),
      ),
      groupProfileSmallRepoProvider.overrideWithValue(
        profileSmallCache ?? _FakeImageRepository(),
      ),
      groupPinImageRepoProvider.overrideWithValue(
        pinImageCache ?? _FakeImageRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(userGroupServiceProvider, (_, _) {});
  addTearDown(subscription.close);
  await container.read(userGroupServiceProvider.future);
  return container.read(userGroupServiceProvider.notifier);
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

GroupDto _groupWithImages({String id = 'group-id'}) => GroupDto(
  id: id,
  name: 'Group',
  visibility: 0,
  profileImage: 'https://example.com/profile.jpg',
  profileImageSmall: 'https://example.com/profile-small.jpg',
  pinImage: 'https://example.com/pin.jpg',
);

GroupDto _groupWithoutImages() =>
    GroupDto(id: 'group-id', name: 'Group', visibility: 0);

GroupDto _privateGroupWithoutImages() =>
    GroupDto(id: 'group-id', name: 'Private group', visibility: 1);

class _FakeMembersApi extends MembersApi {
  _FakeMembersApi(this.group) : super(ApiClient());

  final GroupDto? group;

  @override
  Future<GroupDto?> joinGroup(
    String groupId,
    String userId, {
    String? inviteUrl,
  }) async => group;
}

class _FakeGroupsApi extends GroupsApi {
  _FakeGroupsApi(this.group, {this.getGroupOverride}) : super(ApiClient());

  final GroupDto? group;
  final Future<GroupDto?> Function()? getGroupOverride;
  int getRequests = 0;

  @override
  Future<GroupDto?> getGroup(String groupId) async {
    getRequests++;
    return getGroupOverride == null ? group : getGroupOverride!();
  }

  @override
  Future<GroupDto?> updateGroup(
    String groupId,
    UpdateGroupDto updateGroupDto,
  ) async => group;
}

class _FakePinsApi extends PinsApi {
  _FakePinsApi({this.getPinsOverride}) : super(ApiClient());

  int requests = 0;
  final Future<PinsSyncDto?> Function()? getPinsOverride;

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
    requests++;
    return getPinsOverride == null ? null : getPinsOverride!();
  }
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _UserGroupServiceWithoutInitialValue extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => const Stream<List<GroupEntity>>.empty();
}

class _FakeGroupRepository implements IGroupRepository {
  final Map<String, GroupEntity> _groups = {};

  @override
  Future<void> delete(String id) async {
    _groups.remove(id);
  }

  @override
  Future<void> deleteAll() async {
    _groups.clear();
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    for (final id in ids) {
      _groups.remove(id);
    }
  }

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<GroupEntity?> get(String id) async => _groups[id];

  @override
  Future<List<GroupEntity>> getAll() async => _groups.values.toList();

  @override
  Future<List<GroupEntity?>> getList(List<String> ids) async =>
      ids.map((id) => _groups[id]).toList();

  @override
  Future<void> put(GroupEntity item) async {
    _groups[item.groupId] = item;
  }

  @override
  Future<void> putMultiple(List<GroupEntity> items) async {
    for (final item in items) {
      await put(item);
    }
  }

  @override
  Stream<GroupEntity?> watchById(String id) => Stream.value(_groups[id]);

  @override
  Stream<List<GroupEntity>> watchAllGroups() =>
      Stream.value(_groups.values.toList());

  @override
  Stream<List<GroupEntity>> watchUserGroups() => Stream.value(
    _groups.values.where((group) => group.userIsMember).toList(),
  );
}

class _FakePinRepository implements IPinRepository {
  final List<PinEntity> putItems = [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteByGroupId(String groupId) async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<PinEntity?> get(String id) async => null;

  @override
  Future<List<PinEntity>> getAll() async => [];

  @override
  Future<List<PinEntity?>> getList(List<String> ids) async => [];

  @override
  Stream<List<PinEntity>> getPinsByGroup(String groupId) => Stream.value([]);

  @override
  Stream<List<PinEntity>> getPinsByUser(String userId) => Stream.value([]);

  @override
  Future<void> put(PinEntity item) async {}

  @override
  Future<void> putMultiple(List<PinEntity> items) async =>
      putItems.addAll(items);

  @override
  Future<void> replacePin(String oldPinId, PinEntity newPin) async {}

  @override
  Future<void> updateKeepAlive(
    String groupId,
    bool keepAlive,
    bool onlySession,
  ) async {}

  @override
  Stream<PinEntity?> watchById(String id) => Stream.value(null);
}

class _FakeImageRepository implements IImageRepository {
  _FakeImageRepository() : error = null, _completion = null;

  _FakeImageRepository.pending()
    : error = null,
      _completion = Completer<Uint8List>();

  _FakeImageRepository.failure(this.error) : _completion = null;

  final Completer<Uint8List>? _completion;
  final Object? error;
  final List<String> overrideIds = [];

  @override
  ImageType get type => ImageType.group;

  void complete() => _completion!.complete(Uint8List(0));

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async => null;

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive,
  ) async => null;

  @override
  Future<ImageEntity?> get(String id) async => null;

  @override
  Future<List<ImageEntity>> getAll() async => [];

  @override
  Future<List<ImageEntity?>> getList(List<String> ids) async => [];

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async {
    overrideIds.add(id);
    if (error != null) throw error!;
    return _completion?.future ?? Uint8List(0);
  }

  @override
  Future<void> put(ImageEntity item) async {}

  @override
  Future<void> putMultiple(List<ImageEntity> items) async {}

  @override
  Stream<ImageEntity?> watchById(String id) => Stream.value(null);

  @override
  Stream<Uint8List?> watchImageBytes(String id) => Stream.value(null);
}
