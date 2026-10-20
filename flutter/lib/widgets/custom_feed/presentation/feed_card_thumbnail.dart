import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/remote_pin_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Image-only profile-list card, with a thumbnail preview and full-size upgrade.
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
              child: RemotePinImage(
                pinId: item.pinId,
                photoId: item.photoId,
                thumbnailUrl: item.photoThumbnailUrl,
                imageUrl: item.photoUrl,
                blurhash: item.imageBlurhash,
                policy: RemoteImagePolicy.previewThenFull,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
