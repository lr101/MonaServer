import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup does not require a camera', () async {
    final cameras = await loadAvailableCameras(
      isWeb: true,
      loader: () async => throw CameraException('cameraNotFound', 'no camera'),
    );

    expect(cameras, isEmpty);
  });

  test('camera discovery failures do not block startup', () async {
    final cameras = await loadAvailableCameras(
      isWeb: false,
      loader: () async => throw CameraException('cameraNotFound', 'no camera'),
    );

    expect(cameras, isEmpty);
  });
}
