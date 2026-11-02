import 'package:buff_lisa/widgets/custom_feed/data/feed_snapshot.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_thumbnail_prefetch_coordinator.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
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
  static const int _thumbnailPrefetchPageCount = 2;

  List<PinEntity> _pins = [];
  String? _initialEntryId;
  final GlobalKey _initialItemKey = GlobalKey();
  final Set<String> _thumbnailPrefetchTargets = {};
  PinThumbnailPrefetchCoordinator? _thumbnailPrefetchCoordinator;
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
              keys: [0],
              hasNextPage: initialCount < _pins.length,
            ),
      getNextPageKey: (state) {
        final count = state.items?.length ?? 0;
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
  void dispose() {
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
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
      if (!next.hasValue || next.isLoading || next.hasError) return;
      final incoming = next.value ?? <PinEntity>[];
      final loaded = _pagingController.value.items?.length ?? 0;
      _pins = reconcileFeedEntries(_pins, incoming, loaded);
      if (loaded == 0) {
        _pagingController.refresh();
      } else {
        final count = loaded.clamp(0, _pins.length);
        _pagingController.cancel();
        _pagingController.value = PagingState(
          pages: [_pins.take(count).toList()],
          keys: [0],
          hasNextPage: count < _pins.length,
        );
      }
    });
    return PagingListener<int, PinEntity>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) =>
          PagedSliverList<int, PinEntity>(
            state: state,
            fetchNextPage: fetchNextPage,
            addAutomaticKeepAlives: false,
            builderDelegate: PagedChildBuilderDelegate<PinEntity>(
              animateTransitions: true,
              invisibleItemsThreshold: widget.invisibleItemsThreshold,
              itemBuilder: (context, item, index) => ProviderScope(
                key: item.entryId == _initialEntryId
                    ? _initialItemKey
                    : ValueKey(item.entryId),
                child: ProviderScope(
                  key: ValueKey(item.entryId),
                  overrides: [feedItemProvider.overrideWithValue(item)],
                  child: FeedCard(thumbnailsOnly: widget.thumbnailsOnly),
                ),
              ),
            ),
          ),
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
    _prefetchNextPageThumbnails(end, pageSize);
    return idList;
  }

  void _prefetchNextPageThumbnails(int start, int pageSize) {
    final end = (start + pageSize * _thumbnailPrefetchPageCount).clamp(
      0,
      _pins.length,
    );
    final lookAheadIds = _pins
        .getRange(start, end)
        .where((pin) => !pin.isPhotoUpdate)
        .map((pin) => pin.pinId)
        .toSet();

    _thumbnailPrefetchTargets
      ..clear()
      ..addAll(lookAheadIds);
    final logicalWidth = (MediaQuery.sizeOf(context).width - 36).clamp(
      1.0,
      double.infinity,
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final imageSize = Size(logicalWidth, logicalWidth * 4 / 3);
    final requests = <String, PinThumbnailWarmer>{
      for (final id in lookAheadIds)
        id: (bytes) => _precacheThumbnail(
          id,
          bytes,
          logicalWidth: logicalWidth,
          devicePixelRatio: devicePixelRatio,
          imageSize: imageSize,
        ),
    };
    _currentPrefetchCoordinator().updateWindow(this, requests);
  }

  PinThumbnailPrefetchCoordinator _currentPrefetchCoordinator() {
    final current = ref.read(pinThumbnailPrefetchCoordinatorProvider);
    if (!identical(current, _thumbnailPrefetchCoordinator)) {
      _thumbnailPrefetchCoordinator?.cancelWindow(this);
      _thumbnailPrefetchCoordinator = current;
    }
    return current;
  }

  Future<void> _precacheThumbnail(
    String pinId,
    Uint8List bytes, {
    required double logicalWidth,
    required double devicePixelRatio,
    required Size imageSize,
  }) async {
    if (!mounted || !_thumbnailPrefetchTargets.contains(pinId)) return;
    final imageProvider = memoryImageForDisplay(
      bytes,
      devicePixelRatio: devicePixelRatio,
      logicalWidth: logicalWidth,
      maximumCacheWidth: 720,
    );
    await precacheImage(
      imageProvider,
      context,
      size: imageSize,
      onError: (error, stackTrace) {},
    );
  }

  void _prefetchNextPageMetadata(int start, int pageSize) {
    final end = (start + pageSize).clamp(0, _pins.length);
    final coalescer = ref.read(batchReadCoalescerProvider);
    final pins = _pins.getRange(start, end).toList(growable: false);
    for (final pin in pins) {
      if (!pin.isPhotoUpdate && !widget.thumbnailsOnly) {
        _prefetchKey(coalescer, BatchReadKind.pinImage, pin.pinId);
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
