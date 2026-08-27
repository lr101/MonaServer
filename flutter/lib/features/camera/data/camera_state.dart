
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'camera_state.g.dart';

class CameraState {
  final double ratio;
  final double minZoom;
  final double maxZoom;

  CameraState({required this.ratio, required this.minZoom, required this.maxZoom});

}

@riverpod
class CameraIndex extends _$CameraIndex {

  @override
  int build() {
    return 0;
  }

  void increment() {
    state = (state + 1) % ref.watch(globalDataServiceProvider.select((t) => t.cameras)).length;
  }

  // ignore: use_setters_to_change_properties
  void setIndex(int index) {
    state = index;
  }

}

@riverpod
class CameraValues extends _$CameraValues {
  // Remove the argument from build()
  @override
  Future<CameraState> build() async {
    // Watch the controller provider. 
    // This waits for the camera to initialize before running the logic below.
    final controller = await ref.watch(cameraControllerProvider.future);
    double minZoom = 1;
    double maxZoom = 1;

    try {
      minZoom = await controller.getMinZoomLevel();
      maxZoom = await controller.getMaxZoomLevel();
    } on PlatformException catch(e) {
      debugPrint("Zoom not supported on this camera: ${e.message}");
    }
    // Return the calculated state
    return CameraState(
      ratio: controller.value.aspectRatio,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }
}

@riverpod
Future<CameraController> cameraController(Ref ref) async {
  final cameraIndex = ref.watch(cameraIndexProvider);
  final cameras = ref.watch(globalDataServiceProvider.select((d) => d.cameras));
  
  final controller = CameraController(
    cameras[cameraIndex],
    ResolutionPreset.high,
    enableAudio: false,
  );

  // 3. Register disposal (This fixes the "disposed" bug automatically)
  ref.onDispose(() {
    controller.dispose();
  });

  // 4. Initialize
  await controller.initialize();
  return controller;
}

@Riverpod(keepAlive: true)
class CameraGroupIndex extends _$CameraGroupIndex {

  @override
  int build() => 0;

  // ignore: use_setters_to_change_properties
  void updateIndex(int index) {
    state = index;
  }

}

@riverpod
Future<GroupEntity?> cameraSelectedGroup(Ref ref) async {
  final groupIds = ref.watch(groupOrderServiceProvider);
  final groupCameraIndex = ref.watch(cameraGroupIndexProvider);
  return await ref.watch(groupServiceProvider(groupIds[groupCameraIndex]).future);
}

@Riverpod(keepAlive: true)
class CameraCapturing extends _$CameraCapturing {

  @override
  bool build() {
    return false;
  }

  // ignore: use_setters_to_change_properties
  void setCapturing(bool value) {
    state = value;
  }
}
