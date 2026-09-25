import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/camera/presentation/camera_group_selector.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:camera/camera.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCameraController extends CameraController {
  _FakeCameraController()
    : super(
        const CameraDescription(
          name: 'test-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.low,
        enableAudio: false,
      ) {
    value = const CameraValue(
      isInitialized: true,
      previewSize: Size(16, 9),
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      flashMode: FlashMode.auto,
      exposureMode: ExposureMode.auto,
      exposurePointSupported: false,
      focusMode: FocusMode.auto,
      focusPointSupported: false,
      deviceOrientation: DeviceOrientation.portraitUp,
      description: cameraDescription,
    );
  }

  static const cameraDescription = CameraDescription(
    name: 'test-camera',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  Completer<XFile>? pendingCapture;

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<double> getMinZoomLevel() async => 1;

  @override
  Future<double> getMaxZoomLevel() async => 1;

  @override
  Future<void> resumePreview() async {}

  @override
  Future<XFile> takePicture() =>
      pendingCapture?.future ??
      Future.value(
        XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'pin-update.jpg'),
      );
}

class _CameraPlatform extends CameraPlatform {
  _CameraPlatform(this.cameras);

  final List<CameraDescription> cameras;

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;
}

void main() {
  testWidgets('group shutter stays centered on a bounded carousel on tablets', (
    tester,
  ) async {
    final controller = PageController(
      viewportFraction: CameraGroupSelector.itemViewportFraction,
      initialPage: 2,
    );
    final capturedGroups = <int>[];
    var selectedIndex = 2;
    await tester.binding.setSurfaceSize(const Size(1600, 420));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => CameraGroupSelector(
                controller: controller,
                selectedIndex: selectedIndex,
                onPageChanged: (index) => setState(() => selectedIndex = index),
                onCapture: capturedGroups.add,
                children: List.generate(
                  5,
                  (index) => Center(child: CircleAvatar(child: Text('$index'))),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final carousel = tester.getRect(find.byType(PageView));
    final ring = tester.getRect(
      find.byKey(const ValueKey('camera-group-shutter-ring')),
    );
    expect(carousel.width, closeTo(420, .01));
    expect(ring.center.dx, closeTo(carousel.center.dx, .01));
    expect(ring.center.dy, closeTo(carousel.center.dy, .01));
    expect(
      tester.getRect(find.text('2')).center.dx,
      closeTo(ring.center.dx, 1),
    );
    expect(
      (tester.getRect(find.text('3')).center.dx - ring.center.dx).abs(),
      lessThan(104),
    );

    await tester.timedDragFrom(
      ring.center + Offset(ring.width / 2 + 8, 0),
      const Offset(-140, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(selectedIndex, isNot(2));
    final selectedRing = tester.getRect(
      find.byKey(const ValueKey('camera-group-shutter-ring')),
    );
    expect(
      tester.getRect(find.text('$selectedIndex')).center.dx,
      closeTo(selectedRing.center.dx, 1),
    );
    await tester.tapAt(selectedRing.center);
    expect(capturedGroups, [selectedIndex]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pin update mode captures from preview and returns the file', (
    tester,
  ) async {
    const cameras = [_FakeCameraController.cameraDescription];
    final controller = _FakeCameraController();
    final originalPlatform = CameraPlatform.instance;
    CameraPlatform.instance = _CameraPlatform(cameras);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    addTearDown(() async {
      CameraPlatform.instance = originalPlatform;
      await controller.dispose();
    });

    XFile? captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: null,
              refreshToken: null,
              cameras: cameras,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          groupOrderServiceProvider.overrideWithValue([]),
          cameraControllerProvider.overrideWith(
            (ref) => Future.value(controller),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  captured = await Navigator.of(context).push<XFile>(
                    MaterialPageRoute(
                      builder: (_) => const Camera(pinPhotoMode: true),
                    ),
                  );
                },
                child: const Text('Open pin camera'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open pin camera'));
    await tester.pumpAndSettle();

    expect(find.text('Take pin photo'), findsOneWidget);
    expect(find.byTooltip('Take photo'), findsOneWidget);
    expect(find.byTooltip('Upload photo'), findsNothing);
    await tester.tap(find.byTooltip('Take photo'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(await captured!.readAsBytes(), [1, 2, 3]);
    expect(find.text('Open pin camera'), findsOneWidget);

    controller.pendingCapture = Completer<XFile>();
    await tester.tap(find.text('Open pin camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Take photo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Open pin camera')),
    );
    expect(container.read(cameraCapturingProvider), isFalse);
    controller.pendingCapture!.complete(
      XFile.fromData(Uint8List.fromList([1, 2, 3])),
    );
    await tester.pump();
  });

  testWidgets(
    'keeps selector above upload in the preview corner on compact screens',
    (tester) async {
      const cameras = [
        CameraDescription(
          name: 'back-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        CameraDescription(
          name: 'front-camera',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
      ];
      final controller = _FakeCameraController();
      final originalPlatform = CameraPlatform.instance;
      CameraPlatform.instance = _CameraPlatform(cameras);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.binding.setSurfaceSize(const Size(320, 240));
      addTearDown(() async {
        CameraPlatform.instance = originalPlatform;
        await tester.binding.setSurfaceSize(null);
        await controller.dispose();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            globalDataOnceProvider.overrideWithValue(
              const GlobalDataDto(
                userId: null,
                refreshToken: null,
                cameras: cameras,
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            groupOrderServiceProvider.overrideWithValue([]),
            cameraControllerProvider.overrideWith(
              (ref) => Future.value(controller),
            ),
          ],
          child: const MaterialApp(home: Camera()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final upload = find.byTooltip('Upload photo');
      final selector = find.byTooltip('Select camera');
      expect(upload, findsOneWidget);
      expect(selector, findsOneWidget);
      expect(
        tester.getTopLeft(selector).dy,
        lessThan(tester.getTopLeft(upload).dy),
      );
      expect(tester.getBottomRight(selector).dx, lessThanOrEqualTo(320));
      expect(tester.getBottomRight(selector).dy, lessThanOrEqualTo(240));
      expect(tester.takeException(), isNull);

      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('Back camera'), findsOneWidget);
      expect(find.text('Front camera'), findsOneWidget);
      final menu = find
          .ancestor(
            of: find.text('Back camera'),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getRect(menu).bottom,
        lessThanOrEqualTo(tester.getTopLeft(upload).dy),
      );
      expect(
        tester.getTopLeft(find.text('Back camera')).dy,
        greaterThanOrEqualTo(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not overflow when navigation reduces the preview height', (
    tester,
  ) async {
    const cameras = [
      CameraDescription(
        name: 'back-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      CameraDescription(
        name: 'front-camera',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
    final controller = _FakeCameraController();
    final originalPlatform = CameraPlatform.instance;
    CameraPlatform.instance = _CameraPlatform(cameras);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.binding.setSurfaceSize(const Size(320, 160));
    addTearDown(() async {
      CameraPlatform.instance = originalPlatform;
      await tester.binding.setSurfaceSize(null);
      await controller.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: null,
              refreshToken: null,
              cameras: cameras,
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          groupOrderServiceProvider.overrideWithValue([]),
          cameraControllerProvider.overrideWith(
            (ref) => Future.value(controller),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Camera(),
            bottomNavigationBar: SizedBox(height: 80),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Select camera'));
    await tester.pumpAndSettle();
    expect(find.text('Back camera'), findsOneWidget);
    expect(find.text('Front camera'), findsOneWidget);
    await tester.tap(find.text('Front camera'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
