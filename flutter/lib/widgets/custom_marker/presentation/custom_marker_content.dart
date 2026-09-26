import 'dart:math' as math;

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/map_home/presentation/circle_with_indicator.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class PinMarkerImage extends StatelessWidget {
  const PinMarkerImage({
    super.key,
    required this.isGone,
    required this.image,
    this.style = 'classic',
    this.design,
  });

  final bool isGone;
  final Widget image;
  final String style;
  final MapPinDesign? design;

  @override
  Widget build(BuildContext context) {
    final resolvedDesign = design ?? MapPinDesign.forStyle(style);
    final hasFrame = resolvedDesign.style != 'classic';
    final pinImage = isGone
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: image,
          )
        : image;
    return Semantics(
      label: isGone
          ? 'Pin marked gone${hasFrame ? ' · ${resolvedDesign.name} frame' : ''}'
          : 'Pin${hasFrame ? ' · ${resolvedDesign.name} frame' : ''}',
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 48.0;
          final availableHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : 56.0;
          final scale = math
              .min(availableWidth / 48, availableHeight / 56)
              .clamp(.55, 1.0);
          final width = 48 * scale;
          final height = 56 * scale;
          final outline = resolvedDesign.outlineWidth;
          final headDiameter = math.min(
            width * (resolvedDesign.shape == 'circle' ? .9 : .88),
            height * (resolvedDesign.shape == 'circle' ? .82 : .72),
          );
          final frameDiameter = math.max(
            8.0,
            headDiameter - 2 * (resolvedDesign.imageInset + outline) * scale,
          );
          final imageDiameter = math.max(4 * scale, frameDiameter - 4 * scale);
          final frameLeft = (width - frameDiameter) / 2;
          final headCenterY = switch (resolvedDesign.shape) {
            'circle' => height - headDiameter / 2 - scale,
            'shield' => height * .36,
            _ => height * .34,
          };
          final frameTop = headCenterY - frameDiameter / 2;
          final badgeIcon = _badgeIcon(resolvedDesign.badge);

          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _MapPinPainter(resolvedDesign)),
                ),
                Positioned(
                  left: frameLeft,
                  top: frameTop,
                  width: frameDiameter,
                  height: frameDiameter,
                  child: Container(
                    key: ValueKey('pin-style-frame-${resolvedDesign.style}'),
                    padding: EdgeInsets.all(2 * scale),
                    decoration: BoxDecoration(
                      color: resolvedDesign.imageBorderColor,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: SizedBox.square(
                        dimension: imageDiameter,
                        child: Transform.scale(
                          scale: resolvedDesign.imageZoom,
                          child: pinImage,
                        ),
                      ),
                    ),
                  ),
                ),
                if (badgeIcon != null)
                  Positioned(
                    left: width - 17 * scale,
                    top: headCenterY - 5.5 * scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: resolvedDesign.bodyColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: resolvedDesign.outlineColor),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(scale),
                        child: Icon(
                          badgeIcon,
                          size: 9 * scale,
                          color:
                              resolvedDesign.outlineColor.computeLuminance() >
                                  .5
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (isGone)
                  Positioned(
                    left: frameLeft + frameDiameter - 10 * scale,
                    top: frameTop + frameDiameter - 10 * scale,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(scale),
                        child: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white,
                          size: 11 * scale,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CustomMarkerContent extends ConsumerWidget {
  final PinEntity pinDto;

  const CustomMarkerContent({super.key, required this.pinDto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupMetadataProvider(pinDto.groupId)).value;
    final catalog = ref
        .watch(groupPinDesignCatalogProvider(pinDto.groupId))
        .value;
    final style = group?.pinStyle ?? 'classic';
    final design = MapPinDesign.forCatalog(catalog, style);
    final markerImage = PinMarkerImage(
      isGone: pinDto.isGone,
      style: style,
      design: design,
      image: Image.memory(
        ref.watch(groupPinImageByIdProvider(pinDto.groupId)).value ??
            ref.read(defaultGroupPinImageProvider),
        fit: BoxFit.cover,
        alignment: Alignment(design.imageAlignmentX, design.imageAlignmentY),
        gaplessPlayback: true,
      ),
    );

    return SizedBox(width: 48, height: 56, child: markerImage);
  }
}

IconData? _badgeIcon(String badge) => switch (badge) {
  'star' => Icons.star,
  'leaf' => Icons.eco,
  'sun' => Icons.wb_sunny,
  'spark' => Icons.auto_awesome,
  _ => null,
};

class _MapPinPainter extends CustomPainter {
  const _MapPinPainter(this.design);

  final MapPinDesign design;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    final strokeWidth = design.outlineWidth * scale;
    final pathSize = Size(size.width - strokeWidth, size.height - strokeWidth);
    canvas.save();
    canvas.translate(strokeWidth / 2, strokeWidth / 2);
    final path = _mapPinPath(pathSize, design.shape);
    if (design.shadow) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: .3),
        3 * scale,
        true,
      );
    }
    canvas.drawPath(path, Paint()..color = design.bodyColor);
    if (design.outlineWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = design.outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPinPainter oldDelegate) =>
      oldDelegate.design != design;
}

