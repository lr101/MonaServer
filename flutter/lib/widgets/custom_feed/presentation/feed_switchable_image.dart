import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        .read(feedMapStateProvider(item.pinId).notifier)
        .update;
    final isBig = ref.watch(feedMapStateProvider(item.pinId));
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onDoubleTap: isBig ? () => likeImage() : null,
        onTap: isBig && onTab != null
            ? () => onTab!(LatLng(item.latitude, item.longitude), 18)
            : !isBig
            ? switchFun
            : null,
        child: ColoredBox(
          color: Colors.grey.withValues(alpha: 0.5),
          child: FadeInImage(
            fadeInDuration: const Duration(milliseconds: 100),
            fit: BoxFit.cover,
            placeholder: MemoryImage(kTransparentImage),
            image: image == null
                ? MemoryImage(kTransparentImage)
                : memoryImageForDisplay(
                    image!,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    logicalWidth: constraints.maxWidth,
                    maximumCacheWidth: 720,
                  ),
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}
