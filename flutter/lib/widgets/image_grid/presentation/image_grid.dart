import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
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
    invisibleItemsThreshold: 4,
  );

  final int _pageSize = 18;

  List<PinEntity> _images = [];

  bool isInitial = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyProviderValue(ref.read(widget.pinProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.pinProvider, (previous, next) {
      _applyProviderValue(next);
    });
    return PagedGridView<int, PinEntity>(
      pagingController: _pagingController,
      showNewPageProgressIndicatorAsGridChild: false,
      builderDelegate: PagedChildBuilderDelegate<PinEntity>(
        itemBuilder: (context, item, index) => SquareImage(
          pinId: item.pinId,
          index: index,
          groupId: item.groupId,
          onTap: (index) => context.pushNamed(
            "viewImage",
            pathParameters: {"id": item.pinId},
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
        crossAxisCount: 3,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
      ),
    );
  }

  void _applyProviderValue(AsyncValue<List<PinEntity>?> next) {
    if (next.hasError) {
      isInitial = false;
      if (_images.isEmpty) {
        _errorMessage = "Unable to load images";
      }
      _pagingController.refresh();
      return;
    }

    final data = next.value;
    if (data == null) return;

    _errorMessage = null;
    _images = data;
    isInitial = false;
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
            _prefetchPinImage(coalescer, pin.pinId);
          }
        } catch (_) {
          // Prefetch is an optimization and must not fail the page.
        }
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
          .lookup(BatchReadKind.pinImage, pinId);
      if (suppliedUrl != null) return;
      final future = coalescer.readKey(
        BatchReadKey(BatchReadKind.pinImage, pinId),
      );
      unawaited(future.then<void>((_) {}, onError: (_, _) {}));
    } catch (_) {
      // Prefetch is an optimization and must not turn into a page error.
    }
  }
}
