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
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
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

  test(
    'waits for every group image cache write before joining completes',
    () async {
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
      expect(completed, isFalse);

      profileCache.complete();
      await _nextEventLoop();
      expect(completed, isFalse);

      profileSmallCache.complete();
      await _nextEventLoop();
      expect(completed, isFalse);

      pinImageCache.complete();
      await join;
      expect(completed, isTrue);
    },
  );

  test(
    'waits for group image cache writes before an update completes',
    () async {
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
      expect(completed, isFalse);

      profileCache.complete();
      await _nextEventLoop();
      expect(completed, isFalse);

      profileSmallCache.complete();
      await _nextEventLoop();
      expect(completed, isFalse);

      pinImageCache.complete();
      await update;
      expect(completed, isTrue);
    },
  );

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

  test(
    'returns a synchronization failure when a group image cache write fails',
    () async {
      final service = await _createService(
        membersApi: _FakeMembersApi(_groupWithImages()),
        profileCache: _FakeImageRepository.failure(
          Exception('cache write failed'),
        ),
      );

      await expectLater(
        service.joinGroup('group-id'),
        completion('Failed to sync joined group'),
      );
    },
  );
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

GroupDto _groupWithImages() => GroupDto(
  id: 'group-id',
  name: 'Group',
  visibility: 0,
  profileImage: 'https://example.com/profile.jpg',
  profileImageSmall: 'https://example.com/profile-small.jpg',
  pinImage: 'https://example.com/pin.jpg',
);

GroupDto _groupWithoutImages() =>
    GroupDto(id: 'group-id', name: 'Group', visibility: 0);

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
  _FakeGroupsApi(this.group) : super(ApiClient());

  final GroupDto? group;

  @override
  Future<GroupDto?> updateGroup(
    String groupId,
    UpdateGroupDto updateGroupDto,
  ) async => group;
}

class _FakePinsApi extends PinsApi {
  _FakePinsApi() : super(ApiClient());

  int requests = 0;

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
    return PinsSyncDto();
  }
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
  Future<void> putMultiple(List<PinEntity> items) async {}

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
