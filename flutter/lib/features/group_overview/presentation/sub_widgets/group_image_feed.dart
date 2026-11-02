import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupImageFeed extends ConsumerStatefulWidget {
  const GroupImageFeed({
    super.key,
    required this.index,
    this.entryId,
    required this.groupId,
  });

  final int index;
  final String? entryId;
  final String groupId;

  @override
  ConsumerState<GroupImageFeed> createState() => _GroupImageFeedState();
}

class _GroupImageFeedState extends ConsumerState<GroupImageFeed> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = ref.watch(groupPinEntriesProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text("Group images")),
      body: pins.when(
        skipError: pins.hasValue,
        data: (data) {
          final items = data;
          final selected = items.indexWhere(
            (item) => item.entryId == widget.entryId,
          );
          final initialIndex = selected < 0 ? widget.index : selected;
          return CustomScrollView(
            controller: _scrollController,
            scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
            slivers: [
              CustomFeed(
                pinProvider: groupPinEntriesProvider(widget.groupId),
                index: initialIndex,
                entryId: widget.entryId,
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
