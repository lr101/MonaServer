import 'package:buff_lisa/widgets/custom_feed/data/feed_item_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapPanelFeedCard extends ConsumerWidget {
  const MapPanelFeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FeedCardImage(
        item: ref.watch(feedItemProvider),
        maxWidth: (constraints.maxWidth - 32).clamp(1, double.infinity),
        maxHeight:
            (constraints.maxWidth - 32).clamp(1, double.infinity) * 4 / 3,
      ),
    ),
  );
}
