import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_map_setup/presentation/custom_tile_layer.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';

class FeedMap extends ConsumerStatefulWidget {

  const FeedMap({super.key, required this.item});
  final PinEntity item;

  @override
  ConsumerState<FeedMap> createState() => FeedMapState();
}

class FeedMapState extends ConsumerState<FeedMap> {

  late MapController _mapController;
  late LatLng center;
  late double _zoom;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    center = LatLng(widget.item.latitude, widget.item.longitude);
    _zoom = 5;
  }


  @override
  Widget build(BuildContext context) {
    final isExpanded = !ref.watch(feedMapStateProvider(widget.item.pinId));
    final switchFun = ref.read(feedMapStateProvider(widget.item.pinId).notifier).update;
    return Stack(
      children: [
        GestureDetector(
            onTap: isExpanded ? null : switchFun,
            onDoubleTap: isExpanded ? like : null,
            child: AbsorbPointer(child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            minZoom: 2,
            maxZoom: 18,
            initialZoom: _zoom,
            initialCenter: center,
            keepAlive: true,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom,),
          ),
          children: [
            CustomTileLayer(),
            MarkerLayer(markers: [CustomMarkerWidget(pinDto: widget.item),]),
          ],
        ),),),
        if(isExpanded) Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _MapControlButton(
                      onTap: () => zoomIn(center),
                      theme: Theme.of(context),
                      icon: Icons.zoom_in,),
                  const SizedBox(height: 5,),
                   _MapControlButton(
                      onTap: () => zoomOut(center),
                      theme: Theme.of(context),
                      icon: Icons.zoom_out_rounded,),
                ],
              ),
            ),),
      ],);
  }

  void zoomIn(LatLng center) {
    _mapController.move(center, _mapController.camera.zoom + 1);
  }

  void zoomOut(LatLng center) {
    _mapController.move(center, _mapController.camera.zoom - 1);
  }

  void like() {
    final userId = ref.watch(globalDataServiceProvider).userId!;
    ref.read(likeServiceProvider(widget.item.pinId).notifier)
        .addLike(widget.item.creator, CreateLikeDto(userId: userId, likeLocation: true));
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 45, // Smaller than FAB (56)
          height: 45,
          decoration: BoxDecoration(
            // Semi-transparent surface color (frosted glass effect)
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
        ),
      ),
    );
  }
}
