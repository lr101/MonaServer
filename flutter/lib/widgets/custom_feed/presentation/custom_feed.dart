import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_snapshot.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
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
    this.entryId,
    this.scrollController,
    this.thumbnailsOnly = false,
    this.invisibleItemsThreshold = 3,
  });

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;
  final int? index;
  final String? entryId;
  final ScrollController? scrollController;
  final bool thumbnailsOnly;
  final int invisibleItemsThreshold;

  @override
  ConsumerState<CustomFeed> createState() => _CustomFeedState();
}

class _CustomFeedState extends ConsumerState<CustomFeed> {
  static const int _pageSize = 3;

  List<PinEntity> _pins = [];
  List<PinEntity>? _pendingSortedPins;
  ScrollPosition? _scrollPosition;
  String? _initialEntryId;
  final GlobalKey _initialItemKey = GlobalKey();
  late final PagingController<int, PinEntity> _pagingController;

  @override
  void initState() {
    super.initState();
    _pins = ref.read(widget.pinProvider).value ?? [];
    _initialEntryId =
        widget.entryId ??
        (widget.index != null && widget.index! < _pins.length
            ? _pins[widget.index!].entryId
            : null);
    final initialCount = widget.index == null
        ? 0
        : (widget.index! + 1).clamp(0, _pins.length);
    _pagingController = PagingController<int, PinEntity>(
      value: initialCount == 0
          ? null
          : PagingState(
              pages: [_pins.take(initialCount).toList()],
              keys: const [0],
              hasNextPage: initialCount < _pins.length,
            ),
      getNextPageKey: (state) {
        final count = state.items?.length ?? 0;
        if (state.pages == null) return 0;
        return count < _pins.length ? count : null;
      },
      fetchPage: _fetchPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(widget.pinProvider).whenData((data) => _pins = data ?? []);
      _initialEntryId =
          widget.entryId ??
          (widget.index != null && widget.index! < _pins.length
              ? _pins[widget.index!].entryId
              : null);
      if (widget.index != null) {
        _scrollToInitialItem();
      } else {
        _pagingController.refresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_restoreSortedOrderAtTop);
    _scrollPosition = position;
    _scrollPosition?.addListener(_restoreSortedOrderAtTop);
  }

  bool get _atTop {
    final position = _scrollPosition;
    return position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions ||
        position.pixels <= position.minScrollExtent + 0.5;
  }

  void _restoreSortedOrderAtTop() {
    final pending = _pendingSortedPins;
    if (pending == null || !_atTop || !mounted) return;
    _pendingSortedPins = null;
    if (_samePinList(_pins, pending)) return;
    _pins = pending;
    _updatePagingSnapshot();
  }

  void _updatePagingSnapshot() {
    final currentItems = _pagingController.value.items;
    final loaded = currentItems?.length ?? 0;
    if (loaded == 0) {
      _pagingController.refresh();
    } else {
      final count = loaded.clamp(0, _pins.length);
      final nextItems = _pins.take(count).toList();
      final nextHasNextPage = count < _pins.length;
      if (currentItems != null &&
          _pagingController.value.hasNextPage == nextHasNextPage &&
          _samePinList(currentItems, nextItems)) {
        return;
      }
      _pagingController.cancel();
      _pagingController.value = PagingState(
        pages: [nextItems],
        keys: const [0],
        hasNextPage: nextHasNextPage,
      );
    }
  }

  bool _samePinList(List<PinEntity> a, List<PinEntity> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.entryId != right.entryId ||
          left.pinId != right.pinId ||
          left.photoId != right.photoId ||
          left.photoUrl != right.photoUrl ||
          left.photoThumbnailUrl != right.photoThumbnailUrl ||
          left.imageBlurhash != right.imageBlurhash ||
          left.title != right.title ||
          left.description != right.description ||
          left.creationDate != right.creationDate ||
          left.creator != right.creator ||
          left.contributorUsername != right.contributorUsername ||
          left.isGone != right.isGone ||
          left.isHidden != right.isHidden) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_restoreSortedOrderAtTop);
    _pagingController.dispose();
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
    final cardWidth = (screenWidth - 32).clamp(0.0, 480.0);
    final estimatedItemExtent = cardWidth * 4 / 3 + 90;
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
      if (!next.hasValue || next.isLoading || next.hasError) return;
      final incoming = next.value ?? <PinEntity>[];
      final loaded = _pagingController.value.items?.length ?? 0;
      final List<PinEntity> nextPins;
      if (widget.index == null && widget.entryId == null && _atTop) {
        _pendingSortedPins = null;
        nextPins = List.of(incoming);
      } else {
        _pendingSortedPins = widget.index == null && widget.entryId == null
            ? List.of(incoming)
            : null;
        nextPins = reconcileFeedEntries(_pins, incoming, loaded);
      }
      if (_samePinList(_pins, nextPins) &&
          _pagingController.value.items != null) {
        return;
      }
      _pins = nextPins;
      _updatePagingSnapshot();
    });
    final pinStatus = ref.watch(
      widget.pinProvider.select(
        (value) => (
          hasValue: value.hasValue,
          hasError: value.hasError,
          error: value.hasValue ? null : value.error,
        ),
      ),
    );
    if (!pinStatus.hasValue && !pinStatus.hasError) {
      return const SliverToBoxAdapter(child: _FeedPlaceholder());
    }
    if (!pinStatus.hasValue && pinStatus.hasError) {
      return PagedSliverList<int, PinEntity>(
        state: PagingState(error: pinStatus.error),
        fetchNextPage: () => _pagingController.refresh(),
        builderDelegate: PagedChildBuilderDelegate<PinEntity>(
          itemBuilder: (context, item, index) => const SizedBox.shrink(),
        ),
      );
    }
    final useTwoColumns =
        widget.index == null &&
        widget.entryId == null &&
        MediaQuery.sizeOf(context).width >= 900;
    return PagingListener<int, PinEntity>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) {
        if (!useTwoColumns) {
          return PagedSliverList<int, PinEntity>(
            state: state,
            fetchNextPage: fetchNextPage,
            addAutomaticKeepAlives: false,
            builderDelegate: PagedChildBuilderDelegate<PinEntity>(
              animateTransitions: true,
              firstPageProgressIndicatorBuilder: (_) =>
                  const _FeedPlaceholder(),
              newPageProgressIndicatorBuilder: (_) => const _FeedPlaceholder(),
              invisibleItemsThreshold: widget.invisibleItemsThreshold,
              itemBuilder: (context, item, index) => ProviderScope(
                key: item.entryId == _initialEntryId
                    ? _initialItemKey
                    : ValueKey(item.entryId),
                overrides: [feedItemProvider.overrideWithValue(item)],
                child: FeedCard(thumbnailsOnly: widget.thumbnailsOnly),
              ),
            ),
          );
        }
        return SliverLayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.crossAxisExtent;
            final sidePadding = ((availableWidth - 848.0) / 2).clamp(
              16.0,
              double.infinity,
            );
            final gridWidth = availableWidth - sidePadding * 2;
            final columnWidth = (gridWidth - 16.0) / 2;
            final imageWidth = (columnWidth - 16.0).clamp(160.0, 500.0);
            final imageHeight = (imageWidth * 1.05).clamp(240.0, 420.0);
            final tileHeight = imageHeight + 90.0;
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 16),
              sliver: PagedSliverGrid<int, PinEntity>(
                state: state,
                fetchNextPage: fetchNextPage,
                addAutomaticKeepAlives: false,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: tileHeight,
                ),
                builderDelegate: PagedChildBuilderDelegate<PinEntity>(
                  animateTransitions: true,
                  firstPageProgressIndicatorBuilder: (_) =>
                      const _FeedPlaceholder(),
                  newPageProgressIndicatorBuilder: (_) =>
                      const _FeedPlaceholder(),
                  invisibleItemsThreshold: widget.invisibleItemsThreshold,
                  itemBuilder: (context, item, index) => ProviderScope(
                    key: item.entryId == _initialEntryId
                        ? _initialItemKey
                        : ValueKey(item.entryId),
                    overrides: [feedItemProvider.overrideWithValue(item)],
                    child: FeedCard(
                      thumbnailsOnly: widget.thumbnailsOnly,
                      inGrid: true,
                      gridImageHeight: imageHeight,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<PinEntity>> _fetchPage(
    int pageKey, {
    int pageSize = _pageSize,
  }) async {
    int end;
    if (pageKey + pageSize > _pins.length) {
      end = _pins.length;
    } else {
      end = pageKey + pageSize;
    }
    final idList = _pins.getRange(pageKey, end).toList();
    if (idList.isEmpty) return idList;
    final coalescer = ref.read(batchReadCoalescerProvider);
    for (final pin in idList) {
      // Hydrate metadata while the page is assembled. Object bytes remain
      // lazy and are fetched only by the image widget that needs them.
      if (!pin.isPhotoUpdate) {
        if (!widget.thumbnailsOnly) {
          _prefetchKey(coalescer, BatchReadKind.pinImage, pin.pinId);
        }
        _prefetchKey(coalescer, BatchReadKind.pinImageThumbnail, pin.pinId);
      }
      _prefetchKey(coalescer, BatchReadKind.userImageSmall, pin.creator);
      if (pin.creator.isNotEmpty) ref.read(userServiceProvider(pin.creator));
      ref.read(likeServiceProvider(pin.entryId));
    }
    _prefetchNextPageMetadata(end, pageSize);
    return idList;
  }

  void _prefetchNextPageMetadata(int start, int pageSize) {
    final end = (start + pageSize).clamp(0, _pins.length);
    final coalescer = ref.read(batchReadCoalescerProvider);
    final pins = _pins.getRange(start, end).toList(growable: false);
    for (final pin in pins) {
      if (!pin.isPhotoUpdate) {
        if (!widget.thumbnailsOnly) {
          _prefetchKey(coalescer, BatchReadKind.pinImage, pin.pinId);
        }
        _prefetchKey(coalescer, BatchReadKind.pinImageThumbnail, pin.pinId);
      }
      _prefetchKey(coalescer, BatchReadKind.userImageSmall, pin.creator);
      if (pin.creator.isNotEmpty) ref.read(userServiceProvider(pin.creator));
      ref.read(likeServiceProvider(pin.entryId));
    }
  }

  void _ignorePrefetchError(Future<Object?> future) {
    unawaited(future.then<void>((_) {}, onError: (_, _) {}));
  }

  void _prefetchKey(
    BatchReadCoalescer coalescer,
    BatchReadKind kind,
    String id,
  ) {
    try {
      final suppliedUrl = ref
          .read(suppliedImageUrlRegistryProvider)
          .lookup(kind, id);
      if (suppliedUrl != null) return;
      _ignorePrefetchError(coalescer.readKey(BatchReadKey(kind, id)));
    } catch (_) {
      // Prefetch is an optimization; page assembly must remain usable while
      // the application bootstrap is still being installed.
    }
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Loading pins',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}
