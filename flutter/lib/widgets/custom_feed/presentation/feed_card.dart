import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedCard extends ConsumerWidget {
  const FeedCard({
    super.key,
    this.thumbnailsOnly = false,
    this.inGrid = false,
    this.gridImageHeight,
  });

  final bool thumbnailsOnly;
  final bool inGrid;
  final double? gridImageHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(feedItemProvider);
    final viewport = MediaQuery.sizeOf(context);
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final defaultHeight = maxWidth * 4 / 3;
            final maxHeight = gridImageHeight ??
                (viewport.width >= 600
                    ? defaultHeight.clamp(280.0, viewport.height * 0.54)
                    : defaultHeight);
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
      ),
    );
    if (inGrid) {
      return card;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: card,
        ),
      ),
    );
  }
}
