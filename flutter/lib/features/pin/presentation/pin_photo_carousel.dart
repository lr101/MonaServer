import 'dart:math' as math;
import 'dart:typed_data';

import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

/// The original pin picture followed by its later photo updates.
class PinPhotoCarousel extends StatefulWidget {
  const PinPhotoCarousel({
    super.key,
    this.originalImage,
    this.isOriginalLoading = false,
    required this.photos,
    this.onPageChanged,
  });

  final Uint8List? originalImage;
  final bool isOriginalLoading;
  final List<PinPhotoDto> photos;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PinPhotoCarousel> createState() => _PinPhotoCarouselState();
}

class _PinPhotoCarouselState extends State<PinPhotoCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  List<PinPhotoDto> get _updates =>
      widget.photos.where((photo) => !photo.isOriginal).toList();

  @override
  void didUpdateWidget(covariant PinPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= _updates.length + 1) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.hasClients) _controller.jumpToPage(0);
        widget.onPageChanged?.call(0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updates = _updates;
    final count = updates.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label: 'Photo ${_index + 1} of $count',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_index + 1}/$count',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (index) {
                setState(() => _index = index);
                widget.onPageChanged?.call(index);
              },
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final page =
                      _controller.hasClients &&
                          _controller.position.haveDimensions
                      ? _controller.page ?? _index.toDouble()
                      : _index.toDouble();
                  final tilt = ((index - page) * 0.035).clamp(-0.035, 0.035);
                  return Transform.rotate(angle: tilt, child: child);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (index == 0)
                      _originalPhoto(context)
                    else
                      _networkPhoto(context, updates[index - 1].image),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: index == 0
                          ? const _OriginalBadge()
                          : const _UpdateBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _originalPhoto(BuildContext context) {
    final original = widget.photos
        .where((photo) => photo.isOriginal)
        .firstOrNull;
    final url = original?.image;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bytes = widget.originalImage;
        final ImageProvider<Object>? imageProvider;
        if (bytes != null && bytes.isNotEmpty) {
          imageProvider = memoryImageForDisplay(
            bytes,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            logicalWidth: math.min(constraints.maxWidth, 720),
            maximumCacheWidth: 720,
          );
        } else if (url != null && url.isNotEmpty) {
          imageProvider = NetworkImage(url);
        } else {
          imageProvider = null;
        }

        if (imageProvider == null) {
          return widget.isOriginalLoading
              ? _loadingPhoto(context)
              : _unavailablePhoto(context);
        }

        return _photoImage(
          context,
          imageProvider,
          showUnavailableOnError: !widget.isOriginalLoading,
        );
      },
    );
  }

  Widget _networkPhoto(BuildContext context, String? url) =>
      url == null || url.isEmpty
      ? _unavailablePhoto(context)
      : _photoImage(context, NetworkImage(url), showUnavailableOnError: true);

  Widget _photoImage(
    BuildContext context,
    ImageProvider<Object> imageProvider, {
    required bool showUnavailableOnError,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
      Image(
        image: imageProvider,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: wasSynchronouslyLoaded || frame != null ? 1 : 0,
              child: child,
            ),
        errorBuilder: (_, _, _) => showUnavailableOnError
            ? _unavailablePhoto(context)
            : _loadingPhoto(context),
      ),
    ],
  );

  Widget _loadingPhoto(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);

  Widget _unavailablePhoto(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _OriginalBadge extends StatelessWidget {
  const _OriginalBadge();

  @override
  Widget build(BuildContext context) =>
      const _PhotoBadge(label: 'ORIGINAL', icon: Icons.star_rounded);
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) =>
      const _PhotoBadge(label: 'UPDATE', icon: Icons.update_rounded);
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}
