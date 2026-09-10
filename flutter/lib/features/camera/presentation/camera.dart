import 'dart:async';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera_selector.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mutex/mutex.dart';
import 'package:native_exif/native_exif.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';

class Camera extends ConsumerStatefulWidget {
  const Camera({super.key});

  @override
  ConsumerState<Camera> createState() => _CameraState();
}

class _CameraState extends ConsumerState<Camera> with WidgetsBindingObserver {
  final PageController pageController = PageController(viewportFraction: 0.3);
  double scaleFactor = 1.0;
  double basScaleFactor = 1.0;
  final _m = Mutex();
  late final ZoomUpdateCoalescer _zoomUpdates;
  bool _discoveringCameras = true;
  Object? _discoveryError;
  bool _webCaptureInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      unawaited(_discoverCameras());
    }
    _zoomUpdates = ZoomUpdateCoalescer((zoom) async {
      final controller = ref.read(cameraControllerProvider).value;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }
      await controller.setZoomLevel(zoom);
    });
  }

  Future<void> _discoverCameras() async {
    try {
      await ref.read(globalDataServiceProvider.notifier).refreshCameraList();
    } catch (error) {
      if (!mounted) return;
      _discoveryError = error;
    }
    if (!mounted) return;
    setState(() => _discoveringCameras = false);
  }

  Widget _cameraDiscoveryStatus(Widget child) {
    return Scaffold(
      body: SafeArea(child: Center(child: child)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (!_discoveringCameras &&
        _discoveryError == null &&
        (route?.isCurrent ?? false)) {
      final controller = ref.read(cameraControllerProvider).value;
      if (controller != null && controller.value.isInitialized) {
        controller.resumePreview();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebCameraFallback(context);
    }
    if (_discoveringCameras) {
      return _cameraDiscoveryStatus(const CircularProgressIndicator());
    }
    if (_discoveryError != null) {
      final error = _discoveryError;
      final denied =
          error is CameraException &&
          (error.code == 'NotAllowedError' ||
              error.code.startsWith('CameraAccessDenied') ||
              error.code == 'CameraAccessRestricted');
      return _cameraDiscoveryStatus(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              denied
                  ? 'Allow camera access in your browser or device settings, then retry.'
                  : 'Could not access the camera. Check that it is connected and available.',
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _discoveryError = null;
                  _discoveringCameras = true;
                });
                unawaited(_discoverCameras());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    ref.listen(cameraTorchProvider, (_, next) {
      ref
          .read(cameraControllerProvider)
          .value
          ?.setFlashMode(next ? FlashMode.off : FlashMode.auto);
    });
    final cameras = ref.watch(
      globalDataServiceProvider.select((t) => t.cameras),
    );
    final cameraFlashMode = ref.watch(cameraTorchProvider);
    final groupIds = ref.watch(groupOrderServiceProvider);
    if (cameras.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('No cameras are available on this device.'),
          ),
        ),
      );
    }
    final controllerAsync = ref.watch(cameraControllerProvider);
    final cameraStateAsync = ref.watch(cameraValuesProvider);
    final cameraIndex = ref.watch(cameraIndexProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    // We handle the AsyncValue of the CONTROLLER here
                    child: controllerAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Center(child: Text("Camera Error: $err")),
                      data: (controller) {
                        // Once controller is ready, we check the Values state
                        return cameraStateAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Text(err.toString()),
                          data: (cameraState) => GestureDetector(
                            onDoubleTap: ref
                                .read(cameraIndexProvider.notifier)
                                .increment,
                            onScaleStart: (_) => basScaleFactor = scaleFactor,
                            onScaleUpdate: (details) =>
                                handleZoom(details, cameraState),
                            child: cameraPreviewViewport(controller),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: FractionalOffset.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 75),
                      child: ref.watch(cameraCapturingProvider)
                          ? Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).highlightColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Text("Hold steady capturing ..."),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Align(
                    alignment: FractionalOffset.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.withValues(
                                  alpha: 0.5,
                                ),
                                child: Center(
                                  child: IconButton(
                                    onPressed: () =>
                                        handleFlashChange(!cameraFlashMode),
                                    icon: cameraFlashMode
                                        ? const Icon(Icons.flash_off)
                                        : const Icon(Icons.flash_auto),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: SizedBox.square(
                                dimension: 48,
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey.withValues(
                                    alpha: 0.5,
                                  ),
                                  child: CameraSelectorButton(
                                    cameras: cameras,
                                    selectedIndex: cameraIndex,
                                    onSelected: handleCameraChange,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.withValues(
                                  alpha: 0.5,
                                ),
                                child: Center(
                                  child: GestureDetector(
                                    onTap: uploadFileImage,
                                    child: const Icon(Icons.upload),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (groupIds.isNotEmpty)
              SizedBox(
                height: (MediaQuery.of(context).size.height) * 0.15,
                child: Stack(
                  children: [
                    Center(
                      child: SnappingPageScroll(
                        controller: pageController,
                        onPageChanged: onPageChange,
                        children: List.generate(
                          groupIds.length,
                          (index) => groupCard(groupIds[index], index),
                        ),
                      ),
                    ),
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 5.0,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: BoxShape.circle,
                          ),
                          height:
                              (MediaQuery.of(context).size.height) * 0.07 * 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildWebCameraFallback(BuildContext context) {
    final groupIds = ref.watch(groupOrderServiceProvider);
    final groupIndex = ref.watch(cameraGroupIndexProvider);
    final selectedGroupId = groupIdAt(groupIds, groupIndex);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Use your device camera to take a photo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: selectedGroupId == null
                            ? null
                            : _takeWebCameraPicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take photo'),
                      ),
                      if (selectedGroupId == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Join a group before taking a photo.'),
                        ),
                      TextButton.icon(
                        onPressed: selectedGroupId == null
                            ? null
                            : uploadFileImage,
                        icon: const Icon(Icons.upload),
                        label: const Text('Choose from gallery'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (groupIds.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.15,
                child: Stack(
                  children: [
                    Center(
                      child: SnappingPageScroll(
                        controller: pageController,
                        onPageChanged: onPageChange,
                        children: List.generate(
                          groupIds.length,
                          (index) => groupCard(groupIds[index], index),
                        ),
                      ),
                    ),
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 5,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: BoxShape.circle,
                          ),
                          height: MediaQuery.of(context).size.height * 0.07 * 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Future<void> _takeWebCameraPicture() async {
    if (_webCaptureInProgress) return;
    _webCaptureInProgress = true;
    ref.read(cameraCapturingProvider.notifier).setCapturing(true);
    try {
      // image_picker uses a single user-initiated file input with capture=environment
      // on mobile browsers. This avoids camera_web.availableCameras(), which opens
      // and closes every camera and can fail with AbortError in Firefox for Android.
      final pickedFile = await pickCameraImage(context: context);
      if (pickedFile != null && mounted) {
        await _handleImage(pickedFile, fromGallery: false);
      }
    } catch (error) {
      if (mounted) {
        CustomErrorSnackBar.message(message: 'Could not capture image');
      }
      debugPrint('Web camera capture error: $error');
    } finally {
      _webCaptureInProgress = false;
      if (mounted) {
        ref.read(cameraCapturingProvider.notifier).setCapturing(false);
      }
    }
  }

  void handleZoom(ScaleUpdateDetails scale, CameraState state) {
    if (scale.scale * basScaleFactor <= state.maxZoom &&
        scale.scale * basScaleFactor >= state.minZoom) {
      scaleFactor = basScaleFactor * scale.scale;
      unawaited(
        _zoomUpdates.update(scaleFactor).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Could not update camera zoom: $error');
        }),
      );
    }
  }

  Future<void> uploadFileImage() async {
    final pickedFile = await CustomImagePicker.pick(context: context);
    if (pickedFile != null && mounted) {
      await _handleImage(pickedFile, fromGallery: true);
    }
  }

  void handleCameraChange(int index) {
    ref.read(cameraIndexProvider.notifier).setIndex(index);
  }

  void handleFlashChange(bool value) {
    ref.read(cameraTorchProvider.notifier).setTorch(value);
  }

  void onPageChange(int index) {
    ref.read(cameraGroupIndexProvider.notifier).updateIndex(index);
  }

  Widget groupCard(String groupId, int index) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: GestureDetector(
          onTap: () => takePicture(groupId, index),
          child: RoundImage(
            size: (MediaQuery.of(context).size.height) * 0.06,
            imageCallback: ref.watch(groupProfilePictureByIdProvider(groupId)),
            child: Container(),
          ),
        ),
      ),
    );
  }

  Future<void> takePicture(String groupId, int index) async {
    final indexProvider = ref.read(cameraGroupIndexProvider);
    if (index != indexProvider) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
      );
      return;
    }
    if (kIsWeb) {
      await _takeWebCameraPicture();
      return;
    }
    final controller = ref.read(cameraControllerProvider).value;
    if (_m.isLocked || controller == null) return;
    await _m.acquire();
    ref.read(cameraCapturingProvider.notifier).setCapturing(true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      await _handleImage(image, fromGallery: false);
    } catch (e) {
      if (kDebugMode) print(e);
    } finally {
      _m.release();
      ref.read(cameraCapturingProvider.notifier).setCapturing(false);
    }
  }

  Future<void> _handleImage(XFile file, {required bool fromGallery}) async {
    final controller = kIsWeb ? null : ref.read(cameraControllerProvider).value;
    try {
      if (controller != null && controller.value.isInitialized) {
        await controller.pausePreview().catchError((_) {});
      }
      if (!mounted) return;
      final croppedImage = await CustomImagePicker.autoCrop(res: file);
      if (croppedImage == null) {
        if (controller != null && controller.value.isInitialized) {
          await controller.resumePreview().catchError((_) {});
        }
        return;
      }

      LatLng? coords;
      if (fromGallery) {
        try {
          final exif = await Exif.fromPath(file.path);
          final coord = await exif.getLatLong();
          if (coord != null) coords = LatLng(coord.latitude, coord.longitude);
        } catch (e) {
          debugPrint("Exif error: $e");
        }
      } else {
        try {
          final position = await Geolocator.getCurrentPosition();
          coords = LatLng(position.latitude, position.longitude);
        } catch (e) {
          debugPrint("Location error: $e");
        }
      }

      if (!mounted) return;
      if (coords != null && !fromGallery) {
        context.pushNamed(
          'imageUpload',
          queryParameters: {
            "lat": coords.latitude.toString(),
            "long": coords.longitude.toString(),
          },
          extra: croppedImage,
        );
      } else {
        context.pushNamed(
          'selectLocation',
          queryParameters: coords != null
              ? {
                  "lat": coords.latitude.toString(),
                  "long": coords.longitude.toString(),
                }
              : {},
          extra: croppedImage,
        );
      }
    } catch (e) {
      CustomErrorSnackBar.message(message: "Could not load or crop image");
      debugPrint(e.toString());
    }
  }
}

Future<XFile?> pickCameraImage({required BuildContext context}) {
  return CustomImagePicker.pick(context: context, source: ImageSource.camera);
}

Widget cameraPreviewViewport(CameraController controller, {bool? isWeb}) {
  final useWebPreview = isWeb ?? kIsWeb;
  return ValueListenableBuilder<CameraValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final previewSize = value.previewSize;
      if (!isValidCameraPreviewSize(previewSize)) {
        return const SizedBox.shrink();
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final aspectRatio = useWebPreview
              ? cameraPreviewDisplayAspectRatio(
                  previewSize: previewSize!,
                  orientation: value.deviceOrientation,
                )
              : cameraPreviewAspectRatio(
                  sensorAspectRatio: value.aspectRatio,
                  orientation: value.deviceOrientation,
                );
          final preview = useWebPreview
              ? _webCameraPreview(controller, value)
              : CameraPreview(controller);

          return ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / aspectRatio,
                child: preview,
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _webCameraPreview(CameraController controller, CameraValue value) {
  final previewSize = value.previewSize;
  if (!isValidCameraPreviewSize(previewSize)) {
    return const SizedBox.shrink();
  }

  final cameraTurns = cameraPreviewQuarterTurns(
    previewSize: previewSize!,
    orientation: value.deviceOrientation,
  );
  // camera_web mirrors non-back cameras inside the HTML video element. Add a
  // half-turn before an odd quarter-turn so that the final mirror remains
  // horizontal after the platform view is rotated.
  final quarterTurns =
      value.description.lensDirection != CameraLensDirection.back &&
          cameraTurns.isOdd
      ? (cameraTurns + 2) % 4
      : cameraTurns;

  return RotatedBox(
    quarterTurns: quarterTurns,
    child: AspectRatio(
      aspectRatio: previewSize.width / previewSize.height,
      child: controller.buildPreview(),
    ),
  );
}
