import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image_header.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_switchable_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';

class FeedCardImage extends ConsumerStatefulWidget {
  const FeedCardImage({
    super.key,
    required this.item,
    required this.maxHeight,
    required this.maxWidth,
    this.distance,
    this.rotateHeader = false,
    this.onTab,
  });

  final PinEntity item;
  final double maxWidth;
  final double maxHeight;
  final double? distance;
  final bool rotateHeader;
  final dynamic Function(LatLng location, double zoom)? onTab;

  @override
  ConsumerState<FeedCardImage> createState() => _FeedCardImageState();
}

class _FeedCardImageState extends ConsumerState<FeedCardImage> {
  late final Widget feedMap;

  @override
  void initState() {
    super.initState();
    feedMap = FeedMap(item: widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(pinImageBytesProvider(widget.item.pinId));
    // Determine which view is currently active in the main area
    final isMainViewShowingImage = ref.watch(
      feedMapStateProvider(widget.item.pinId),
    );

    final feedImage = FeedSwitchableImage(
      item: widget.item,
      image: data.value,
      likeImage: likeImage,
      onTab: widget.onTab,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: widget.maxHeight,
                  width: widget.maxWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isMainViewShowingImage ? feedImage : feedMap,
                      ),
                      // 2. The Mini View in the bottom right corner
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: SizedBox.square(
                            dimension: 100,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              // Show the opposite of the main view
                              child: isMainViewShowingImage
                                  ? feedMap
                                  : feedImage,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              width: widget.maxWidth,
              height: 65,
              child: FeedCardImageHeader(
                pin: widget.item,
                distance: widget.distance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FeedCardSubtitle(pin: widget.item),
      ],
    );
  }

  void likeImage() {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    ref
        .read(likeServiceProvider(widget.item.pinId).notifier)
        .addLike(
          widget.item.creator,
          CreateLikeDto(userId: userId, like: true),
        );
  }
}
