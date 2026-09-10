import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraSelectorButton extends StatelessWidget {
  const CameraSelectorButton({
    required this.cameras,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<CameraDescription> cameras;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = _cameraLabels(cameras);
    final selectedCameraIndex = _selectedCameraIndex;

    return PopupMenuButton<int>(
      tooltip: 'Select camera',
      icon: const Icon(Icons.flip_camera_android),
      onSelected: onSelected,
      itemBuilder: (context) => List.generate(
        cameras.length,
        (index) => CheckedPopupMenuItem<int>(
          value: index,
          checked: index == selectedCameraIndex,
          child: Row(
            children: [
              Icon(_cameraIcon(cameras[index].lensDirection)),
              const SizedBox(width: 12),
              Text(labels[index]),
            ],
          ),
        ),
      ),
    );
  }

  int get _selectedCameraIndex {
    if (cameras.isEmpty || selectedIndex < 0) return 0;
    if (selectedIndex >= cameras.length) return cameras.length - 1;
    return selectedIndex;
  }
}

List<String> _cameraLabels(List<CameraDescription> cameras) {
  final counts = <CameraLensDirection, int>{};
  final seen = <CameraLensDirection, int>{};
  for (final camera in cameras) {
    counts.update(
      camera.lensDirection,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  return cameras.map((camera) {
    final direction = camera.lensDirection;
    final occurrence = (seen[direction] ?? 0) + 1;
    seen[direction] = occurrence;
    final label = _cameraLabel(direction);
    return counts[direction] == 1 ? label : '$label $occurrence';
  }).toList();
}

String _cameraLabel(CameraLensDirection direction) {
  return switch (direction) {
    CameraLensDirection.back => 'Back camera',
    CameraLensDirection.front => 'Front camera',
    CameraLensDirection.external => 'External camera',
  };
}

IconData _cameraIcon(CameraLensDirection direction) {
  return switch (direction) {
    CameraLensDirection.back => Icons.camera_rear,
    CameraLensDirection.front => Icons.camera_front,
    CameraLensDirection.external => Icons.videocam,
  };
}
