import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class PinImagePlaceholder extends StatelessWidget {
  const PinImagePlaceholder({super.key, required this.blurhash});

  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final hash = blurhash;
    if (hash == null || hash.length != 16) {
      return const ColoredBox(color: Colors.black12);
    }

    return Image(
      image: _CachedBlurHashImage(hash),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const ColoredBox(color: Colors.black12);
      },
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
    );
  }
}

/// Caches decoded 16x16 blurhash placeholders in Flutter's [ImageCache] so
/// scrolling or switching tabs never re-decodes the same hash or leaks images.
class _CachedBlurHashImage extends ImageProvider<_CachedBlurHashImage> {
  const _CachedBlurHashImage(this.blurHash);

  static const int _decodeDimension = 16;

  final String blurHash;

  @override
  Future<_CachedBlurHashImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedBlurHashImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _CachedBlurHashImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_loadAsync(key));

  Future<ImageInfo> _loadAsync(_CachedBlurHashImage key) async {
    final image = await blurHashDecodeImage(
      blurHash: key.blurHash,
      width: _decodeDimension,
      height: _decodeDimension,
      optimizationMode: BlurHashOptimizationMode.approximation,
    );
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedBlurHashImage && other.blurHash == blurHash;

  @override
  int get hashCode => blurHash.hashCode;

  @override
  String toString() => '_CachedBlurHashImage($blurHash)';
}
