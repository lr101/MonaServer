import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('small group profile images use the small image repository', () async {
    final largeRepository = _RecordingImageRepository(ImageType.group);
    final smallRepository = _RecordingImageRepository(ImageType.groupSmall);
    final container = ProviderContainer(
      overrides: [
        groupProfileRepoProvider.overrideWithValue(largeRepository),
        groupProfileSmallRepoProvider.overrideWithValue(smallRepository),
        userGroupServiceProvider.overrideWith(_FakeUserGroupService.new),
      ],
    );
    addTearDown(container.dispose);

    final membershipSubscription = container.listen(
      userGroupServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(membershipSubscription.close);
    await container.read(userGroupServiceProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(userGroupServiceProvider).value, isNotNull);
    expect(
      container.read(
        userGroupServiceProvider.select(
          (value) => value.value?.any((group) => group.groupId == 'group-1'),
        ),
      ),
      false,
    );
    final subscription = container.listen(
      groupProfilePictureSmallByIdProvider('group-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(
      container.read(groupProfileSmallRepoProvider),
      same(smallRepository),
    );
    expect(container.read(groupProfileRepoProvider), same(largeRepository));
    await container.read(
      groupProfilePictureSmallByIdProvider('group-1').future,
    );

    expect(smallRepository.fetches, [('group-1', false)]);
    expect(largeRepository.fetches, isEmpty);
  });
}

class _FakeUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _RecordingImageRepository implements IImageRepository {
  _RecordingImageRepository(this.type);

  @override
  final ImageType type;
  final List<(String, bool)> fetches = [];

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async {
    fetches.add((id, keepAlive));
    return null;
  }

  @override
  Stream<Uint8List?> watchImageBytes(String id) => Stream.value(null);

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async =>
      Uint8List(0);

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {}

  @override
  Future<void> put(ImageEntity item) async {}

  @override
  Stream<ImageEntity?> watchById(String id) => Stream.value(null);

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<ImageEntity?> get(String id) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ImageEntity>> getAll() async => [];

  @override
  Future<List<ImageEntity?>> getList(List<String> ids) async => [];

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> putMultiple(List<ImageEntity> items) async {}

  @override
  Future<void> deleteOldestItems() async {}
}
