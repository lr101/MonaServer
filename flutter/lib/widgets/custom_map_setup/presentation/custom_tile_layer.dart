import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class CustomTileLayer extends TileLayer {
  CustomTileLayer({super.key})
      : super(
            tileProvider: kIsWeb 
                ? NetworkTileProvider() 
                : FMTCTileProvider(stores: const {'tileStore': BrowseStoreStrategy.readUpdateCreate}),
            urlTemplate: "https://map.lr-projects.de/tile/{z}/{x}/{y}.png");
}
