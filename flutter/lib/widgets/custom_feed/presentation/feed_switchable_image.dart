import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class FeedSwitchableImage extends ConsumerStatefulWidget {
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
  ConsumerState<FeedSwitchableImage> createState() =>
      _FeedSwitchableImageState();
}

class _FeedSwitchableImageState extends ConsumerState<FeedSwitchableImage> {
  Uint8List? _displayImage;
  bool _hasDisplayedImage = false;

  @override
  void initState() {
    super.initState();
    _displayImage = widget.image;
  }

  @override
  void didUpdateWidget(covariant FeedSwitchableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.pinId != widget.item.pinId) {
      _displayImage = widget.image;
      _hasDisplayedImage = false;
    } else if (widget.image != null) {
      // Keep the last decoded preview visible while the full image replaces it.
      _displayImage = widget.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    final switchFun = ref
        .read(feedMapStateProvider(widget.item.pinId).notifier)
        .update;
    final isBig = ref.watch(feedMapStateProvider(widget.item.pinId));
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onDoubleTap: isBig ? () => widget.likeImage() : null,
        onTap: isBig && widget.onTab != null
            ? () => widget.onTab!(
                LatLng(widget.item.latitude, widget.item.longitude),
                18,
              )
            : !isBig
            ? switchFun
            : null,
        child: ColoredBox(
          color: Colors.grey.withValues(alpha: 0.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PinImagePlaceholder(blurhash: widget.item.imageBlurhash),
              if (_displayImage != null)
                Image(
                  fit: BoxFit.cover,
                  image: memoryImageForDisplay(
                    _displayImage!,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    logicalWidth: constraints.maxWidth,
                    maximumCacheWidth: 720,
                  ),
                  width: double.infinity,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          _hasDisplayedImage = true;
                        }
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          opacity: _hasDisplayedImage ? 1 : 0,
                          child: child,
                        );
                      },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
