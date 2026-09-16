import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
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

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<double> getMinZoomLevel() async => 1;

  @override
  Future<double> getMaxZoomLevel() async => 1;

  @override
  Future<void> resumePreview() async {}
}

class _CameraPlatform extends CameraPlatform {
  _CameraPlatform(this.cameras);

  final List<CameraDescription> cameras;

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;
}

void main() {
  testWidgets(
    'keeps upload above selector in the preview corner on compact screens',
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
        tester.getTopLeft(upload).dy,
        lessThan(tester.getTopLeft(selector).dy),
      );
      expect(tester.getBottomRight(selector).dx, lessThanOrEqualTo(320));
      expect(tester.getBottomRight(selector).dy, lessThanOrEqualTo(160));
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
}
