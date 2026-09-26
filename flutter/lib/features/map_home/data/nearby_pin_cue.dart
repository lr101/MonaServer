import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openapi/api.dart';

const nearbyPinCueRadiusMeters = 75;
const nearbyPinCueMaxLocationAccuracyMeters = 50.0;

final nearbyPinCandidatesProvider =
    FutureProvider.autoDispose<List<NearbyPinDto>>((ref) async {
      final position = ref.watch(currentLocationProvider).value;
      if (position == null || !hasCredibleNearbyLocation(position)) {
        return const [];
      }

      try {
        final response = await ref
            .watch(pinApiProvider)
            .getNearbyPins(
              position.latitude,
              position.longitude,
              nearbyPinCueRadiusMeters,
            );
        return response?.items ?? const [];
      } catch (_) {
        // Location discovery is a convenience. A transient API failure should
        // leave the map usable and remove any stale cue.
        return const [];
      }
    });

bool hasCredibleNearbyLocation(Position? position) =>
    position != null &&
    position.latitude.isFinite &&
    position.latitude >= -90 &&
    position.latitude <= 90 &&
    position.longitude.isFinite &&
    position.longitude >= -180 &&
    position.longitude <= 180 &&
    position.accuracy.isFinite &&
    position.accuracy >= 0 &&
    position.accuracy <= nearbyPinCueMaxLocationAccuracyMeters;
