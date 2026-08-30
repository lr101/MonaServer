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

double cameraPreviewAspectRatio({
  required double sensorAspectRatio,
  required DeviceOrientation orientation,
}) {
  final isLandscape = orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;
  return isLandscape ? sensorAspectRatio : 1 / sensorAspectRatio;
}

int? cameraIndexForLength(int index, int length) {
  if (length <= 0) {
    return null;
  }
  return index.clamp(0, length - 1);
}

int nextCameraIndex(int currentIndex, int cameraCount) {
  final current = cameraIndexForLength(currentIndex, cameraCount);
  if (current == null) {
    return 0;
  }
  return (current + 1) % cameraCount;
}

String? groupIdAt(List<String> groupIds, int index) {
  if (index < 0 || index >= groupIds.length) {
    return null;
  }
  return groupIds[index];
}

class ZoomUpdateCoalescer {
  ZoomUpdateCoalescer(this._setZoomLevel);

  final Future<void> Function(double zoom) _setZoomLevel;
  double? _pendingZoom;
  Future<void>? _draining;

  Future<void> update(double zoom) {
    _pendingZoom = zoom;
    return _draining ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pendingZoom != null) {
        final zoom = _pendingZoom!;
        _pendingZoom = null;
        await _setZoomLevel(zoom);
      }
    } finally {
      _draining = null;
    }
  }
}

class CameraState {
  final double ratio;
  final double minZoom;
  final double maxZoom;

  CameraState({
    required this.ratio,
    required this.minZoom,
    required this.maxZoom,
  });
}

@riverpod
class CameraIndex extends _$CameraIndex {
  @override
  int build() {
    ref.watch(globalDataServiceProvider.select((data) => data.cameras.length));
    return 0;
  }

  void increment() {
    final cameras = ref.read(
      globalDataServiceProvider.select((data) => data.cameras),
    );
    state = nextCameraIndex(state, cameras.length);
  }

  // ignore: use_setters_to_change_properties
  void setIndex(int index) {
    final cameras = ref.read(
      globalDataServiceProvider.select((data) => data.cameras),
    );
    state = cameraIndexForLength(index, cameras.length) ?? 0;
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
    } on PlatformException catch (e) {
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
  final selectedIndex = cameraIndexForLength(cameraIndex, cameras.length);
  if (selectedIndex == null) {
    throw StateError('No cameras are available.');
  }

  final controller = CameraController(
    cameras[selectedIndex],
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
  int build() {
    ref.watch(groupOrderServiceProvider.select((groups) => groups.length));
    return 0;
  }

  // ignore: use_setters_to_change_properties
  void updateIndex(int index) {
    final groupIds = ref.read(groupOrderServiceProvider);
    state = cameraIndexForLength(index, groupIds.length) ?? 0;
  }
}

@riverpod
Future<GroupEntity?> cameraSelectedGroup(Ref ref) async {
  final groupIds = ref.watch(groupOrderServiceProvider);
  final groupCameraIndex = ref.watch(cameraGroupIndexProvider);
  final groupId = groupIdAt(groupIds, groupCameraIndex);
  if (groupId == null) {
    return null;
  }
  return await ref.watch(groupServiceProvider(groupId).future);
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
