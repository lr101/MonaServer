import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/remote_image/remote_image.dart';
import 'package:flutter/material.dart';

/// Pin-specific convenience adapter; all display and caching policy is shared.
class RemotePinImage extends StatelessWidget {
  const RemotePinImage({
    super.key,
    required this.pinId,
    this.photoId,
    this.thumbnailUrl,
    this.imageUrl,
    this.blurhash,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.policy = RemoteImagePolicy.thumbnail,
  });
  final String pinId;
  final String? photoId;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? blurhash;
  final BoxFit fit;
  final Alignment alignment;
  final RemoteImagePolicy policy;
  @override
  Widget build(BuildContext context) => RemoteImage(
    image: RemoteImageReference(
      kind: RemoteImageKind.pin,
      id: pinId,
      photoId: photoId,
      thumbnailUrl: thumbnailUrl,
      imageUrl: imageUrl,
    ),
    blurhash: blurhash,
    fit: fit,
    alignment: alignment,
    policy: policy,
  );
}
