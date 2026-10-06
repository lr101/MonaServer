import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_thumbnail_prefetch_coordinator.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class ImageGrid extends ConsumerStatefulWidget {
  const ImageGrid({super.key, required this.pinProvider});

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;

  @override
  ConsumerState<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<ImageGrid> {
  final PagingController<int, PinEntity> _pagingController = PagingController(
    firstPageKey: 0,
    invisibleItemsThreshold: 12,
  );
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 18;
  static const int _prefetchCount = 6;
  static const int _columns = 3;
  static const double _crossAxisSpacing = 5;

  late final PageRequestListener<int> _pageRequestListener;
  List<PinEntity> _images = [];
  final Set<String> _thumbnailPrefetchTargets = {};
  PinThumbnailPrefetchCoordinator? _thumbnailPrefetchCoordinator;
  double _tileLogicalWidth = 120;
  double _devicePixelRatio = 1;
  int? _lastPrefetchCacheWidth;
  ScrollDirection _lastScrollDirection = ScrollDirection.reverse;

  bool isInitial = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pageRequestListener = (pageKey) => unawaited(_fetchPage(pageKey));
    _pagingController.addPageRequestListener(_pageRequestListener);
    _scrollController.addListener(_handleGridScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyProviderValue(ref.read(widget.pinProvider));
    });
  }

  @override
  void dispose() {
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
    _scrollController.removeListener(_handleGridScroll);
    _scrollController.dispose();
    _pagingController.removePageRequestListener(_pageRequestListener);
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.pinProvider, (previous, next) {
      _applyProviderValue(next);
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final contentWidth = (constraints.maxWidth - padding.horizontal).clamp(
          1.0,
          double.infinity,
        );
        final oldCacheWidth = _prefetchCacheWidth;
        _tileLogicalWidth =
            ((contentWidth - _crossAxisSpacing * (_columns - 1)) / _columns)
                .clamp(1.0, double.infinity);
        _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        if (oldCacheWidth != _prefetchCacheWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updatePrefetchWindowForScroll();
          });
        }
        final cacheExtent = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.5
            : 400.0;

        return PagedGridView<int, PinEntity>(
          pagingController: _pagingController,
          scrollController: _scrollController,
          padding: padding,
          cacheExtent: cacheExtent,
          showNewPageProgressIndicatorAsGridChild: false,
          builderDelegate: PagedChildBuilderDelegate<PinEntity>(
            itemBuilder: (context, item, index) => SquareImage(
              pinId: item.pinId,
              imageBlurhash: item.imageBlurhash,
              photoUrl: item.photoUrl,
              photoThumbnailUrl: item.photoThumbnailUrl,
              photoId: item.photoId,
              index: index,
              groupId: item.groupId,
              onTap: (index) => context.pushNamed(
                "viewImage",
                pathParameters: {"id": item.pinId},
                queryParameters: item.photoId == null
                    ? {}
                    : {"photo": item.photoId},
              ),
            ),
            noItemsFoundIndicatorBuilder: (context) => Center(
              child: isInitial
                  ? const CircularProgressIndicator()
                  : _errorMessage != null
                  ? Text(_errorMessage!)
                  : const Text("No images found"),
            ),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            crossAxisSpacing: _crossAxisSpacing,
            mainAxisSpacing: _crossAxisSpacing,
          ),
        );
      },
    );
  }

  void _applyProviderValue(AsyncValue<List<PinEntity>?> next) {
    if (next.hasError) {
      isInitial = false;
      if (_images.isEmpty) {
        _errorMessage = "Unable to load images";
      }
      _cancelThumbnailPrefetches();
      _pagingController.refresh();
      return;
    }

    final data = next.value;
    if (data == null) return;

    _errorMessage = null;
    _images = data;
    isInitial = false;
    _cancelThumbnailPrefetches();
    _pagingController.refresh();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      int end;
      final images = _images;
      if (pageKey + _pageSize > images.length) {
        end = images.length;
      } else {
        end = pageKey + _pageSize;
      }
      final idList = images.getRange(pageKey, end).toList();
      if (idList.isNotEmpty) {
        try {
          final coalescer = ref.read(batchReadCoalescerProvider);
          for (final pin in idList) {
            if (!pin.isPhotoUpdate) _prefetchPinImage(coalescer, pin.pinId);
          }
        } catch (_) {
          // Prefetch is an optimization and must not fail the page.
        }
        _prefetchPageThumbnails(idList);
      }
      if (end == images.length) {
        _pagingController.appendLastPage(idList);
      } else {
        _pagingController.appendPage(idList, pageKey + _pageSize);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  void _prefetchPinImage(BatchReadCoalescer coalescer, String pinId) {
    try {
      final suppliedUrl = ref
          .read(suppliedImageUrlRegistryProvider)
          .lookup(BatchReadKind.pinImageThumbnail, pinId);
      if (suppliedUrl != null) return;
      final future = coalescer.readKey(
        BatchReadKey(BatchReadKind.pinImageThumbnail, pinId),
      );
      unawaited(future.then<void>((_) {}, onError: (_, _) {}));
    } catch (_) {
      // Prefetch is an optimization and must not turn into a page error.
    }
  }

  void _prefetchPageThumbnails(List<PinEntity> pins) {
    _setThumbnailPrefetchWindow(
      pins.where((pin) => !pin.isPhotoUpdate).take(_prefetchCount),
    );
  }

  void _handleGridScroll() {
    if (!_scrollController.hasClients) return;
    final direction = _scrollController.position.userScrollDirection;
    if (direction != ScrollDirection.idle) {
      _lastScrollDirection = direction;
    }
    _updatePrefetchWindowForScroll();
  }

  void _updatePrefetchWindowForScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final loadedPins = _pagingController.itemList ?? const <PinEntity>[];
    if (loadedPins.isEmpty) return;

    final position = _scrollController.position;
    final topPadding = MediaQuery.paddingOf(context).top;
    final rowExtent = _tileLogicalWidth + _crossAxisSpacing;
    final contentOffset = (position.pixels - topPadding).clamp(
      0.0,
      double.infinity,
    );
    final firstVisibleRow = (contentOffset / rowExtent).floor();
    final visibleRowCount = (position.viewportDimension / rowExtent).ceil();
    final lastLoadedRow = (loadedPins.length - 1) ~/ _columns;
    final firstPrefetchRow = _lastScrollDirection == ScrollDirection.forward
        ? (firstVisibleRow - 2).clamp(0, lastLoadedRow)
        : firstVisibleRow + visibleRowCount;
    final firstIndex = firstPrefetchRow * _columns;
    if (firstIndex >= loadedPins.length) {
      _setThumbnailPrefetchWindow(const <PinEntity>[]);
      return;
    }
    _setThumbnailPrefetchWindow(
      loadedPins
          .skip(firstIndex)
          .where((pin) => !pin.isPhotoUpdate)
          .take(_prefetchCount),
    );
  }

  void _setThumbnailPrefetchWindow(Iterable<PinEntity> pins) {
    final pagePins = pins
        .where((pin) => !pin.isPhotoUpdate)
        .take(_prefetchCount)
        .toList(growable: false);
    final targetIds = pagePins.map((pin) => pin.pinId).toSet();
    final logicalWidth = _tileLogicalWidth.clamp(1.0, double.infinity);
    final devicePixelRatio = _devicePixelRatio;
    final cacheWidth = _prefetchCacheWidth;
    final previousCoordinator = _thumbnailPrefetchCoordinator;
    final coordinator = _currentPrefetchCoordinator();
    final coordinatorChanged = !identical(previousCoordinator, coordinator);
    final sameTargets =
        targetIds.length == _thumbnailPrefetchTargets.length &&
        targetIds.containsAll(_thumbnailPrefetchTargets);
    if (!coordinatorChanged &&
        sameTargets &&
        cacheWidth == _lastPrefetchCacheWidth) {
      return;
    }

    _thumbnailPrefetchTargets
      ..clear()
      ..addAll(targetIds);
    _lastPrefetchCacheWidth = cacheWidth;
    final imageSize = Size(logicalWidth, logicalWidth);
    final requests = <String, PinThumbnailWarmer>{
      for (final pin in pagePins)
        pin.pinId: (bytes) => _precacheThumbnail(
          pin.pinId,
          bytes,
          logicalWidth: logicalWidth,
          devicePixelRatio: devicePixelRatio,
          imageSize: imageSize,
        ),
    };
    coordinator.updateWindow(this, requests);
  }

  int get _prefetchCacheWidth =>
      (_tileLogicalWidth * _devicePixelRatio).ceil().clamp(1, 720);

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

  void _cancelThumbnailPrefetches() {
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
  }

  PinThumbnailPrefetchCoordinator _currentPrefetchCoordinator() {
    final current = ref.read(pinThumbnailPrefetchCoordinatorProvider);
    if (!identical(current, _thumbnailPrefetchCoordinator)) {
      _thumbnailPrefetchCoordinator?.cancelWindow(this);
      _thumbnailPrefetchCoordinator = current;
    }
    return current;
  }
}
