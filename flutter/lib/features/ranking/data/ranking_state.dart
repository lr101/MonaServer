import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ranking_state.g.dart';

@riverpod
class RankingGid extends _$RankingGid {
  @override
  RankingSearchDtoInner? build() {
    return null;
  }

  // ignore: use_setters_to_change_properties
  void update(RankingSearchDtoInner? gid) {
    state = gid;
  }
}

@Riverpod(keepAlive: true)
class RankingSearch extends _$RankingSearch {

  @override
  Future<List<RankingSearchDtoInner>> build() async {
    final rankingApi = ref.watch(rankingApiProvider);
    return await rankingApi.searchRanking() ?? [];
  }

}

@riverpod
class RankingTimeSelector extends _$RankingTimeSelector{
  @override
  int build() {
    return 0;
  }

  // ignore: use_setters_to_change_properties
  void updateIndex(int index) {
    state = index;
  }
}
