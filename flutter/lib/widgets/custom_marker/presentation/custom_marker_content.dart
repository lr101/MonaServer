import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/map_home/presentation/circle_with_indicator.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';

class CustomMarkerContent extends ConsumerStatefulWidget {
  final PinEntity pinDto;
  final bool withAnimation;

  const CustomMarkerContent({
    super.key,
    required this.pinDto,
    required this.withAnimation,
  });

  @override
  _CustomMarkerContentState createState() => _CustomMarkerContentState();
}

class _CustomMarkerContentState extends ConsumerState<CustomMarkerContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isWithinDistance(Position userPosition) {
    return _distance.as(LengthUnit.Meter, LatLng(userPosition.latitude, userPosition.longitude),
        LatLng(widget.pinDto.latitude, widget.pinDto.longitude),) <= 50.0;
  }

  @override
  Widget build(BuildContext context) {
    final isInRange = ref.watch(currentLocationProvider.select((e) => e.whenOrNull(data: (data) => _isWithinDistance(data))));
    final markerImage = Image.memory(ref.watch(groupPinImageByIdProvider(widget.pinDto.groupId)).value ?? ref.read(defaultGroupPinImageProvider));
    if (widget.withAnimation == false || isInRange == null) {
     return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            width: 30,
            child: markerImage,
          ),
          const SizedBox.square(dimension: 30),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isInRange)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = _controller.value;
              return Container(
                width: 50 + scale * 50,
                height: 50 + scale * 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8 - (scale - 0.2)),
                ),
              );
            },
          ),
        SizedBox(
          height: 30,
          width: 30,
          child: markerImage,
        ),
      ],
    );
  }
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
                  child: Text("No Data", style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                            width: 16, height: 16,
                            child: RoundImage(
                              size: 16,
                              imageCallback: ref.watch(groupProfilePictureByIdProvider(group.id)),
                              child: Container(color: Colors.grey[800]),
                            ),
                          ),
                        const SizedBox(width: 6),
                        
                        // Name & Points
                        Expanded(
                          child: Text(
                            group?.name ?? "Unknown",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${item.points ?? 0}",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9),
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
