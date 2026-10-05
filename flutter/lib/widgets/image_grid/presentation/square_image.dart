import 'dart:typed_data';

import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class SquareImage extends ConsumerStatefulWidget {
  final String pinId;
  final String groupId;
  final String? photoUrl;
  final String? photoId;
  final int index;
  final Function(int index) onTap;

  const SquareImage({
    super.key,
    required this.pinId,
    required this.index,
    required this.groupId,
    this.photoUrl,
    this.photoId,
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
    if (oldWidget.pinId != widget.pinId ||
        oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.photoId != widget.photoId) {
      _imageFuture = _fetchImage();
    }
  }

  Future<Uint8List?> _fetchImage() {
    final photoUrl = widget.photoUrl;
    final photoId = widget.photoId;
    if (photoUrl != null && photoId != null) {
      return ref
          .read(pinImageRepositoryProvider)
          .fetchImageFromUrl(photoId, photoUrl, false);
    }
    if (photoUrl != null) return Future<Uint8List?>.value();
    return ref.read(pinImageRepositoryProvider).fetchImage(widget.pinId, false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FutureBuilder<Uint8List?>(
        future: _imageFuture,
        builder: (context, snapshot) {
          final image = snapshot.data;
          final showNetworkFallback =
              widget.photoUrl != null &&
              (widget.photoId == null ||
                  snapshot.connectionState == ConnectionState.done);
          if (image != null || showNetworkFallback) {
            return GestureDetector(
              onTap: () => widget.onTap(widget.index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FadeInImage(
                    fadeInDuration: const Duration(milliseconds: 100),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: MemoryImage(kTransparentImage),
                    image: widget.photoUrl == null
                        ? memoryImageForDisplay(
                            image!,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                            logicalWidth: constraints.maxWidth,
                            maximumCacheWidth: 720,
                          )
                        : image == null
                        ? NetworkImage(widget.photoUrl!)
                        : memoryImageForDisplay(
                            image,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                            logicalWidth: constraints.maxWidth,
                            maximumCacheWidth: 720,
                          ),
                  ),
                ],
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
