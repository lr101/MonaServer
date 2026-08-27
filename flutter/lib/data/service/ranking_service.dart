
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/geojson_service.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ranking_service.g.dart';


@Riverpod(keepAlive: true)
class CurrentUserTopRanking extends _$CurrentUserTopRanking {

  @override
  Future<List<UserRankingDtoInner>?> build() async {
    final district = ref.watch(districtServiceProvider);
    if (district == null) return null;
    return await ref.watch(rankingApiProvider).userRanking(gid2: district.gid2, page: 0, size: 3);
  }
}
