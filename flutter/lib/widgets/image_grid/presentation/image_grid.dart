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

class ImageGrid extends ConsumerStatefulWidget {
  const ImageGrid({super.key, required this.pinProvider, this.onTap});

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;
  final ValueChanged<int>? onTap;

  @override
  ConsumerState<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<ImageGrid> {
  static const int _columns = 3;
  static const int _prefetchRows = 2;
  static const double _spacing = 5;

  List<PinEntity> _images = const [];
  final Set<String> _thumbnailPrefetchTargets = {};
  PinThumbnailPrefetchCoordinator? _thumbnailPrefetchCoordinator;
  ScrollMetrics? _lastScrollMetrics;
  ScrollDirection _lastScrollDirection = ScrollDirection.reverse;
  double _tileLogicalWidth = 120;
  int? _lastPrefetchCacheWidth;
  int? _lastThumbnailPrefetchCacheWidth;

  @override
  void dispose() {
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.pinProvider);
    if (state.hasValue) {
      _images = state.value ?? const <PinEntity>[];
    }
    if (_images.isEmpty) {
      _cancelThumbnailPrefetches();
      return Center(
        child: state.hasError
            ? const Text('Unable to load images')
            : state.isLoading
            ? const CircularProgressIndicator()
            : const Text('No images found'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final contentWidth = (constraints.maxWidth - padding.horizontal).clamp(
          1.0,
          double.infinity,
        );
        _tileLogicalWidth =
            ((contentWidth - _spacing * (_columns - 1)) / _columns).clamp(
              1.0,
              double.infinity,
            );
        final cacheWidth = _prefetchCacheWidth;
        if (_lastPrefetchCacheWidth != cacheWidth) {
          _lastPrefetchCacheWidth = cacheWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final metrics = _lastScrollMetrics;
            if (mounted && metrics != null) {
              _updatePrefetchWindowForMetrics(metrics);
            }
          });
        }

        return NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleMetrics,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: GridView.builder(
              primary: true,
              padding: padding,
              // Retain loaded neighbors through small reversals. Image streams
              // stay attached, preventing placeholders from flashing back in.
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              itemCount: _images.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = _images.indexWhere(
                  (pin) => pin.entryId == key.value,
                );
                return index < 0 ? null : index;
              },
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: _spacing,
                mainAxisSpacing: _spacing,
              ),
              itemBuilder: (context, index) {
                final item = _images[index];
                return SquareImage(
                  key: ValueKey(item.entryId),
                  pinId: item.pinId,
                  imageBlurhash: item.imageBlurhash,
                  photoUrl: item.photoUrl,
                  photoThumbnailUrl: item.photoThumbnailUrl,
                  photoId: item.photoId,
                  index: index,
                  groupId: item.groupId,
                  onTap: (index) {
                    final tap = widget.onTap;
                    if (tap != null) {
                      tap(index);
                      return;
                    }
                    context.pushNamed(
                      'viewImage',
                      pathParameters: {'id': item.pinId},
                      queryParameters: item.photoId == null
                          ? {}
                          : {'photo': item.photoId},
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _handleMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    _lastScrollMetrics = notification.metrics;
    _updatePrefetchWindowForMetrics(notification.metrics);
    return false;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _lastScrollMetrics = notification.metrics;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _lastScrollDirection = notification.direction;
    }
    if (notification is ScrollUpdateNotification ||
        notification is UserScrollNotification) {
      _updatePrefetchWindowForMetrics(notification.metrics);
    }
    return false;
  }

  void _updatePrefetchWindowForMetrics(ScrollMetrics metrics) {
    if (!mounted || _images.isEmpty) return;

    final padding = MediaQuery.paddingOf(context);
    final rowExtent = _tileLogicalWidth + _spacing;
    final contentOffset = (metrics.pixels - padding.top).clamp(
      0.0,
      double.infinity,
    );
    final firstVisibleRow = (contentOffset / rowExtent).floor();
    final visibleRowCount = (metrics.viewportDimension / rowExtent)
        .ceil()
        .clamp(1, (_images.length + _columns - 1) ~/ _columns);
    final rowCount = (_images.length + _columns - 1) ~/ _columns;

    // Resolve the current screen and two rows in its travel direction together.
    // This turns per-tile URL lookups into one small authenticated batch before
    // the bounded byte prefetch starts.
    final metadataStartRow = (firstVisibleRow - 1).clamp(0, rowCount);
    final metadataEndRow = (firstVisibleRow + visibleRowCount + _prefetchRows)
        .clamp(metadataStartRow, rowCount);
    final metadataPins = _images
        .skip(metadataStartRow * _columns)
        .take((metadataEndRow - metadataStartRow) * _columns)
        .where((pin) => !pin.isPhotoUpdate);
    _prefetchImageUrls(metadataPins);

    final firstPrefetchRow = _lastScrollDirection == ScrollDirection.forward
        ? (firstVisibleRow - _prefetchRows).clamp(0, rowCount)
        : (firstVisibleRow + visibleRowCount).clamp(0, rowCount);
    final startIndex = firstPrefetchRow * _columns;
    final lookAhead = _images
        .skip(startIndex)
        .where((pin) => !pin.isPhotoUpdate)
        .take(_columns * _prefetchRows)
        .toList(growable: false);
    _setThumbnailPrefetchWindow(lookAhead);
  }

  void _prefetchImageUrls(Iterable<PinEntity> pins) {
    try {
      final registry = ref.read(suppliedImageUrlRegistryProvider);
      final coalescer = ref.read(batchReadCoalescerProvider);
      const imageKinds = [
        BatchReadKind.pinImageThumbnail,
        BatchReadKind.pinImage,
      ];
      for (final pin in pins) {
        for (final kind in imageKinds) {
          if (registry.lookup(kind, pin.pinId) != null) continue;
          _ignorePrefetchError(
            coalescer.readKey(BatchReadKey(kind, pin.pinId)),
          );
        }
      }
    } catch (_) {
      // Metadata look-ahead is an optimization; visible tiles can still load.
    }
  }

  void _setThumbnailPrefetchWindow(List<PinEntity> pins) {
    final targetIds = pins.map((pin) => pin.pinId).toSet();
    final cacheWidth = _prefetchCacheWidth;
    if (targetIds.length == _thumbnailPrefetchTargets.length &&
        targetIds.containsAll(_thumbnailPrefetchTargets) &&
        cacheWidth == _lastThumbnailPrefetchCacheWidth) {
      return;
    }

    _thumbnailPrefetchTargets
      ..clear()
      ..addAll(targetIds);
    _lastThumbnailPrefetchCacheWidth = cacheWidth;
    final coordinator = _currentPrefetchCoordinator();
    if (coordinator == null) return;

    final logicalWidth = _tileLogicalWidth.clamp(1.0, double.infinity);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final imageSize = Size(logicalWidth, logicalWidth);
    coordinator.updateWindow(this, {
      for (final pin in pins)
        pin.pinId: (bytes) => _precacheThumbnail(
          pin.pinId,
          bytes,
          logicalWidth: logicalWidth,
          devicePixelRatio: devicePixelRatio,
          imageSize: imageSize,
        ),
    });
  }

  PinThumbnailPrefetchCoordinator? _currentPrefetchCoordinator() {
    try {
      final current = ref.read(pinThumbnailPrefetchCoordinatorProvider);
      if (!identical(current, _thumbnailPrefetchCoordinator)) {
        _thumbnailPrefetchCoordinator?.cancelWindow(this);
        _thumbnailPrefetchCoordinator = current;
      }
      return current;
    } catch (_) {
      return null;
    }
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

  void _cancelThumbnailPrefetches() {
    _thumbnailPrefetchTargets.clear();
    _thumbnailPrefetchCoordinator?.cancelWindow(this);
  }

  void _ignorePrefetchError(Future<Object?> future) {
    unawaited(future.then<void>((_) {}, onError: (_, _) {}));
  }

  int get _prefetchCacheWidth =>
      (_tileLogicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
        1,
        720,
      );
}
