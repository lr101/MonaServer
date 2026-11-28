import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

// Hue-preserving luminance-inverted neutral charcoal matrix for dark map tiles:
// keeps land calm slate (#1E2125), parks subtle dark green, water muted slate-blue,
// and street labels crisp light grey without heavy navy/blue arterial glare.
const ColorFilter _darkMapTileFilter = ColorFilter.matrix(<double>[
  -0.053, -0.693, -0.135, 0, 240,
  -0.353, -0.393, -0.135, 0, 244,
  -0.353, -0.693, 0.165, 0, 250,
  0, 0, 0, 1, 0,
]);

class CustomTileLayer extends StatelessWidget {
  static final TileProvider _webTileProvider = NetworkTileProvider();

  const CustomTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      tileProvider: kIsWeb
          ? _webTileProvider
          : FMTCTileProvider(
              stores: const {
                'tileStore': BrowseStoreStrategy.readUpdateCreate,
              },
            ),
      urlTemplate: "https://map.lr-projects.de/tile/{z}/{x}/{y}.png",
      tileBuilder: isDark
          ? (context, tileWidget, tile) => Transform.scale(
              scale: 1.003,
              child: ColorFiltered(
                colorFilter: _darkMapTileFilter,
                child: tileWidget,
              ),
            )
          : null,
    );
  }
}
