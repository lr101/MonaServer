import 'package:buff_lisa/data/entity/pin_like_entity.dart';
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
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

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Future<PinLikeEntity?> get(String id) async => null;

  @override
  Future<List<PinLikeEntity?>> getList(List<String> ids) async => [];

  @override
  Future<List<PinLikeEntity>> getAll() async => [];

  @override
  Future<void> put(PinLikeEntity item) async => putCount++;

  @override
  Future<void> putMultiple(List<PinLikeEntity> items) async {}

  @override
  Stream<PinLikeEntity?> watchById(String id) => Stream.value(null);
}
