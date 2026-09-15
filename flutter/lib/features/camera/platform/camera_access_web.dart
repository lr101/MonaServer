import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_web/camera_web.dart';
// camera_web has no public discovery hook. Keep this bridge isolated and pin
// its version until upstream offers enumeration without opening every lens.
// ignore: implementation_imports
import 'package:camera_web/src/types/camera_metadata.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

String? _setting(web.MediaStreamTrack track, String name) =>
    (track.getSettings().getProperty<JSAny?>(name.toJS) as JSString?)?.toDart;

Future<List<CameraDescription>> discoverCameras() async {
  final plugin = CameraPlatform.instance;
  if (plugin is! CameraPlugin) return availableCameras();
  if (!web.window.isSecureContext) {
    throw CameraException('cameraType', 'Camera access requires HTTPS.');
  }

  web.MediaStream? stream;
  try {
    final devices = web.window.navigator.mediaDevices;
    // Request video permission directly: Permissions API camera queries are
    // not supported consistently in Safari/Firefox. Prefer the main rear lens.
    stream = await devices
        .getUserMedia(
          web.MediaStreamConstraints(
            audio: false.toJS,
            video: {
              'facingMode': {'ideal': 'environment'},
            }.jsify()!,
          ),
        )
        .toDart;
    final tracks = stream.getVideoTracks().toDart;
    final selectedId = tracks.isEmpty
        ? null
        : _setting(tracks.first, 'deviceId');
    final selectedFacing = tracks.isEmpty
        ? null
        : _setting(tracks.first, 'facingMode');
    // Enumerate while permission's stream is live so labels/device IDs remain
    // available. Never open other lenses merely to discover their facing mode.
    final inputs = (await devices.enumerateDevices().toDart).toDart
        .where(
          (device) => device.kind == 'videoinput' && device.deviceId.isNotEmpty,
        )
        .toList();
    final descriptions = <CameraDescription>[];
    final metadata = <CameraDescription, CameraMetadata>{};
    for (var index = 0; index < inputs.length; index++) {
      final device = inputs[index];
      final label = device.label;
      final facing = device.deviceId == selectedId
          ? selectedFacing
          : RegExp(
              'back|rear|environment',
              caseSensitive: false,
            ).hasMatch(label)
          ? 'environment'
          : RegExp('front|user|facetime', caseSensitive: false).hasMatch(label)
          ? 'user'
          : null;
      final description = CameraDescription(
        name: '${label.isEmpty ? 'Camera' : label} (${index + 1})',
        lensDirection: facing == 'environment'
            ? CameraLensDirection.back
            : facing == 'user'
            ? CameraLensDirection.front
            : CameraLensDirection.external,
        sensorOrientation: 0,
      );
      if (device.deviceId == selectedId) {
        descriptions.insert(0, description);
      } else {
        descriptions.add(description);
      }
      metadata[description] = CameraMetadata(
        deviceId: device.deviceId,
        facingMode: facing,
      );
    }
    // This public, test-visible map is the plugin's required device-ID bridge.
    // ignore: invalid_use_of_visible_for_testing_member
    plugin.camerasMetadata
      ..clear()
      ..addAll(metadata);
    return descriptions;
  } catch (error) {
    if ((error as JSAny).isA<web.DOMException>()) {
      final exception = error as web.DOMException;
      throw CameraException(exception.name, exception.message);
    }
    rethrow;
  } finally {
    for (final track
        in stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
  }
}

void Function() configureCameraPreview(CameraController controller) {
  final plugin = CameraPlatform.instance;
  if (plugin is! CameraPlugin) return () {};
  // ignore: invalid_use_of_visible_for_testing_member
  final video = plugin.getCamera(controller.cameraId).videoElement;
  // The browser may renegotiate stream dimensions on rotation, independently
  // of camera_web's one-time initialized previewSize.
  video.style.objectFit = 'contain';
  void updateSize(web.Event? _) {
    if (video.videoWidth > 0 && video.videoHeight > 0) {
      controller.value = controller.value.copyWith(
        previewSize: Size(
          video.videoWidth.toDouble(),
          video.videoHeight.toDouble(),
        ),
      );
    }
  }

  final listener = ((web.Event event) => updateSize(event)).toJS;
  video.addEventListener('resize', listener);
  updateSize(null);
  return () => video.removeEventListener('resize', listener);
}
