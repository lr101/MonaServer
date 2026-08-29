import 'package:buff_lisa/data/service/geojson_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/map_home/data/marker_window_state.dart';
import 'package:buff_lisa/features/map_home/presentation/circle_with_indicator.dart';
import 'package:buff_lisa/features/map_home/presentation/join_group_hint.dart';
import 'package:buff_lisa/features/map_home/presentation/osm_copyright.dart';
import 'package:buff_lisa/features/map_home/presentation/ranking_panel.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_map_setup/presentation/custom_tile_layer.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/mode_selector.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/top_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class MapHome extends ConsumerStatefulWidget {
  const MapHome({super.key});

  @override
  ConsumerState<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends ConsumerState<MapHome>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final MapController _controller = MapController();
  late final AnimationController _animateController;
  late final MapLocationAnimator _locationAnimator;

  static const double panelHeaderSize = 60;

  @override
  void initState() {
    super.initState();
    _animateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _locationAnimator = MapLocationAnimator(
      controller: _animateController,
      move: _controller.move,
      onComplete: (center, zoom) {
        ref
            .read(districtServiceProvider.notifier)
            .updateLatLong(center.latitude, center.longitude, zoom);
        ref.read(districtServiceProvider.notifier).refetch();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => moveToCurrentPosition(),
    );
  }

  @override
  void dispose() {
    _locationAnimator.dispose();
    _animateController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mapState = ref.watch(mapStatesProvider);
    final mapZoom = ref.watch(mapZoomLevelProvider);
    ref.watch(markerWindowStateProvider);
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              minZoom: 2,
              maxZoom: 18,
              initialZoom: mapZoom,
              keepAlive: true,
              initialCenter: ref.watch(lastKnownLocationProvider),
              onPointerUp: (event, point) {
                ref.read(districtServiceProvider.notifier).refetch();
              },
              onPositionChanged: (position, hasGesture) {
                ref.read(mapZoomLevelProvider.notifier).setZoom(position.zoom);
                ref
                    .read(districtServiceProvider.notifier)
                    .updateLatLong(
                      position.center.latitude,
                      position.center.longitude,
                      position.zoom,
                    );
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              CustomTileLayer(),
              const CurrentLocationLayer(),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  disableClusteringAtZoom: 16,
                  size: const Size(80, 80),
                  markers: mapState.markers,
                  polygonOptions: const PolygonOptions(
                    color: Colors.transparent,
                  ),
                  onMarkerTap: onMarkerTab,
                  builder: (context, markers) => CircleWithIndicator(
                    color: Theme.of(context).highlightColor,
                    number: markers.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: panelHeaderSize + 10,
          right: 4, // ranking panel has 4px box shadow, so position 4px from bottom and right
          child: FloatingActionButton(
            heroTag: "moveToCurrentLocation",
            onPressed: moveToCurrentPosition,
            child: const Icon(Icons.my_location),
          ),
        ),
        const Positioned(
          bottom: panelHeaderSize + 4,
          left: 0, // ranking panel has 4px box shadow, so position 4px left
          child: OsmCopyright(),
        ),
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: TopStatusBar()),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [JoinGroupHintOverlay(), ModeSelector()],
                ),
              ],
            ),
          ),
        ),

        const Positioned.fill(
          child: NotificationListener<DraggableScrollableNotification>(
            child: RankingSlidingPanel(headerPixelHeight: panelHeaderSize),
          ),
        ),
      ],
    );
  }

  Future<void> onMarkerTab(Marker marker) async {
    final m = marker as CustomMarkerWidget;
    context.pushNamed("viewImage", pathParameters: {"id": m.pinDto.pinId});
  }

  Future<void> moveToCurrentPosition() async {
    if (!await hasLocationPermission(GeolocatorLocationPermissionGateway())) {
      CustomErrorSnackBar.message(
        message: 'Some functions do not work without location permission',
        type: CustomErrorSnackBarType.error,
      );
      return;
    }
    try {
      final destLocation = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setLocation(LatLng(destLocation.latitude, destLocation.longitude), 15);
    } catch (_) {
      CustomErrorSnackBar.message(
        message: 'Could not determine your current location',
        type: CustomErrorSnackBarType.error,
      );
    }
  }

  void setLocation(LatLng location, double zoom) {
    _locationAnimator.animate(
      currentCenter: _controller.camera.center,
      currentZoom: _controller.camera.zoom,
      destination: location,
      destinationZoom: zoom,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
