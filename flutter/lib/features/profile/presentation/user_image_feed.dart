import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
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
          return CustomScrollView(
            controller: _scrollController,
            scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
            slivers: [
              CustomFeed(
                pinProvider: widget.userPinNotifier,
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
