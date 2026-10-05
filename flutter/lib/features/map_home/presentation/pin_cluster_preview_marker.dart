import 'dart:math' as math;

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinClusterPreviewMarker extends ConsumerStatefulWidget {
  const PinClusterPreviewMarker({
    super.key,
    required this.pins,
    required this.isOpen,
    required this.onPinSelected,
    required this.onClosed,
  });

  static const double _previewDiameter = 24;
  static const double _ringRadius = 40;
  static const double _ringSpacing = _previewDiameter + 8;
  static const double _clusterPadding = 4;
  static const int _maxPreviewsPerRing = 10;

  static Size sizeForCount(int count) {
    if (count <= 0) return const Size(80, 80);
    final ringCount = (count / _maxPreviewsPerRing).ceil();
    final outerRadius = _ringRadius + (ringCount - 1) * _ringSpacing;
    final diameter = (outerRadius + _previewDiameter / 2 + _clusterPadding) * 2;
    return Size.square(diameter);
  }

  final List<PinEntity> pins;
  final bool isOpen;
  final ValueChanged<String> onPinSelected;
  final VoidCallback onClosed;

  @override
  ConsumerState<PinClusterPreviewMarker> createState() =>
      _PinClusterPreviewMarkerState();
}

class _PinClusterPreviewMarkerState
    extends ConsumerState<PinClusterPreviewMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _showPreviews = false;

  @override
  void initState() {
    super.initState();
    _showPreviews = widget.isOpen;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addStatusListener(_handleAnimationStatus);
    _scale = Tween<double>(
      begin: 0.72,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.isOpen) _controller.forward();
  }

  @override
  void didUpdateWidget(PinClusterPreviewMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen) {
      _showPreviews = true;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed ||
        widget.isOpen ||
        !_showPreviews) {
      return;
    }

    setState(() => _showPreviews = false);
    widget.onClosed();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rings = _showPreviews
        ? _splitIntoRings(widget.pins)
        : const <List<PinEntity>>[];
    final size = PinClusterPreviewMarker.sizeForCount(widget.pins.length);
    final ringRadii = _ringRadiiFor(rings.length);
    final center = Offset(size.width / 2, size.height / 2);
    final children = <Widget>[];

    for (var ringIndex = 0; ringIndex < rings.length; ringIndex++) {
      final ring = rings[ringIndex];
      final radius = ringRadii[ringIndex];
      for (var pinIndex = 0; pinIndex < ring.length; pinIndex++) {
        final pin = ring[pinIndex];
        final angle = -math.pi / 2 + (2 * math.pi * pinIndex / ring.length);
        final position = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        children.add(
          Positioned(
            left: position.dx - PinClusterPreviewMarker._previewDiameter / 2,
            top: position.dy - PinClusterPreviewMarker._previewDiameter / 2,
            width: PinClusterPreviewMarker._previewDiameter,
            height: PinClusterPreviewMarker._previewDiameter,
            child: _PinImagePreview(
              pin: pin,
              onTap: () => widget.onPinSelected(pin.pinId),
            ),
          ),
        );
      }
    }

    return SizedBox.fromSize(
      size: size,
      child: IgnorePointer(
        ignoring: !widget.isOpen,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        ),
      ),
    );
  }

  static List<List<PinEntity>> _splitIntoRings(List<PinEntity> pins) {
    final rings = <List<PinEntity>>[];
    for (
      var start = 0;
      start < pins.length;
      start += PinClusterPreviewMarker._maxPreviewsPerRing
    ) {
      final end = math.min(
        start + PinClusterPreviewMarker._maxPreviewsPerRing,
        pins.length,
      );
      rings.add(pins.sublist(start, end));
    }
    return rings;
  }

  static List<double> _ringRadiiFor(int count) => List<double>.generate(
    count,
    (index) =>
        PinClusterPreviewMarker._ringRadius +
        index * PinClusterPreviewMarker._ringSpacing,
  );
}

class _PinImagePreview extends ConsumerWidget {
  const _PinImagePreview({required this.pin, required this.onTap});

  final PinEntity pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pinThumbnailBytesProvider(pin.pinId)).value;
    final title = pin.title?.trim();
    final label = title == null || title.isEmpty ? 'Open pin' : 'Open $title';
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      image: true,
      label: label,
      child: Tooltip(
        message: title?.isNotEmpty == true ? title! : 'Open pin',
        child: Material(
          color: colorScheme.surface,
          shape: CircleBorder(
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: image == null || image.isEmpty
                ? _previewPlaceholder(context)
                : Image.memory(
                    image,
                    fit: BoxFit.cover,
                    cacheWidth:
                        (PinClusterPreviewMarker._previewDiameter *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        _previewPlaceholder(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _previewPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: PinClusterPreviewMarker._previewDiameter,
      child: ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.photo_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
