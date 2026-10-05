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
  static const int _thumbnailPrefetchPageCount = 2;

  List<PinEntity> _pins = [];
  final GlobalKey _initialItemKey = GlobalKey();
  final Set<String> _thumbnailPrefetchTargets = {};
  PinThumbnailPrefetchCoordinator? _thumbnailPrefetchCoordinator;
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
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
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
      _thumbnailPrefetchTargets.clear();
      _thumbnailPrefetchCoordinator?.cancelWindow(this);
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
      final coalescer = ref.read(batchReadCoalescerProvider);
      for (final pin in idList) {
        // Hydrate current-page metadata while the page is assembled.
        _prefetchKey(coalescer, BatchReadKind.pinImageThumbnail, pin.pinId);
        _prefetchKey(coalescer, BatchReadKind.userImageSmall, pin.creator);
        ref.read(userServiceProvider(pin.creator));
        ref.read(likeServiceProvider(pin.pinId));
      }
      _prefetchNextPageMetadata(end, pageSize);
      _prefetchNextPageThumbnails(end, pageSize);
      if (!mounted) return;
      if (end == _pins.length) {
        widget.pagingController.appendLastPage(idList);
      } else {
        widget.pagingController.appendPage(idList, pageKey + pageSize);
      }
    } catch (error) {
      if (mounted) widget.pagingController.error = error;
    }
  }

  void _prefetchNextPageThumbnails(int start, int pageSize) {
    final end = (start + pageSize * _thumbnailPrefetchPageCount).clamp(
      0,
      _pins.length,
    );
    final lookAheadIds = _pins
        .getRange(start, end)
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
    final thumbnailEnd = (start + pageSize * _thumbnailPrefetchPageCount).clamp(
      0,
      _pins.length,
    );
    final coalescer = ref.read(batchReadCoalescerProvider);
    final thumbnailPins = _pins
        .getRange(start, thumbnailEnd)
        .toList(growable: false);
    for (final pin in thumbnailPins) {
      _prefetchKey(coalescer, BatchReadKind.pinImageThumbnail, pin.pinId);
    }

    final metadataEnd = (start + pageSize).clamp(0, _pins.length);
    final metadataPins = _pins
        .getRange(start, metadataEnd)
        .toList(growable: false);
    for (final pin in metadataPins) {
      _prefetchKey(coalescer, BatchReadKind.userImageSmall, pin.creator);
      ref.read(userServiceProvider(pin.creator));
      ref.read(likeServiceProvider(pin.pinId));
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
