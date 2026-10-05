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
    this.initialPhotoId,
    this.onPageChanged,
    this.onDoubleTap,
    this.onTap,
    this.overlayBuilder,
  });

  final Uint8List? originalImage;
  final bool isOriginalLoading;
  final List<PinPhotoDto> photos;
  final String? initialPhotoId;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;
  final Widget Function(BuildContext, int, int, VoidCallback?, VoidCallback?)?
  overlayBuilder;

  @override
  State<PinPhotoCarousel> createState() => _PinPhotoCarouselState();
}

class _PinPhotoCarouselState extends State<PinPhotoCarousel> {
  late final PageController _controller;
  int _index = 0;
  bool _initialPhotoResolved = false;

  int _targetIndex() {
    if (widget.initialPhotoId == null) return 0;
    final index = _updates.indexWhere(
      (photo) => photo.id == widget.initialPhotoId,
    );
    return index < 0 ? 0 : index + 1;
  }

  @override
  void initState() {
    super.initState();
    _index = _targetIndex();
    _initialPhotoResolved = widget.initialPhotoId == null || _index > 0;
    _controller = PageController(initialPage: _index);
  }

  List<PinPhotoDto> get _updates =>
      widget.photos.where((photo) => !photo.isOriginal).toList();

  @override
  void didUpdateWidget(covariant PinPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhotoId != widget.initialPhotoId) {
      _initialPhotoResolved = false;
    }
    if (!_initialPhotoResolved) {
      final target = _targetIndex();
      if (widget.initialPhotoId == null || target > 0) {
        _initialPhotoResolved = true;
        _index = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          _controller.jumpToPage(target);
          widget.onPageChanged?.call(target);
        });
      }
    }
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

    if (widget.overlayBuilder != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (index) {
                setState(() {
                  _index = index;
                  _initialPhotoResolved = true;
                });
                widget.onPageChanged?.call(index);
              },
              itemBuilder: (context, index) => index == 0
                  ? _originalPhoto(context)
                  : _networkPhoto(context, updates[index - 1].image),
            ),
          ),
          widget.overlayBuilder!(
            context,
            _index,
            count,
            _index > 0 ? () => _select(_index - 1) : null,
            _index < count - 1 ? () => _select(_index + 1) : null,
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Photos & updates',
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Previous photo',
              onPressed: _index > 0 ? () => _select(_index - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Semantics(
              label: 'Photo ${_index + 1} of $count',
              child: Text(
                '${_index + 1}/$count',
                style: theme.textTheme.labelLarge,
              ),
            ),
            IconButton(
              tooltip: 'Next photo',
              onPressed: _index < count - 1 ? () => _select(_index + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GestureDetector(
              onDoubleTap: widget.onDoubleTap,
              child: PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (index) {
                  setState(() {
                    _index = index;
                    _initialPhotoResolved = true;
                  });
                  widget.onPageChanged?.call(index);
                },
                itemBuilder: (context, index) => index == 0
                    ? _originalPhoto(context)
                    : _networkPhoto(context, updates[index - 1].image),
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76 + MediaQuery.textScalerOf(context).scale(16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = index == 0 ? 'Original' : 'Update $index';
                return Semantics(
                  selected: index == _index,
                  button: true,
                  label: 'Show $label',
                  child: Tooltip(
                    message: 'Show $label',
                    child: InkWell(
                      onTap: () => _select(index),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Container(
                              height: 68,
                              width: 76,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  width: index == _index ? 2 : 1,
                                  color: index == _index
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ExcludeSemantics(
                                  child: index == 0
                                      ? _originalPhoto(context)
                                      : _networkPhoto(
                                          context,
                                          updates[index - 1].image,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              maxLines: 1,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: index == _index
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _select(int index) {
    _initialPhotoResolved = true;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
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
        fit: BoxFit.contain,
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
