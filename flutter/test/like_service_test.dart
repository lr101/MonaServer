import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_like_entity.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  for (final failure in [
    ApiException(503, 'offline'),
    StateError('transport'),
  ]) {
    test(
      'failed sync restores state and leaves cache confirmed: $failure',
      () async {
        final repository = _FakePinLikeRepository()
          ..cached = PinLikeEntity.fromDto(
            PinLikeDto(likeCount: 0, likedByUser: false),
            'pin',
          );
        final api = _DelayedLikesApi();
        final container = ProviderContainer(
          overrides: [
            pinLikeRepositoryProvider.overrideWithValue(repository),
            userIdProvider.overrideWithValue('user-id'),
            likeApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          likeServiceProvider('pin'),
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(likeServiceProvider('pin').future);
        final request = container
            .read(likeServiceProvider('pin').notifier)
            .addLike('creator', CreateLikeDto(userId: 'user-id', like: true));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(likeServiceProvider('pin')).value!.likeCount, 1);
        expect(repository.cached!.likeCount, 0);
        api.result.completeError(failure);
        await request;
        expect(
          container.read(likeServiceProvider('pin')).value!.likedByUser,
          false,
        );
        expect(repository.cached!.hasLike, false);
      },
    );
  }

  test('cached negative pin count is normalized when loaded', () async {
    final repository = _FakePinLikeRepository()
      ..cached = PinLikeEntity.fromDto(
        PinLikeDto(likeCount: -4, likedByUser: false),
        'pin',
      );
    final container = ProviderContainer(
      overrides: [
        pinLikeRepositoryProvider.overrideWithValue(repository),
        userIdProvider.overrideWithValue('user-id'),
        likeApiProvider.overrideWithValue(LikesApi(ApiClient())),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(likeServiceProvider('pin'), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(likeServiceProvider('pin').future)).likeCount,
      0,
    );
  });

  test(
    'successful like remains confirmed if cache persistence fails',
    () async {
      final repository = _FakePinLikeRepository()
        ..cached = PinLikeEntity.fromDto(
          PinLikeDto(likeCount: 0, likedByUser: false),
          'pin',
        )
        ..failWrites = true;
      final api = _DelayedLikesApi()
        ..result.complete(PinLikeDto(likeCount: 1, likedByUser: true));
      final container = ProviderContainer(
        overrides: [
          pinLikeRepositoryProvider.overrideWithValue(repository),
          userIdProvider.overrideWithValue('user-id'),
          likeApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(likeServiceProvider('pin'), (_, _) {});
      addTearDown(sub.close);
      await container.read(likeServiceProvider('pin').future);
      await container
          .read(likeServiceProvider('pin').notifier)
          .addLike('creator', CreateLikeDto(userId: 'user-id', like: true));
      final state = container.read(likeServiceProvider('pin')).value!;
      expect(state.likeCount, 1);
      expect(state.likedByUser, true);
    },
  );

  test(
    'negative authoritative server count is normalized and cached',
    () async {
      final repository = _FakePinLikeRepository()
        ..cached = PinLikeEntity.fromDto(
          PinLikeDto(likeCount: 1, likedByUser: true),
          'pin',
        );
      final api = _DelayedLikesApi()
        ..result.complete(PinLikeDto(likeCount: -9, likedByUser: false));
      final container = ProviderContainer(
        overrides: [
          pinLikeRepositoryProvider.overrideWithValue(repository),
          userIdProvider.overrideWithValue('user-id'),
          likeApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(likeServiceProvider('pin'), (_, _) {});
      addTearDown(sub.close);
      await container.read(likeServiceProvider('pin').future);
      await container
          .read(likeServiceProvider('pin').notifier)
          .addLike('creator', CreateLikeDto(userId: 'user-id', like: false));
      expect(container.read(likeServiceProvider('pin')).value!.likeCount, 0);
      expect(repository.cached!.likeCount, 0);
    },
  );

  test(
    'unlike stays nonnegative and accepts authoritative server count',
    () async {
      final repository = _FakePinLikeRepository()
        ..cached = PinLikeEntity.fromDto(
          PinLikeDto(likeCount: 0, likedByUser: true),
          'pin',
        );
      final api = _DelayedLikesApi();
      final container = ProviderContainer(
        overrides: [
          pinLikeRepositoryProvider.overrideWithValue(repository),
          userIdProvider.overrideWithValue('user-id'),
          likeApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        likeServiceProvider('pin'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(likeServiceProvider('pin').future);
      final request = container
          .read(likeServiceProvider('pin').notifier)
          .addLike('creator', CreateLikeDto(userId: 'user-id', like: false));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(likeServiceProvider('pin')).value!.likeCount, 0);
      api.result.complete(PinLikeDto(likeCount: 8, likedByUser: false));
      await request;
      expect(container.read(likeServiceProvider('pin')).value!.likeCount, 8);
      expect(repository.cached!.likeCount, 8);
    },
  );

  test(
    'repeated double-tap likes do not increase creator totals twice',
    () async {
      final repository = _FakePinLikeRepository()
        ..cached = PinLikeEntity.fromDto(
          PinLikeDto(likeCount: 1, likedByUser: true),
          'pin',
        );
      final api = _DelayedLikesApi()
        ..result.complete(PinLikeDto(likeCount: 1, likedByUser: true));
      final totals = _RecordingUserLikes();
      final container = ProviderContainer(
        overrides: [
          pinLikeRepositoryProvider.overrideWithValue(repository),
          userIdProvider.overrideWithValue('user-id'),
          likeApiProvider.overrideWithValue(api),
          userLikeServiceProvider('creator').overrideWith(() => totals),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(likeServiceProvider('pin'), (_, _) {});
      final userSub = container.listen(
        userLikeServiceProvider('creator'),
        (_, _) {},
      );
      addTearDown(sub.close);
      addTearDown(userSub.close);
      await container.read(likeServiceProvider('pin').future);
      await container.read(userLikeServiceProvider('creator').future);
      await container
          .read(likeServiceProvider('pin').notifier)
          .addLike('creator', CreateLikeDto(userId: 'user-id', like: true));
      expect(totals.recordedUpdate!.like, isNull);
      expect(container.read(likeServiceProvider('pin')).value!.likeCount, 1);
    },
  );

  test('does not cache a retryable pin-like batch failure', () async {
    final repository = _FakePinLikeRepository();
    final loader = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async => [
        BatchReadResult(
          kind: BatchReadResultKindEnum.pinLikes,
          id: items.single.id,
          status: 503,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        pinLikeRepositoryProvider.overrideWithValue(repository),
        userIdProvider.overrideWithValue('user-id'),
        likeApiProvider.overrideWithValue(LikesApi(ApiClient())),
        batchReadCoalescerProvider.overrideWithValue(loader),
      ],
    );
    addTearDown(loader.dispose);
    addTearDown(container.dispose);

    final value = await container.read(likeServiceProvider('pin-1').future);

    expect(value.likeCount, isNull);
    expect(repository.putCount, 0);
  });
}

class _FakePinLikeRepository implements IPinLikeRepository {
  int putCount = 0;
  PinLikeEntity? cached;
  bool failWrites = false;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<PinLikeEntity?> get(String id) async => cached;

  @override
  Future<List<PinLikeEntity?>> getList(List<String> ids) async => [];

  @override
  Future<List<PinLikeEntity>> getAll() async => [];

  @override
  Future<void> put(PinLikeEntity item) async {
    putCount++;
    if (failWrites) throw StateError('cache unavailable');
    cached = item;
  }

  @override
  Future<void> putMultiple(List<PinLikeEntity> items) async {}

  @override
  Stream<PinLikeEntity?> watchById(String id) => Stream.value(null);
}

class _DelayedLikesApi extends LikesApi {
  final result = Completer<PinLikeDto?>();
  @override
  Future<PinLikeDto?> createOrUpdateLike(String pinId, CreateLikeDto dto) =>
      result.future;
}

class _RecordingUserLikes extends UserLikeService {
  CreateLikeDto? recordedUpdate;
  @override
  Future<UserLikesDto> build(String userId) async => UserLikesDto(
    likeCount: 1,
    likeArtCount: 0,
    likeLocationCount: 0,
    likePhotographyCount: 0,
  );
  @override
  Future<void> updateLikeCount(CreateLikeDto dto) async {
    recordedUpdate = dto;
  }
}
