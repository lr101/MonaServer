import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/map_home/presentation/osm_copyright.dart';
import 'package:buff_lisa/widgets/buttons/presentation/custom_submit_button.dart';
import 'package:buff_lisa/widgets/custom_map_setup/presentation/custom_tile_layer.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class SelectLocation extends ConsumerStatefulWidget {
  const SelectLocation({super.key, this.center, required this.image});

  final LatLng? center;
  final Uint8List image;

  @override
  ConsumerState<SelectLocation> createState() => _SelectLocationState();
}

class _SelectLocationState extends ConsumerState<SelectLocation> {
  final _mapController = MapController();
  final _zoom = 10.0;

  @override
  Widget build(BuildContext context) {
    LatLng centerPosition = const LatLng(49.01105, 8.25190);
    if (widget.center == null) {
      final pos = ref.read(currentLocationProvider).value;
      if (pos != null) {
        centerPosition = LatLng(pos.latitude, pos.longitude);
      }
    }

    final groupIndex = ref.watch(cameraGroupIndexProvider);
    final groupIds = ref.watch(groupOrderServiceProvider);
    final groupId = groupIds[groupIndex];
    final group = ref.watch(groupMetadataProvider(groupId)).value;
    final catalog = ref.watch(groupPinDesignCatalogProvider(groupId)).value;
    final design = MapPinDesign.forCatalog(
      catalog,
      group?.pinStyle ?? 'classic',
    );
    final groupProfileImage =
        (ref.watch(groupProfilePictureSmallByIdProvider(groupId)).value ??
        ref.read(defaultErrorImageProvider))!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Select Location",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            const Card(
              child: ListTile(
                title: Text("How to"),
                subtitle: Text(
                  "Select the sticker location by moving the map around until the marker in the center appropriately matches where your picture was taken.",
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Stack(
                  children: [
                    // Flutter Map widget
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: centerPosition,
                          minZoom: 2,
                          maxZoom: 18,
                          initialZoom: _zoom,
                          keepAlive: true,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag,
                          ),
                        ),
                        children: [
                          const CurrentLocationLayer(),
                          CustomTileLayer(),
                          const OsmCopyright(),
                        ],
                      ),
                    ),
                    // Center Pin Icon
                    Center(
                      child: SizedBox(
                        width: 40,
                        height: 80,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: const Offset(0, -7),
                            child: SizedBox(
                              width: 30,
                              height: 30 * 56 / 48,
                              child: PinMarkerImage(
                                isGone: false,
                                style: design.style,
                                design: design,
                                image: Image.memory(
                                  groupProfileImage,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SubmitButton(
                text: "Next",
                onPressed: () => context.pushNamed(
                  'imageUpload',
                  queryParameters: {
                    "lat": _mapController.camera.center.latitude.toString(),
                    "long": _mapController.camera.center.longitude.toString(),
                  },
                  extra: widget.image,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
