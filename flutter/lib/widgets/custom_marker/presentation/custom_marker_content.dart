import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/map_home/presentation/circle_with_indicator.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class PinMarkerImage extends StatelessWidget {
  const PinMarkerImage({
    super.key,
    required this.isGone,
    required this.image,
    this.style = 'classic',
  });

  final bool isGone;
  final Widget image;
  final String style;

  @override
  Widget build(BuildContext context) {
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

    final frameColor = _pinStyleColor(style);
    final hasFrame = style != 'classic';
    final framedImage = hasFrame
        ? Container(
            key: ValueKey('pin-style-frame-$style'),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: frameColor, width: 2),
            ),
            child: ClipOval(child: pinImage),
          )
        : pinImage;

    return Semantics(
      label: isGone
          ? 'Pin marked gone${hasFrame ? ' · ${_pinStyleName(style)} frame' : ''}'
          : 'Pin${hasFrame ? ' · ${_pinStyleName(style)} frame' : ''}',
      image: true,
      child: SizedBox.square(
        dimension: 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: framedImage),
            if (isGone)
              const Positioned(
                right: -2,
                top: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(1),
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final markerImage = PinMarkerImage(
      isGone: pinDto.isGone,
      style: group?.pinStyle ?? 'classic',
      image: Image.memory(
        ref.watch(groupPinImageByIdProvider(pinDto.groupId)).value ??
            ref.read(defaultGroupPinImageProvider),
        gaplessPlayback: true,
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 30, width: 30, child: markerImage),
        const SizedBox.square(dimension: 30),
      ],
    );
  }
}

Color _pinStyleColor(String style) => switch (style) {
  'moss' => const Color(0xff668465),
  'sunset' => const Color(0xffd57b50),
  'aurora' => const Color(0xff6d77ba),
  _ => Colors.transparent,
};

String _pinStyleName(String style) => switch (style) {
  'moss' => 'Moss',
  'sunset' => 'Sunset',
  'aurora' => 'Aurora',
  _ => 'Classic',
};

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
