import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/widgets/pin_image/presentation/pin_image_placeholder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uses the package's browser loader on web and file cache on native platforms.
/// Flutter's image cache owns decoded frames on both platforms.
class RemotePinImage extends ConsumerStatefulWidget {
  const RemotePinImage({
    super.key,
    required this.pinId,
    this.photoId,
    this.thumbnailUrl,
    this.imageUrl,
    this.blurhash,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });
  final String pinId;
  final String? photoId;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? blurhash;
  final BoxFit fit;
  final Alignment alignment;

  @override
  ConsumerState<RemotePinImage> createState() => _RemotePinImageState();
}

class _RemotePinImageState extends ConsumerState<RemotePinImage> {
  int _attempt = 0;
  bool _advanceScheduled = false;

  @override
  void didUpdateWidget(covariant RemotePinImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pinId != widget.pinId ||
        oldWidget.photoId != widget.photoId ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl ||
        oldWidget.imageUrl != widget.imageUrl) {
      _attempt = 0;
      _advanceScheduled = false;
    }
  }

  PinImageRequest get _request => (
    pinId: widget.pinId,
    photoId: widget.photoId,
    thumbnailUrl: widget.thumbnailUrl,
    imageUrl: widget.imageUrl,
    attempt: _attempt,
  );

  void _advance() {
    if (_advanceScheduled || _attempt >= 3) return;
    _advanceScheduled = true;
    final attempt = _attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _attempt++;
        _advanceScheduled = false;
      });
    });
  }

  Widget _placeholder() => PinImagePlaceholder(blurhash: widget.blurhash);

  Widget _failed() {
    if (_attempt < 3) {
      _advance();
      return _placeholder();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _placeholder(),
        const Center(child: Icon(Icons.image_not_supported_outlined)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(pinImageSourceProvider(_request));
    return source.when(
      loading: _placeholder,
      error: (_, _) => _failed(),
      data: (source) {
        if (source == null) return _failed();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cacheWidth = width.isFinite
                ? (width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
                    1,
                    720,
                  )
                : 720;
            return CachedNetworkImage(
              imageUrl: source.url,
              cacheKey: source.cacheKey,
              // A new session must also replace OctoImage's retained old frame.
              key: ValueKey(source.cacheKey),
              fit: widget.fit,
              alignment: widget.alignment,
              memCacheWidth: cacheWidth,
              fadeInDuration: const Duration(milliseconds: 150),
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => _placeholder(),
              errorWidget: (_, _, _) => _failed(),
            );
          },
        );
      },
    );
  }
}
