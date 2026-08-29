import 'dart:async';

import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('replacing a map location animation removes stale callbacks', (
    tester,
  ) async {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: tester,
    );
    final movedCenters = <LatLng>[];
    final completedCenters = <LatLng>[];
    final animator = MapLocationAnimator(
      controller: controller,
      move: (center, zoom) => movedCenters.add(center),
      onComplete: (center, zoom) => completedCenters.add(center),
    );
    const staleDestination = LatLng(10, 20);
    const destination = LatLng(30, 40);

    animator.animate(
      currentCenter: const LatLng(0, 0),
      currentZoom: 5,
      destination: staleDestination,
      destinationZoom: 10,
    );
    animator.animate(
      currentCenter: const LatLng(0, 0),
      currentZoom: 5,
      destination: destination,
      destinationZoom: 15,
    );

    await tester.pumpAndSettle();

    expect(controller.status, AnimationStatus.completed);
    expect(movedCenters, isNot(contains(staleDestination)));
    expect(completedCenters, [destination]);

    animator.dispose();
    controller.dispose();
  });

  test(
    'denied permission remains unavailable after a denied request',
    () async {
      final permissions = _FakeLocationPermissionGateway(
        checkedPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );

      final granted = await hasLocationPermission(permissions);

      expect(granted, isFalse);
      expect(permissions.requestCount, 1);
    },
  );

  test('empty camera and group collections have no selectable index', () {
    expect(cameraIndexForLength(0, 0), isNull);
    expect(cameraIndexForLength(5, 3), 2);
    expect(groupIdAt([], 0), isNull);
    expect(groupIdAt(['group-a'], 1), isNull);
  });

  test('static markers do not create an animation controller', () {
    expect(
      createMarkerAnimationController(
        withAnimation: false,
        vsync: _TestVsync(),
      ),
      isNull,
    );
  });

  test('zoom updates coalesce while a platform update is pending', () async {
    final firstUpdate = Completer<void>();
    final calls = <double>[];
    final coalescer = ZoomUpdateCoalescer((zoom) {
      calls.add(zoom);
      return calls.length == 1 ? firstUpdate.future : Future.value();
    });

    final firstRequest = coalescer.update(1.2);
    final secondRequest = coalescer.update(1.5);
    final thirdRequest = coalescer.update(2.0);

    expect(calls, [1.2]);

    firstUpdate.complete();
    await Future.wait([firstRequest, secondRequest, thirdRequest]);

    expect(calls, [1.2, 2.0]);
  });
}

class _FakeLocationPermissionGateway implements LocationPermissionGateway {
  _FakeLocationPermissionGateway({
    required this.checkedPermission,
    required this.requestedPermission,
  });

  final LocationPermission checkedPermission;
  final LocationPermission requestedPermission;
  int requestCount = 0;

  @override
  Future<LocationPermission> checkPermission() async => checkedPermission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    return requestedPermission;
  }
}

class _TestVsync extends TestVSync {}
