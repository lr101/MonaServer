import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_state.freezed.dart';
part 'map_state.g.dart';

abstract interface class LocationPermissionGateway {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
}

class GeolocatorLocationPermissionGateway implements LocationPermissionGateway {
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
}

Future<bool> hasLocationPermission(
  LocationPermissionGateway permissions,
) async {
  var permission = await permissions.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await permissions.requestPermission();
  }
  return permission != LocationPermission.denied &&
      permission != LocationPermission.deniedForever;
}

class MapLocationAnimator {
  MapLocationAnimator({
    required this.controller,
    required this.move,
    required this.onComplete,
  });

  final AnimationController controller;
  final void Function(LatLng center, double zoom) move;
  final void Function(LatLng center, double zoom) onComplete;
  VoidCallback? _animationListener;
  AnimationStatusListener? _statusListener;

  void animate({
    required LatLng currentCenter,
    required double currentZoom,
    required LatLng destination,
    required double destinationZoom,
  }) {
    controller.stop();
    _removeListeners();

    final latitude = Tween<double>(
      begin: currentCenter.latitude,
      end: destination.latitude,
    );
    final longitude = Tween<double>(
      begin: currentCenter.longitude,
      end: destination.longitude,
    );
    final zoom = Tween<double>(begin: currentZoom, end: destinationZoom);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    _animationListener = () {
      move(
        LatLng(latitude.evaluate(animation), longitude.evaluate(animation)),
        zoom.evaluate(animation),
      );
    };
    _statusListener = (status) {
      if (status != AnimationStatus.completed) {
        return;
      }
      _removeListeners();
      onComplete(destination, destinationZoom);
    };
    controller.addListener(_animationListener!);
    controller.addStatusListener(_statusListener!);
    controller.forward(from: 0);
  }

  void dispose() {
    controller.stop();
    _removeListeners();
  }

  void _removeListeners() {
    final animationListener = _animationListener;
    if (animationListener != null) {
      controller.removeListener(animationListener);
      _animationListener = null;
    }
    final statusListener = _statusListener;
    if (statusListener != null) {
      controller.removeStatusListener(statusListener);
      _statusListener = null;
    }
  }
}

@freezed
abstract class MapState with _$MapState {
  const factory MapState({required List<Marker> markers}) = _MapState;
}

@Riverpod(keepAlive: true)
class MapStates extends _$MapStates {
  @override
  MapState build() {
    return MapState(
      markers: ref
          .watch(activatedPinsWithoutLoadingProvider)
          .map((e) => CustomMarkerWidget(pinDto: e))
          .toList(),
    );
  }
}

@Riverpod(keepAlive: true)
Stream<Position> currentLocation(Ref ref) async* {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  if (!await hasLocationPermission(GeolocatorLocationPermissionGateway())) {
    CustomErrorSnackBar.message(
      message: 'Some functions do not work without location permission',
      type: CustomErrorSnackBarType.error,
    );
    return;
  }

  final positionStream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    ),
  );
  positionStream.first.then((position) {
    sharedPrefs.setDouble('lastKnownLong', position.longitude);
    sharedPrefs.setDouble('lastKnownLat', position.latitude);
  });
  yield* positionStream;
}

@Riverpod(keepAlive: true)
class MapZoomLevel extends _$MapZoomLevel {
  @override
  double build() {
    return 5;
  }

  void setZoom(double zoom) {
    state = zoom;
  }
}
