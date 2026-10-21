import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/remote_image/remote_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RemoteRoundImage extends ConsumerWidget {
  const RemoteRoundImage({
    super.key,
    required this.image,
    required this.radius,
    this.progressive = false,
    this.child,
  });
  final RemoteImageReference image;
  final double radius;
  final bool progressive;
  final Widget? child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Image.memory(
      ref.watch(defaultErrorImageProvider),
      fit: BoxFit.cover,
    );
    return SizedBox.square(
      dimension: radius * 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          ),
          ClipOval(
            child: RemoteImage(
              image: image,
              policy: progressive
                  ? RemoteImagePolicy.previewThenFull
                  : RemoteImagePolicy.thumbnail,
              placeholder: fallback,
              errorWidget: fallback,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
