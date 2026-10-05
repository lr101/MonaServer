import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/user_like_entity.dart';
import 'package:buff_lisa/data/repository/user_repository.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test('unlike cannot make stale zero creator total negative', () async {
    final repo = _UserLikes();
    final container = ProviderContainer(
      overrides: [
        userLikeRepositoryProvider.overrideWithValue(repo),
        likeApiProvider.overrideWithValue(LikesApi(ApiClient())),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(userLikeServiceProvider('creator'), (_, _) {});
    addTearDown(sub.close);
    await container.read(userLikeServiceProvider('creator').future);
    await container
        .read(userLikeServiceProvider('creator').notifier)
        .updateLikeCount(CreateLikeDto(userId: 'viewer', like: false));
    final likes = container.read(userLikeServiceProvider('creator')).value!;
    expect(likes.likeCount, 0);
    expect(repo.value.likeCount, 0);
  });

  test('negative cached creator totals are normalized when loaded', () async {
    final repo = _UserLikes(
      value: UserLikeEntity.fromDto(
        UserLikesDto(likeCount: -1),
        'creator',
        true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        userLikeRepositoryProvider.overrideWithValue(repo),
        likeApiProvider.overrideWithValue(LikesApi(ApiClient())),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(userLikeServiceProvider('creator'), (_, _) {});
    addTearDown(sub.close);
    final likes = await container.read(
      userLikeServiceProvider('creator').future,
    );
    expect(likes.likeCount, 0);
  });
}

class _UserLikes implements IUserLikeRepository {
  late UserLikeEntity value;

  _UserLikes({UserLikeEntity? value})
    : value =
          value ??
          UserLikeEntity.fromDto(UserLikesDto(likeCount: 0), 'creator', true);
  @override
  Future<UserLikeEntity?> get(String id) async => value;
  @override
  Future<void> put(UserLikeEntity item) async {
    value = item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
