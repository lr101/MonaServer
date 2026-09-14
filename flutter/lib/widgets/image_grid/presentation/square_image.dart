import 'dart:typed_data';

import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class SquareImage extends ConsumerStatefulWidget {
  final String pinId;
  final String groupId;
  final int index;
  final Function(int index) onTap;

  const SquareImage({
    super.key,
    required this.pinId,
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
    _imageFuture = _fetchImage();
  }

  @override
  void didUpdateWidget(covariant SquareImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pinId != widget.pinId) {
      _imageFuture = _fetchImage();
    }
  }

  Future<Uint8List?> _fetchImage() {
    return ref.read(pinImageRepositoryProvider).fetchImage(widget.pinId, false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FutureBuilder<Uint8List?>(
        future: _imageFuture,
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image != null) {
            return GestureDetector(
              onTap: () => widget.onTap(widget.index),
              child: FadeInImage(
                fadeInDuration: const Duration(milliseconds: 100),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: MemoryImage(kTransparentImage),
                image: memoryImageForDisplay(
                  image,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  logicalWidth: constraints.maxWidth,
                  maximumCacheWidth: 720,
                ),
              ),
            );
          }

          return const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.image_not_supported_outlined)),
          );
        },
      ),
    );
  }
}
