import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
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
  late final _pagingControllerGroup =
      PagingController<int, GroupRankingDtoInner>(
        getNextPageKey: (state) => state.pages == null
            ? 0
            : state.pages!.last.length < _pageSize
            ? null
            : state.keys!.last + 1,
        fetchPage: updatePageGroup,
      );
  late final _pagingControllerUser = PagingController<int, UserRankingDtoInner>(
    getNextPageKey: (state) => state.pages == null
        ? 0
        : state.pages!.last.length < _pageSize
        ? null
        : state.keys!.last + 1,
    fetchPage: updatePageUser,
  );
  late final _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: 1,
  );

  static const int _pageSize = 40;

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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  const SizedBox(width: 20),
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
            child: PagingListener<int, GroupRankingDtoInner>(
              controller: _pagingControllerGroup,
              builder: (context, state, fetchNextPage) =>
                  PagedListView<int, GroupRankingDtoInner>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    builderDelegate: PagedChildBuilderDelegate(
                      itemBuilder: listBuilderGroup,
                    ),
                  ),
            ),
          ),
          RankingListWrapper(
            child: PagingListener<int, UserRankingDtoInner>(
              controller: _pagingControllerUser,
              builder: (context, state, fetchNextPage) =>
                  PagedListView<int, UserRankingDtoInner>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    builderDelegate: PagedChildBuilderDelegate(
                      itemBuilder: listBuilderUser,
                    ),
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
    return GroupRankingTile(groupDto: item, height: 40);
  }

  Widget listBuilderUser(
    BuildContext context,
    UserRankingDtoInner item,
    int index,
  ) {
    return UserRankingTile(user: item, height: 40);
  }

  Future<List<UserRankingDtoInner>> updatePageUser(int pageKey) async {
    try {
      final districts = ref.read(rankingGidProvider);
      final rankingTime = ref.read(rankingTimeSelectorProvider);
      final gid0 = districts?.adminLevel == 0 ? districts?.gid : null;
      final gid1 = districts?.adminLevel == 1 ? districts?.gid : null;
      final gid2 = districts?.adminLevel == 2 ? districts?.gid : null;
      final season = rankingTime == 0;
      List<UserRankingDtoInner>? items;
      items = await ref
          .read(rankingApiProvider)
          .userRanking(
            gid0: gid0,
            gid1: gid1,
            gid2: gid2,
            page: pageKey,
            size: _pageSize,
            season: season,
          );
      if (items == null) {
        throw Exception("Ranking could not be fetched");
      }
      _prefetchUserImages(items);
      return items;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  bool compareFn(RankingSearchDtoInner i1, RankingSearchDtoInner i2) {
    return i1.gid == i2.gid;
  }

  Future<List<GroupRankingDtoInner>> updatePageGroup(int pageKey) async {
    try {
      final districts = ref.read(rankingGidProvider);
      final rankingTime = ref.read(rankingTimeSelectorProvider);
      final gid0 = districts?.adminLevel == 0 ? districts?.gid : null;
      final gid1 = districts?.adminLevel == 1 ? districts?.gid : null;
      final gid2 = districts?.adminLevel == 2 ? districts?.gid : null;
      final season = rankingTime == 0;
      List<GroupRankingDtoInner>? items;
      items = await ref
          .read(rankingApiProvider)
          .groupRanking(
            gid0: gid0,
            gid1: gid1,
            gid2: gid2,
            page: pageKey,
            size: _pageSize,
            season: season,
          );
      if (items == null) {
        throw Exception("Ranking could not be fetched");
      }
      for (final item in items) {
        final group = item.groupInfoDto;
        if (group != null) {
          registerGroupImageUrls(ref, group);
          _prefetchImage(BatchReadKind.groupImageSmall, group.id);
        }
      }
      return items;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  void _prefetchUserImages(Iterable<UserRankingDtoInner> items) {
    for (final item in items) {
      final userId = item.userInfoDto?.userId;
      if (userId != null) {
        _prefetchImage(BatchReadKind.userImageSmall, userId);
      }
    }
  }

  void _prefetchImage(BatchReadKind kind, String id) {
    try {
      final registry = ref.read(suppliedImageUrlRegistryProvider);
      if (registry.lookup(kind, id) != null) return;
      final future = ref
          .read(batchReadCoalescerProvider)
          .readKey(BatchReadKey(kind, id));
      unawaited(future.then<void>((_) {}, onError: (_, _) {}));
    } catch (_) {
      // Prefetch is an optimization and must not fail the ranking page.
    }
  }
}
