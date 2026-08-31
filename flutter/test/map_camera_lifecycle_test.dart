import 'dart:async';

import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart'
    as camera_page;
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  test('camera preview ratio follows the Android device orientation', () {
    const sensorAspectRatio = 16 / 9;

    expect(
      cameraPreviewAspectRatio(
        sensorAspectRatio: sensorAspectRatio,
        orientation: DeviceOrientation.landscapeRight,
      ),
      sensorAspectRatio,
    );
    expect(
      cameraPreviewAspectRatio(
        sensorAspectRatio: sensorAspectRatio,
        orientation: DeviceOrientation.portraitUp,
      ),
      9 / 16,
    );
  });

  testWidgets('camera preview viewport follows orientation changes', (
    tester,
  ) async {
    final controller = _FakeCameraController(
      orientation: DeviceOrientation.portraitUp,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: camera_page.cameraPreviewViewport(controller),
          ),
        ),
      ),
    );

    var previewChildSize = _fittedPreviewChildSize(tester);
    expect(previewChildSize.width, 320);
    expect(previewChildSize.height, closeTo(320 * 16 / 9, 0.001));

    controller.value = controller.value.copyWith(
      deviceOrientation: DeviceOrientation.landscapeRight,
    );
    await tester.pump();

    previewChildSize = _fittedPreviewChildSize(tester);
    expect(previewChildSize.width, 320);
    expect(previewChildSize.height, closeTo(320 * 9 / 16, 0.001));
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

Size _fittedPreviewChildSize(WidgetTester tester) {
  final fittedBox = tester.renderObject<RenderFittedBox>(
    find.byType(FittedBox),
  );
  return fittedBox.child!.size;
}

class _FakeCameraController extends CameraController {
  _FakeCameraController({required DeviceOrientation orientation})
    : super(_description, ResolutionPreset.low, enableAudio: false) {
    value = CameraValue(
      isInitialized: true,
      previewSize: const Size(16, 9),
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      flashMode: FlashMode.auto,
      exposureMode: ExposureMode.auto,
      exposurePointSupported: false,
      focusMode: FocusMode.auto,
      focusPointSupported: false,
      deviceOrientation: orientation,
      description: _description,
    );
  }

  static const _description = CameraDescription(
    name: 'test-camera',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  @override
  Widget buildPreview() => const SizedBox.expand();
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
