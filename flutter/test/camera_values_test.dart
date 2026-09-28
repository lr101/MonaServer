import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CameraWithoutZoom extends CameraController {
  _CameraWithoutZoom()
    : super(
        const CameraDescription(
          name: 'browser camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      ) {
    value = value.copyWith(previewSize: const Size(1280, 720));
  }

  @override
  Future<double> getMinZoomLevel() async =>
      throw CameraException('zoomLevelNotSupported', 'No zoom');
}

void main() {
  test(
    'unsupported browser zoom does not prevent the preview becoming ready',
    () async {
      final controller = _CameraWithoutZoom();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          cameraControllerProvider.overrideWith(
            (ref) => Future.value(controller),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.dispose);
      final subscription = container.listen(cameraValuesProvider, (_, _) {});
      addTearDown(subscription.close);
      final values = await container.read(cameraValuesProvider.future);
      expect(values.minZoom, 1);
      expect(values.maxZoom, 1);
    },
  );
}
