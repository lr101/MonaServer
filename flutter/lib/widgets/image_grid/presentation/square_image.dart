import 'package:buff_lisa/widgets/pin_image/presentation/remote_pin_image.dart';
import 'package:flutter/material.dart';

class SquareImage extends StatelessWidget {
  const SquareImage({
    super.key,
    required this.pinId,
    this.imageBlurhash,
    required this.groupId,
    this.photoUrl,
    this.photoThumbnailUrl,
    this.photoId,
    required this.index,
    required this.onTap,
  });

  final String pinId;
  final String? imageBlurhash;
  final String groupId;
  final String? photoUrl;
  final String? photoThumbnailUrl;
  final String? photoId;
  final int index;
  final Function(int index) onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onTap(index),
    behavior: HitTestBehavior.opaque,
    child: RemotePinImage(
      pinId: pinId,
      photoId: photoId,
      thumbnailUrl: photoThumbnailUrl,
      imageUrl: photoUrl,
      blurhash: imageBlurhash,
    ),
  );
}
