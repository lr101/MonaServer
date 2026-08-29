import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class CustomFeed extends ConsumerStatefulWidget {
  const CustomFeed({
    super.key,
    required this.pinProvider,
    this.index,
    required this.pagingController,
    this.scrollController,
  });

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;
  final PagingController<int, PinEntity> pagingController;
  final int? index;
  final ScrollController? scrollController;

  @override
  ConsumerState<CustomFeed> createState() => _CustomFeedState();
}

class _CustomFeedState extends ConsumerState<CustomFeed> {
  static const int _pageSize = 3;

  List<PinEntity> _pins = [];
  final GlobalKey _initialItemKey = GlobalKey();
  late final PageRequestListener<int> _pageRequestListener;

  @override
  void initState() {
    super.initState();
    _pageRequestListener = (pageKey) => _fetchPage(pageKey);
    widget.pagingController.addPageRequestListener(_pageRequestListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(widget.pinProvider).whenData((data) => _pins = data ?? []);
      if (widget.index != null) {
        _scrollToInitialItem();
      } else {
        widget.pagingController.refresh();
      }
    });
  }

  @override
  void dispose() {
    widget.pagingController.removePageRequestListener(_pageRequestListener);
    super.dispose();
  }

  void _scrollToInitialItem() {
    final targetContext = _initialItemKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(targetContext);
      return;
    }

    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final estimatedItemExtent = screenWidth * 4 / 3 + 90;
    final estimatedOffset = estimatedItemExtent * widget.index!;
    controller.jumpTo(
      estimatedOffset.clamp(0.0, controller.position.maxScrollExtent),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _initialItemKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.pinProvider, (previous, next) {
      _pins = next.value ?? [];
      widget.pagingController.refresh();
    });
    return PagedSliverList<int, PinEntity>(
      pagingController: widget.pagingController,
      addAutomaticKeepAlives: false,
      builderDelegate: PagedChildBuilderDelegate<PinEntity>(
        animateTransitions: true,
        itemBuilder: (context, item, index) => ProviderScope(
          key: index == widget.index ? _initialItemKey : null,
          child: ProviderScope(
            overrides: [feedItemProvider.overrideWithValue(item)],
            child: const FeedCard(),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchPage(int pageKey, {int pageSize = _pageSize}) async {
    try {
      int end;
      if (pageKey + pageSize > _pins.length) {
        end = _pins.length;
      } else {
        end = pageKey + pageSize;
      }
      final idList = _pins.getRange(pageKey, end).toList();
      for (final pin in idList) {
        // prefetch data
        ref.read(pinImageRepositoryProvider).fetchImage(pin.pinId, false);
        ref.read(userServiceProvider(pin.creator));
        ref.read(getUserProfileSmallProvider(pin.creator));
      }
      if (end == _pins.length) {
        widget.pagingController.appendLastPage(idList);
      } else {
        widget.pagingController.appendPage(idList, pageKey + pageSize);
      }
    } catch (error) {
      widget.pagingController.error = error;
    }
  }
}
