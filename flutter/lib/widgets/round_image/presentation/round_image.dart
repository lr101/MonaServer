import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class RoundImage extends ConsumerWidget {

  final AsyncValue<Uint8List?> imageCallback;
  final bool clickable;
  final double? size;
  final Widget? child;
  final VoidCallback? handleOpenImage;
  final Uint8List? defaultPlaceholderImage;

  const RoundImage({super.key, required this.imageCallback, this.clickable = false, this.size, this.child, this.handleOpenImage, this.defaultPlaceholderImage}) : assert (clickable && handleOpenImage != null || !clickable);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _clickable(
          context: context,
          child: SizedBox.square(
              dimension: size != null ? size! * 2 : null,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),

                  ),

                ClipOval(
                    child: FadeInImage(
                      height: size != null ? size! * 2 : null,
                      width: size != null ? size! * 2 : null,
                    placeholder: MemoryImage(kTransparentImage),
                    image: MemoryImage(imageCallback.when<Uint8List>(
                        data: (data) => data ?? defaultPlaceholderImage ?? ref.watch(defaultErrorImageProvider),
                        error: (_,trace) => defaultPlaceholderImage ?? ref.watch(defaultErrorImageProvider),
                        loading: () => kTransparentImage,
                    ),),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    fadeOutDuration: const Duration(milliseconds: 250),
                    imageErrorBuilder: (_, obj, trace) => Image.memory(
                      ref.watch(defaultErrorImageProvider),
                      fit: BoxFit.cover,
                    ),
                ),
              ),
                if (child != null) child!,
              ],),
          ),
        );
  }

  Widget _clickable({required Widget child, required BuildContext context}) {
    if (clickable) {
      return GestureDetector(
          onTap: handleOpenImage,
          child: child,
      );
    } else {
      return child;
    }
  }
}