Path _mapPinPath(Size size, String shape) {
  final width = size.width;
  final height = size.height;
  final center = width / 2;
  if (shape == 'shield') {
    return Path()
      ..moveTo(width * .17, height * .07)
      ..quadraticBezierTo(width * .08, height * .07, width * .08, height * .16)
      ..lineTo(width * .08, height * .38)
      ..quadraticBezierTo(width * .08, height * .55, center, height)
      ..quadraticBezierTo(width * .92, height * .55, width * .92, height * .38)
      ..lineTo(width * .92, height * .16)
      ..quadraticBezierTo(width * .92, height * .07, width * .83, height * .07)
      ..close();
  }

  if (shape == 'circle') {
    final radius = math.min(width * .46, height * .42);
    final centerY = height - radius;
    return Path()..addOval(
      Rect.fromCircle(center: Offset(center, centerY), radius: radius),
    );
  }

  return Path()
    ..moveTo(center, height)
    ..cubicTo(
      center - width * .1,
      height * .72,
      width * .04,
      height * .54,
      width * .04,
      height * .34,
    )
    ..cubicTo(
      width * .04,
      height * .15,
      width * .24,
      height * .05,
      center,
      height * .05,
    )
    ..cubicTo(
      width * .76,
      height * .05,
      width * .96,
      height * .15,
      width * .96,
      height * .34,
    )
    ..cubicTo(
      width * .96,
      height * .54,
      center + width * .1,
      height * .72,
      center,
      height,
    )
    ..close();
}

class RankedClusterMarker extends ConsumerWidget {
  final List<GroupRankingDtoInner> ranking;
  final int totalMarkers;
  final String regionName;

  const RankedClusterMarker({
    super.key,
    required this.ranking,
    required this.totalMarkers,
    required this.regionName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top3 = ranking.take(3).toList();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // --- 1. THE CARD CONTENT ---
        Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Region Name Header
              Text(
                regionName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 8, color: Colors.grey, thickness: 0.5),

              // Ranking List
              if (top3.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text(
                    "No Data",
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                )
              else
                ...top3.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final group = item.groupInfoDto;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        // Rank #
                        Text(
                          "${index + 1}.",
                          style: TextStyle(
                            color: index == 0 ? Colors.amber : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Group Image
                        if (group != null)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: SmallProfilePicture.group(
                              groupId: group.id,
                              radius: 8,
                              child: Container(color: Colors.grey[800]),
                            ),
                          ),
                        const SizedBox(width: 6),

                        // Name & Points
                        Expanded(
                          child: Text(
                            group?.name ?? "Unknown",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${item.points ?? 0}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),

        // --- 2. THE TOTAL COUNT BADGE ---
        Positioned(
          top: -8,
          right: -8,
          child: CircleWithIndicator(
            color: Colors.orange,
            number: totalMarkers,
          ),
        ),
      ],
    );
  }
}
