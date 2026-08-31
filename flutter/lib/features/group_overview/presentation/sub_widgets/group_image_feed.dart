import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class GroupImageFeed extends ConsumerStatefulWidget {
  const GroupImageFeed({super.key, required this.index, required this.groupId});

  final int index;
  final String groupId;

  @override
  ConsumerState<GroupImageFeed> createState() => _GroupImageFeedState();
}

class _GroupImageFeedState extends ConsumerState<GroupImageFeed> {
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
    final pins = ref.watch(sortedGroupPinsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text("Group images")),
      body: pins.when(
        data: (data) {
          final items = data ?? <PinEntity>[];
          final initialItems = items.take(widget.index + 1).toList();
          final pagingController = _pagingController ??=
              PagingController.fromValue(
                PagingState<int, PinEntity>(
                  nextPageKey: initialItems.length < items.length
                      ? initialItems.length
                      : null,
                  itemList: initialItems,
                ),
                firstPageKey: 0,
              );
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              CustomFeed(
                pinProvider: sortedGroupPinsProvider(widget.groupId),
                index: widget.index,
                pagingController: pagingController,
                scrollController: _scrollController,
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
