import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FeedCardThumbnail extends ConsumerWidget {
  const FeedCardThumbnail({
    super.key,
    required this.item,
    required this.maxWidth,
    required this.maxHeight,
  });

  final PinEntity item;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageState = item.isPhotoUpdate
        ? ref.watch(
            pinPhotoThumbnailBytesProvider((
              photoId: item.photoId!,
              thumbnailUrl: item.photoThumbnailUrl,
              imageUrl: item.photoUrl,
            )),
          )
        : ref.watch(pinThumbnailBytesProvider(item.pinId));
    final image = imageState.value;

    return Semantics(
      button: true,
      label: 'Open photo details',
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: () => context.pushNamed(
                'viewImage',
                pathParameters: {'id': item.pinId},
                queryParameters: {
                  if (item.photoId != null) 'photo': item.photoId!,
                },
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PinImagePlaceholder(blurhash: item.imageBlurhash),
                  if (image != null && image.isNotEmpty)
                    Image(
                      image: memoryImageForDisplay(
                        image,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                        logicalWidth: maxWidth,
                        maximumCacheWidth: 720,
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true,
                    ),
                  if ((image == null || image.isEmpty) && imageState.hasError)
                    const ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
