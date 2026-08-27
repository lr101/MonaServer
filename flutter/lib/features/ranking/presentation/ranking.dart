import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/features/ranking/data/ranking_state.dart';
import 'package:buff_lisa/features/ranking/presentation/ranking_list_wrapper.dart';
import 'package:buff_lisa/features/ranking/presentation/ranking_tab_button.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_close_keyboard_scaffold.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_ranking_tile.dart';
import 'package:buff_lisa/widgets/tiles/presentation/user_ranking_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:openapi/api.dart';

class Ranking extends ConsumerStatefulWidget {
  const Ranking({super.key});

  @override
  ConsumerState<Ranking> createState() => _RankingState();
}

class _RankingState extends ConsumerState<Ranking>
    with TickerProviderStateMixin {
  final _pagingControllerGroup =
      PagingController<int, GroupRankingDtoInner>(firstPageKey: 0);
  final _pagingControllerUser =
      PagingController<int, UserRankingDtoInner>(firstPageKey: 0);
  late final _tabController = TabController(length: 2, vsync: this,initialIndex: 1);

  static const int _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _pagingControllerGroup.addPageRequestListener(updatePageGroup);
    _pagingControllerUser.addPageRequestListener(updatePageUser);
  }

  @override
  void dispose() {
    _pagingControllerGroup.dispose();
    _pagingControllerUser.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rankingGidProvider, (_, next) {
      _pagingControllerGroup.refresh();
      _pagingControllerUser.refresh();
    });
    ref.listen(rankingTimeSelectorProvider, (_, next) {
      _pagingControllerGroup.refresh();
      _pagingControllerUser.refresh();
    });
    return CustomCloseKeyboardScaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        // here the desired height
        child: AppBar(
          shape: const ContinuousRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).focusColor,
          title: const Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RankingTabButton(
                    label: "Groups",
                    index: 0,
                    tabController: _tabController,
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  RankingTabButton(
                    label: "Users",
                    index: 1,
                    tabController: _tabController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RankingListWrapper(
            child: PagedListView<int, GroupRankingDtoInner>(
              pagingController: _pagingControllerGroup,
              builderDelegate: PagedChildBuilderDelegate(
                itemBuilder: listBuilderGroup,
              ),
            ),
          ),
          RankingListWrapper(
            child: PagedListView<int, UserRankingDtoInner>(
              pagingController: _pagingControllerUser,
              builderDelegate: PagedChildBuilderDelegate(
                itemBuilder: listBuilderUser,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget listBuilderGroup(
    BuildContext context,
    GroupRankingDtoInner item,
    int index,
  ) {
    return GroupRankingTile(
      groupDto: item,
      height: 40,
    );
  }

  Widget listBuilderUser(
    BuildContext context,
    UserRankingDtoInner item,
    int index,
  ) {
    return UserRankingTile(
      user: item,
      height: 40,
    );
  }

  Future<void> updatePageUser(int pageKey) async {
    try {
      final districts = ref.read(rankingGidProvider);
      final rankingTime = ref.read(rankingTimeSelectorProvider);
      final gid0 = districts?.adminLevel == 0 ? districts?.gid : null;
      final gid1 = districts?.adminLevel == 1 ? districts?.gid : null;
      final gid2 = districts?.adminLevel == 2 ? districts?.gid : null;
      final season = rankingTime == 0;
      List<UserRankingDtoInner>? items;
      items = await ref.read(rankingApiProvider).userRanking(
            gid0: gid0,
            gid1: gid1,
            gid2: gid2,
            page: pageKey,
            size: _pageSize,
            season: season,
          );
      if (items == null) {
        _pagingControllerUser.error = "Ranking could not be fetched";
        return;
      }
      if (items.length < _pageSize) {
        _pagingControllerUser.appendLastPage(items);
      } else {
        _pagingControllerUser.appendPage(items, pageKey + 1);
      }
    } on ApiException catch (e) {
      _pagingControllerUser.error = e.message;
    }
  }

  bool compareFn(RankingSearchDtoInner i1, RankingSearchDtoInner i2) {
    return i1.gid == i2.gid;
  }

  Future<void> updatePageGroup(int pageKey) async {
    try {
      final districts = ref.read(rankingGidProvider);
      final rankingTime = ref.read(rankingTimeSelectorProvider);
      final gid0 = districts?.adminLevel == 0 ? districts?.gid : null;
      final gid1 = districts?.adminLevel == 1 ? districts?.gid : null;
      final gid2 = districts?.adminLevel == 2 ? districts?.gid : null;
      final season = rankingTime == 0;
      List<GroupRankingDtoInner>? items;
      items = await ref.read(rankingApiProvider).groupRanking(
            gid0: gid0,
            gid1: gid1,
            gid2: gid2,
            page: pageKey,
            size: _pageSize,
            season: season,
          );
      if (items == null) {
        _pagingControllerGroup.error = "Ranking could not be fetched";
        return;
      }
      if (items.length < _pageSize) {
        _pagingControllerGroup.appendLastPage(items);
      } else {
        _pagingControllerGroup.appendPage(items, pageKey + 1);
      }
    } on ApiException catch (e) {
      _pagingControllerGroup.error = e.message;
    }
  }
}
