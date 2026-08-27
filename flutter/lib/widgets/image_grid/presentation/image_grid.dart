import 'package:buff_lisa/data/entity/pin_entity.dart';
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

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.watch(widget.pinProvider).whenData((data) {
        if (data != null) {
          _images = data;
          isInitial = false;
          _pagingController.refresh();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.pinProvider, (previous, next) {
      if (next.value != null && next.value!.isEmpty) isInitial = false;
      _images = next.value ?? [];
      _pagingController.refresh();
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
      if (end == images.length) {
        _pagingController.appendLastPage(idList);
      } else {
        _pagingController.appendPage(idList, pageKey + _pageSize);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }
}
