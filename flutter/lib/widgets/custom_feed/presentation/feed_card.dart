import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedCard extends ConsumerWidget {
  const FeedCard({super.key, this.thumbnailsOnly = false});

  final bool thumbnailsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(feedItemProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = maxWidth * 4 / 3;
          if (thumbnailsOnly) {
            return FeedCardThumbnail(
              item: item,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            );
          }
          return FeedCardImage(
            item: item,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          );
        },
      ),
    );
  }
}
