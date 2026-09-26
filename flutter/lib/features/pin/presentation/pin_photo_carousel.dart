import 'dart:math' as math;
import 'dart:typed_data';

import 'package:buff_lisa/util/image/memory_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

/// The original pin picture followed by its later photo updates.
class PinPhotoCarousel extends StatefulWidget {
  const PinPhotoCarousel({super.key, this.originalImage, required this.photos});

  final Uint8List? originalImage;
  final List<PinPhotoDto> photos;

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
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
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
    final current = _index == 0 ? null : updates[_index - 1];
    final original = widget.photos
        .where((photo) => photo.isOriginal)
        .firstOrNull;
    final title = current == null
        ? 'Original pin photo'
        : 'Update by ${current.contributorUsername}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          // A landscape frame leaves room for the pin details and actions on
          // a regular phone screen while keeping the swipe interaction clear.
          aspectRatio: 6 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (index) => setState(() => _index = index),
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
                child: index == 0
                    ? _originalPhoto(context)
                    : _networkPhoto(context, updates[index - 1].image),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (count > 1) Text('${_index + 1} / $count'),
          ],
        ),
        if (current ?? original case final photo?)
          Text(
            '${MaterialLocalizations.of(context).formatMediumDate(photo.observedAt.toLocal())} · '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(photo.observedAt.toLocal()))}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (current?.caption case final caption? when caption.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }

  Widget _originalPhoto(BuildContext context) {
    if (widget.originalImage case final bytes? when bytes.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => Image(
          image: memoryImageForDisplay(
            bytes,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            logicalWidth: math.min(constraints.maxWidth, 720),
            maximumCacheWidth: 720,
          ),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _unavailablePhoto(context),
        ),
      );
    }
    final original = widget.photos
        .where((photo) => photo.isOriginal)
        .firstOrNull;
    return _networkPhoto(context, original?.image);
  }

  Widget _networkPhoto(BuildContext context, String? url) =>
      url == null || url.isEmpty
      ? _unavailablePhoto(context)
      : Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _unavailablePhoto(context),
        );

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
