import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

class ImageGrid extends ConsumerStatefulWidget {
  const ImageGrid({super.key, required this.pinProvider, this.onTap});

  final ProviderListenable<AsyncValue<List<PinEntity>?>> pinProvider;
  final ValueChanged<int>? onTap;

  @override
  ConsumerState<ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<ImageGrid> {
  static const int _columns = 3;
  static const double _spacing = 5;
  List<PinEntity> _images = const [];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.pinProvider);
    if (state.hasValue) _images = state.value ?? const <PinEntity>[];

    if (_images.isEmpty) {
      return Center(
        child: state.hasError
            ? const Text('Unable to load images')
            : state.isLoading
            ? const CircularProgressIndicator()
            : const Text('No images found'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final contentWidth = (constraints.maxWidth - padding.horizontal).clamp(
          1.0,
          double.infinity,
        );
        final tileWidth = (contentWidth - _spacing * (_columns - 1)) / _columns;
        return GridView.builder(
          primary: true,
          padding: padding,
          // Keep nearby rows mounted; each tile loads and fades in its image as
          // it approaches the view. RemoteImage shares downloads and cache.
          scrollCacheExtent: ScrollCacheExtent.pixels(tileWidth * 2),
          itemCount: _images.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final index = _images.indexWhere((pin) => pin.entryId == key.value);
            return index < 0 ? null : index;
          },
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
          ),
          itemBuilder: (context, index) {
            final item = _images[index];
            return SquareImage(
              key: ValueKey(item.entryId),
              pinId: item.pinId,
              imageBlurhash: item.imageBlurhash,
              photoUrl: item.photoUrl,
              photoThumbnailUrl: item.photoThumbnailUrl,
              photoId: item.photoId,
              index: index,
              groupId: item.groupId,
              onTap: (index) {
                final tap = widget.onTap;
                if (tap != null) {
                  tap(index);
                  return;
                }
                context.pushNamed(
                  'viewImage',
                  pathParameters: {'id': item.pinId},
                  queryParameters: item.photoId == null
                      ? {}
                      : {'photo': item.photoId},
                );
              },
            );
          },
        );
      },
    );
  }
}
