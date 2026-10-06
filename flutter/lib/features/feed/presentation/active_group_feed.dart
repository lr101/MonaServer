import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/top_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class ActiveGroupFeed extends ConsumerStatefulWidget {
  const ActiveGroupFeed({super.key});

  @override
  ConsumerState<ActiveGroupFeed> createState() => _ActiveGroupFeedState();
}

class _ActiveGroupFeedState extends ConsumerState<ActiveGroupFeed>
    with AutomaticKeepAliveClientMixin {
  final PagingController<int, PinEntity> _pagingController = PagingController(
    firstPageKey: 0,
    invisibleItemsThreshold: 5,
  );

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    ref.listen(activePinEntriesProvider, (previous, next) {
      _pagingController.refresh();
    });

    return SafeArea(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
        slivers: [
          const SliverAppBar(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            flexibleSpace: Padding(
              padding: EdgeInsets.all(4),
              child: TopStatusBar(showUserLevel: false),
            ),
          ),

          CustomFeed(
            pinProvider: activePinEntriesProvider,
            pagingController: _pagingController,
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
