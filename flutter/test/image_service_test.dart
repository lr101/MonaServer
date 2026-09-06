import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  test('pin image stream forwards encoded bytes without predecoding', () async {
    final bytes = Uint8List.fromList(kTransparentImage);
    final repository = _RecordingImageRepository(ImageType.pin)
      ..watchedBytes = bytes;
    final container = ProviderContainer(
      overrides: [pinImageRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      pinImageBytesProvider('pin-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final image = await container.read(pinImageBytesProvider('pin-1').future);

    expect(image, same(bytes));
  });

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

  test(
    'unjoined group profile images load without a membership snapshot',
    () async {
      final repository = _RecordingImageRepository(ImageType.group);
      final container = ProviderContainer(
        overrides: [
          groupProfileRepoProvider.overrideWithValue(repository),
          userGroupServiceProvider.overrideWith(
            _UserGroupServiceWithoutInitialValue.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final membershipSubscription = container.listen(
        userGroupServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(membershipSubscription.close);

      final subscription = container.listen(
        groupProfilePictureByIdProvider('group-1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(groupProfilePictureByIdProvider('group-1').future)
          .timeout(const Duration(milliseconds: 100));

      expect(repository.fetches, [('group-1', false)]);
    },
  );

  test('search thumbnails use the supplied URL after subscribing', () async {
    final repository = _RecordingImageRepository(ImageType.groupSmall)
      ..urlFetchGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        groupProfileSmallRepoProvider.overrideWithValue(repository),
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

    final subscription = container.listen(
      groupProfilePictureSmallByUrlProvider((
        groupId: 'group-1',
        url: 'https://example.com/group-small.png',
      )),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await repository.urlFetchStarted.future.timeout(
      const Duration(milliseconds: 100),
    );

    expect(repository.events, ['watch-created', 'watch-listened', 'fetch-url']);
    expect(repository.fetches, isEmpty);
    expect(repository.urlFetches, [
      ('group-1', 'https://example.com/group-small.png', false),
    ]);
    repository.urlFetchGate!.complete();
  });

  test('group pin image provider watches before fetching the image', () async {
    final repository = _RecordingImageRepository(ImageType.groupPin)
      ..fetchGate = Completer<void>();
    final firstEmission = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        groupPinImageRepoProvider.overrideWithValue(repository),
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

    final subscription = container.listen(
      groupPinImageByIdProvider('group-1'),
      (_, value) {
        if (value.hasValue && !firstEmission.isCompleted) {
          firstEmission.complete();
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await firstEmission.future.timeout(const Duration(milliseconds: 100));

    expect(repository.fetchGate!.isCompleted, isFalse);
    expect(repository.events, ['watch-created', 'watch-listened', 'fetch']);
    repository.fetchGate!.complete();
  });

  test('group pin image provider forwards refresh errors', () async {
    final error = StateError('refresh failed');
    final repository = _RecordingImageRepository(ImageType.groupPin)
      ..fetchError = error;
    final container = ProviderContainer(
      overrides: [
        groupPinImageRepoProvider.overrideWithValue(repository),
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

    final errorFuture = Completer<Object>();
    final subscription = container.listen(
      groupPinImageByIdProvider('group-1'),
      (_, value) {
        value.whenOrNull(
          error: (error, _) {
            if (!errorFuture.isCompleted) errorFuture.complete(error);
          },
        );
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      await errorFuture.future.timeout(const Duration(milliseconds: 100)),
      same(error),
    );
  });
}

class _FakeUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _UserGroupServiceWithoutInitialValue extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => const Stream<List<GroupEntity>>.empty();
}

class _RecordingImageRepository implements IImageRepository {
  _RecordingImageRepository(this.type);

  @override
  final ImageType type;
  final List<(String, bool)> fetches = [];
  final List<(String, String, bool)> overrides = [];
  final List<(String, String, bool)> urlFetches = [];
  final List<String> events = [];
  Completer<void>? fetchGate;
  Object? fetchError;
  Completer<void>? urlFetchGate;
  final urlFetchStarted = Completer<void>();
  Uint8List? watchedBytes;

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async {
    events.add('fetch');
    fetches.add((id, keepAlive));
    await fetchGate?.future;
    final error = fetchError;
    if (error != null) throw error;
    return null;
  }

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive,
  ) async {
    events.add('fetch-url');
    urlFetches.add((id, url, keepAlive));
    if (!urlFetchStarted.isCompleted) urlFetchStarted.complete();
    await urlFetchGate?.future;
    return null;
  }

  @override
  Stream<Uint8List?> watchImageBytes(String id) {
    events.add('watch-created');
    return Stream<Uint8List?>.multi((controller) {
      events.add('watch-listened');
      controller.add(watchedBytes);
    });
  }

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async {
    events.add('override');
    overrides.add((id, url, keepAlive));
    return Uint8List(0);
  }

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {}

  @override
  Future<void> put(ImageEntity item) async {}

  @override
  Stream<ImageEntity?> watchById(String id) => Stream.value(null);

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<ImageEntity?> get(String id) async {
    events.add('get');
    return null;
  }

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
