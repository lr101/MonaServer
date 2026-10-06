import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:transparent_image/transparent_image.dart';

class FeedSwitchableImage extends ConsumerWidget {
  final PinEntity item;
  final Uint8List? image;
  final VoidCallback likeImage;
  final Function(LatLng, double)? onTab;

  const FeedSwitchableImage({
    super.key,
    required this.item,
    required this.image,
    required this.likeImage,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchFun = ref
        .read(feedMapStateProvider(item.entryId).notifier)
        .update;
    final isBig = ref.watch(feedMapStateProvider(item.entryId));
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        button: true,
        label: 'Open pin and all photos',
        child: InkWell(
          onDoubleTap: isBig ? () => likeImage() : null,
          onTap: !isBig
              ? switchFun
              : () => context.pushNamed(
                  'viewImage',
                  pathParameters: {'id': item.pinId},
                  queryParameters: {
                    if (item.photoId != null) 'photo': item.photoId,
                  },
                ),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: FadeInImage(
              fadeInDuration: const Duration(milliseconds: 100),
              fit: BoxFit.contain,
              placeholder: MemoryImage(kTransparentImage),
              image: item.photoUrl != null
                  ? NetworkImage(item.photoUrl!)
                  : image == null
                  ? MemoryImage(kTransparentImage)
                  : memoryImageForDisplay(
                      image!,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      logicalWidth: constraints.maxWidth,
                      maximumCacheWidth: 720,
                    ),
              imageErrorBuilder: (context, error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_not_supported_outlined),
                    const SizedBox(height: 8),
                    Text(
                      'Photo unavailable',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
