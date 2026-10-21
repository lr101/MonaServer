import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class UserImageFeed extends ConsumerStatefulWidget {
  const UserImageFeed({
    super.key,
    required this.index,
    this.entryId,
    required this.userId,
    required this.userPinNotifier,
  });

  final int index;
  final String? entryId;
  final String userId;
  final ProviderListenable<AsyncValue<List<PinEntity>>> userPinNotifier;

  @override
  ConsumerState<UserImageFeed> createState() => _UserImageFeedState();
}

class _UserImageFeedState extends ConsumerState<UserImageFeed> {
  PagingController<int, PinEntity>? _pagingController;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _pagingController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(widget.userPinNotifier);
    return Scaffold(
      appBar: AppBar(title: const Text("User images")),
      body: pins.when(
        skipError: pins.hasValue,
        data: (data) {
          final selected = data.indexWhere(
            (item) => item.entryId == widget.entryId,
          );
          final initialIndex = selected < 0 ? widget.index : selected;
          final initialItems = data.take(initialIndex + 1).toList();
          final pagingController = _pagingController ??=
              PagingController.fromValue(
                PagingState<int, PinEntity>(
                  nextPageKey: initialItems.length < data.length
                      ? initialItems.length
                      : null,
                  itemList: initialItems,
                ),
                firstPageKey: 0,
              );
          return CustomScrollView(
            controller: _scrollController,
            scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
            slivers: [
              CustomFeed(
                pinProvider: widget.userPinNotifier,
                index: initialIndex,
                entryId: widget.entryId,
                pagingController: pagingController,
                scrollController: _scrollController,
                thumbnailsOnly: true,
              ),
            ],
          );
        },
        error: (error, stackTrace) => const Center(child: Icon(Icons.error)),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
