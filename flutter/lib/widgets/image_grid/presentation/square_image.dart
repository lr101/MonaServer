import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquareImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final imageState = ref.watch(pinGridImageBytesProvider(pinId));
    final image = imageState.value;
    final imageUnavailable =
        image == null && (imageState.hasValue || imageState.hasError);

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTap: image == null ? null : () => onTap(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PinImagePlaceholder(blurhash: imageBlurhash),
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
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: wasSynchronouslyLoaded || frame != null ? 1 : 0,
                      child: child,
                    ),
              ),
            if (imageUnavailable && imageBlurhash == null)
              const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.image_not_supported_outlined)),
              ),
          ],
        ),
      ),
    );
  }
}
