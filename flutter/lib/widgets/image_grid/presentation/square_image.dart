import 'dart:typed_data';

import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquareImage extends ConsumerStatefulWidget {
  final String pinId;
  final String? imageBlurhash;
  final String groupId;
  final int index;
  final Function(int index) onTap;

  const SquareImage({
    super.key,
    required this.pinId,
    this.imageBlurhash,
    required this.index,
    required this.groupId,
    required this.onTap,
  });

  @override
  ConsumerState<SquareImage> createState() => _SquareImageState();
}

class _SquareImageState extends ConsumerState<SquareImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _fetchThumbnail();
  }

  @override
  void didUpdateWidget(covariant SquareImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pinId != widget.pinId) {
      _imageFuture = _fetchThumbnail();
    }
  }

  Future<Uint8List?> _fetchThumbnail() =>
      ref.read(pinThumbnailRepositoryProvider).fetchImage(widget.pinId, false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FutureBuilder<Uint8List?>(
        future: _imageFuture,
        builder: (context, snapshot) {
          final isReady = snapshot.connectionState == ConnectionState.done;
          final image = isReady ? snapshot.data : null;

          return GestureDetector(
            onTap: image == null ? null : () => widget.onTap(widget.index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PinImagePlaceholder(blurhash: widget.imageBlurhash),
                if (image != null)
                  Image(
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    image: memoryImageForDisplay(
                      image,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      logicalWidth: constraints.maxWidth,
                      maximumCacheWidth: 720,
                    ),
                    gaplessPlayback: true,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) =>
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              opacity: wasSynchronouslyLoaded || frame != null
                                  ? 1
                                  : 0,
                              child: child,
                            ),
                  ),
                if (isReady && image == null && widget.imageBlurhash == null)
                  const ColoredBox(
                    color: Colors.black12,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
