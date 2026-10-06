import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedCard extends ConsumerWidget {
  const FeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) => FeedCardImage(
        item: ref.watch(feedItemProvider),
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxWidth * 4 / 3,
      ),
    ),
  );
}
