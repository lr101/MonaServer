import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/geojson_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/map_home/data/marker_window_state.dart';
import 'package:buff_lisa/features/map_home/presentation/circle_with_indicator.dart';
import 'package:buff_lisa/features/map_home/presentation/join_group_hint.dart';
import 'package:buff_lisa/features/map_home/presentation/osm_copyright.dart';
import 'package:buff_lisa/features/map_home/presentation/pin_cluster_preview_marker.dart';
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

class _ClusterPreviewSelection {
  const _ClusterPreviewSelection({
    required this.clusterKey,
    required this.center,
    required this.pins,
    required this.markerSignature,
  });

  final String clusterKey;
  final LatLng center;
  final List<PinEntity> pins;
  final int markerSignature;
}

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
  String? _openClusterKey;
  String? _previewClusterKey;
  List<PinEntity> _previewPins = const [];
  LatLng? _previewCenter;
  int? _previewMarkerSignature;
  _ClusterPreviewSelection? _pendingClusterPreview;
  bool _previewInvalidationScheduled = false;

  static const double panelHeaderSize = 60;
  static const double maxMapZoom = 18;

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
      (_) => moveToCurrentPosition(showPermissionError: false),
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
    final markerSignature = _markerSignature(mapState.markers);
    _closePreviewWhenMarkerDataChanges(markerSignature);
    final previewIsOpen =
        _openClusterKey != null &&
        _openClusterKey == _previewClusterKey &&
        _previewMarkerSignature == markerSignature;
    final previewSize = PinClusterPreviewMarker.sizeForCount(
      _previewPins.length,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              minZoom: 2,
              maxZoom: maxMapZoom,
              initialZoom: mapZoom,
              keepAlive: true,
              initialCenter: ref.watch(lastKnownLocationProvider),
              onPointerUp: (event, point) {
                ref.read(districtServiceProvider.notifier).refetch();
              },
              onMapEvent: (event) {
                if (event is MapEventDoubleTapZoomEnd) {
                  ref.read(districtServiceProvider.notifier).refetch();
                }
              },
              onPositionChanged: (position, hasGesture) {
                if (position.zoom < maxMapZoom &&
                    (_openClusterKey != null ||
                        _pendingClusterPreview != null)) {
                  setState(() {
                    _openClusterKey = null;
                    _pendingClusterPreview = null;
                  });
                }
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
                flags:
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag,
              ),
            ),
            children: [
              CustomTileLayer(),
              const CurrentLocationLayer(),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  disableClusteringAtZoom: maxMapZoom.toInt(),
                  size: const Size(80, 80),
                  maxClusterRadius: 120,
                  zoomToBoundsOnClick: false,
                  spiderfyCluster: false,
                  markers: mapState.markers,
                  polygonOptions: const PolygonOptions(
                    color: Colors.transparent,
                  ),
                  onMarkerTap: onMarkerTab,
                  builder: (context, markers) {
                    final pins = markers
                        .whereType<CustomMarkerWidget>()
                        .map((marker) => marker.pinDto)
                        .toList();
                    final clusterKey = _clusterKey(markers);
                    final clusterCenter = _clusterCenter(markers);
                    void onCountTap() => _onClusterNumberPressed(
                      clusterKey,
                      clusterCenter,
                      pins,
                      markerSignature,
                    );
                    return CircleWithIndicator(
                      color: Theme.of(context).highlightColor,
                      number: markers.length,
                      onTap: onCountTap,
                    );
                  },
                ),
              ),
              if (_previewPins.isNotEmpty && _previewCenter != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      key: const ValueKey('pin-cluster-preview'),
                      point: _previewCenter!,
                      width: previewSize.width,
                      height: previewSize.height,
                      child: PinClusterPreviewMarker(
                        pins: _previewPins,
                        isOpen: previewIsOpen,
                        onPinSelected: (pinId) => context.pushNamed(
                          'viewImage',
                          pathParameters: {'id': pinId},
                        ),
                        onClosed: _onClusterPreviewClosed,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          bottom: panelHeaderSize + 10,
          right: 4, // ranking panel has 4px box shadow, so position 4px from bottom and right
          child: FloatingActionButton(
            heroTag: "moveToCurrentLocation",
            onPressed: () => moveToCurrentPosition(showPermissionError: true),
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

  void onMarkerTab(Marker marker) {
    final tappedMarker = marker as CustomMarkerWidget;
    context.pushNamed(
      'viewImage',
      pathParameters: {'id': tappedMarker.pinDto.pinId},
    );
  }

  String _clusterKey(List<Marker> markers) {
    final pinIds =
        markers
            .whereType<CustomMarkerWidget>()
            .map((marker) => marker.pinDto.pinId)
            .toList()
          ..sort();
    return pinIds.join('|');
  }

  LatLng _clusterCenter(List<Marker> markers) =>
      LatLngBounds.fromPoints(markers.map((marker) => marker.point).toList())
          .center;

  void _onClusterNumberPressed(
    String clusterKey,
    LatLng clusterCenter,
    List<PinEntity> pins,
    int markerSignature,
  ) {
    final currentZoom = ref.read(mapZoomLevelProvider);
    if (currentZoom >= maxMapZoom) {
      if (pins.isEmpty) return;
      final selection = _ClusterPreviewSelection(
        clusterKey: clusterKey,
        center: clusterCenter,
        pins: pins,
        markerSignature: markerSignature,
      );
      final isCurrentPreviewOpen =
          _openClusterKey == clusterKey &&
          _previewClusterKey == clusterKey &&
          _previewMarkerSignature == markerSignature;
      if (isCurrentPreviewOpen) {
        setState(() {
          _openClusterKey = null;
          _pendingClusterPreview = null;
        });
      } else if (_previewPins.isNotEmpty) {
        setState(() {
          _openClusterKey = null;
          _pendingClusterPreview = selection;
        });
      } else {
        setState(() => _applyClusterPreview(selection));
      }
      return;
    }

    final nextZoom = (currentZoom.ceil() + 1)
        .clamp(2, maxMapZoom.toInt())
        .toDouble();
    if (nextZoom <= currentZoom) return;

    _locationAnimator.animate(
      currentCenter: _controller.camera.center,
      currentZoom: _controller.camera.zoom,
      destination: clusterCenter,
      destinationZoom: nextZoom,
    );
  }

  void _onClusterPreviewClosed() {
    if (!mounted || _previewPins.isEmpty) return;
    final pendingPreview = _pendingClusterPreview;
    final currentMarkerSignature = _markerSignature(
      ref.read(mapStatesProvider).markers,
    );
    if (pendingPreview != null &&
        pendingPreview.markerSignature == currentMarkerSignature) {
      setState(() => _applyClusterPreview(pendingPreview));
      return;
    }

    final currentPreviewIsOpen =
        _openClusterKey != null &&
        _openClusterKey == _previewClusterKey &&
        _previewMarkerSignature == currentMarkerSignature;
    if (currentPreviewIsOpen) return;

    setState(() {
      _openClusterKey = null;
      _previewClusterKey = null;
      _previewPins = const [];
      _previewCenter = null;
      _previewMarkerSignature = null;
      _pendingClusterPreview = null;
      _previewInvalidationScheduled = false;
    });
  }

  void _applyClusterPreview(_ClusterPreviewSelection selection) {
    _openClusterKey = selection.clusterKey;
    _previewClusterKey = selection.clusterKey;
    _previewPins = List.unmodifiable(selection.pins);
    _previewCenter = selection.center;
    _previewMarkerSignature = selection.markerSignature;
    _pendingClusterPreview = null;
  }

  void _closePreviewWhenMarkerDataChanges(int markerSignature) {
    if (_previewPins.isEmpty || _previewInvalidationScheduled) return;
    final expectedSignature =
        _pendingClusterPreview?.markerSignature ?? _previewMarkerSignature;
    if (expectedSignature == markerSignature) return;

    _previewInvalidationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestMarkerSignature = _markerSignature(
        ref.read(mapStatesProvider).markers,
      );
      final latestExpectedSignature =
          _pendingClusterPreview?.markerSignature ?? _previewMarkerSignature;
      if (latestExpectedSignature != latestMarkerSignature) {
        setState(() {
          _openClusterKey = null;
          _pendingClusterPreview = null;
        });
      }
      _previewInvalidationScheduled = false;
    });
  }

  int _markerSignature(List<Marker> markers) => Object.hashAllUnordered(
    markers.whereType<CustomMarkerWidget>().map(
      (marker) => Object.hash(
        marker.pinDto.pinId,
        marker.point.latitude,
        marker.point.longitude,
      ),
    ),
  );

  Future<void> moveToCurrentPosition({
    required bool showPermissionError,
  }) async {
    if (!await hasLocationPermission(GeolocatorLocationPermissionGateway())) {
      if (showPermissionError) {
        CustomErrorSnackBar.message(
          message: 'Some functions do not work without location permission',
          type: CustomErrorSnackBarType.error,
        );
      }
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
