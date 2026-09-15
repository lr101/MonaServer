import 'package:camera/camera.dart';

Future<List<CameraDescription>> discoverCameras() => availableCameras();

void Function() configureCameraPreview(CameraController controller) => () {};
