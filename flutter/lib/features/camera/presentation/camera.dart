import 'dart:async';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera_group_selector.dart';
import 'package:buff_lisa/features/camera/presentation/camera_selector.dart';
import 'package:buff_lisa/features/progression/data/profile_picture_progression_provider.dart';
import 'package:buff_lisa/features/progression/data/profile_progression_prefetch.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
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

class Camera extends ConsumerStatefulWidget {
  const Camera({super.key, this.pinPhotoMode = false});

  /// Captures a photo for an existing pin and returns it to the calling page.
  final bool pinPhotoMode;

  @override
  ConsumerState<Camera> createState() => _CameraState();
}

class _CameraState extends ConsumerState<Camera> with WidgetsBindingObserver {
  late final PageController pageController;
  double scaleFactor = 1.0;
  double basScaleFactor = 1.0;
  final _m = Mutex();
  late final ZoomUpdateCoalescer _zoomUpdates;
  late final CameraCapturing _capturingNotifier;
  bool _discoveringCameras = true;
  bool _pinCapturing = false;
  Object? _discoveryError;

  @override
  void initState() {
    super.initState();
    _capturingNotifier = ref.read(cameraCapturingProvider.notifier);
    final groupIds = ref.read(groupOrderServiceProvider);
    final initialGroupIndex = cameraIndexForLength(
      ref.read(cameraGroupIndexProvider),
      groupIds.length,
    );
    pageController = PageController(
      viewportFraction: CameraGroupSelector.itemViewportFraction,
      initialPage: initialGroupIndex ?? 0,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_discoverCameras());
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
      appBar: _pinPhotoAppBar(),
      body: SafeArea(child: Center(child: child)),
    );
  }

  PreferredSizeWidget? _pinPhotoAppBar() => widget.pinPhotoMode
      ? AppBar(
          title: const Text('Take pin photo'),
          actions: [
            IconButton(
              tooltip: 'Choose from gallery',
              onPressed: choosePinPhotoFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
            ),
          ],
        )
      : null;

  @override
  void dispose() {
    if (!widget.pinPhotoMode) _capturingNotifier.setCapturing(false);
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
      if (kIsWeb) return;
      ref
          .read(cameraControllerProvider)
          .value
          ?.setFlashMode(next ? FlashMode.off : FlashMode.auto);
    });
    final cameras = ref.watch(
      globalDataServiceProvider.select((t) => t.cameras),
    );
    final cameraFlashMode = ref.watch(cameraTorchProvider);
    final groupIds = widget.pinPhotoMode
        ? <String>[]
        : ref.watch(groupOrderServiceProvider);
    preloadGroupProfileProgressions(
      groupIds,
      (id) => ref.read(groupAvatarProgressionProvider(id).future),
    );
    if (cameras.isEmpty) {
      return Scaffold(
        appBar: _pinPhotoAppBar(),
        body: const SafeArea(
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
      appBar: _pinPhotoAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        // We handle the AsyncValue of the CONTROLLER here
                        child: controllerAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not start the camera. Check camera access and close other camera apps.',
                                ),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(cameraControllerProvider),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                          data: (controller) {
                            // Once controller is ready, we check the Values state
                            return cameraStateAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (err, stack) => Text(err.toString()),
                              data: (cameraState) => GestureDetector(
                                onDoubleTap: ref
                                    .read(cameraIndexProvider.notifier)
                                    .increment,
                                onScaleStart: (_) =>
                                    basScaleFactor = scaleFactor,
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
                          child:
                              (widget.pinPhotoMode
                                  ? _pinCapturing
                                  : ref.watch(cameraCapturingProvider))
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
                                        onPressed: kIsWeb
                                            ? null
                                            : () => handleFlashChange(
                                                !cameraFlashMode,
                                              ),
                                        icon: cameraFlashMode
                                            ? const Icon(Icons.flash_off)
                                            : const Icon(Icons.flash_auto),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const controlSpacing = 8.0;
                            const controlBottomPadding = 12.0;
                            const controlButtonHeight = 48.0;
                            final maxMenuHeight =
                                (constraints.maxHeight -
                                        controlBottomPadding -
                                        (controlButtonHeight * 2) -
                                        controlSpacing)
                                    .clamp(0.0, 240.0);
                            return Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 12,
                                  bottom: controlBottomPadding,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomRight,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      CameraSelectorButton(
                                        cameras: cameras,
                                        selectedIndex: cameraIndex,
                                        onSelected: handleCameraChange,
                                        maxMenuHeight: maxMenuHeight,
                                      ),
                                      const SizedBox(height: controlSpacing),
                                      if (!widget.pinPhotoMode)
                                        Material(
                                          color: Colors.grey.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: const CircleBorder(),
                                          child: IconButton(
                                            tooltip: 'Upload photo',
                                            onPressed: uploadFileImage,
                                            icon: const Icon(Icons.upload),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.pinPhotoMode)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: IconButton.filled(
                              tooltip: 'Take photo',
                              iconSize: 36,
                              onPressed:
                                  controllerAsync.value?.value.isInitialized ==
                                      true
                                  ? capturePinPhoto
                                  : null,
                              icon: const Icon(Icons.camera_alt),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (groupIds.isNotEmpty)
                  CameraGroupSelector(
                    controller: pageController,
                    selectedIndex: ref.watch(cameraGroupIndexProvider),
                    onPageChanged: onPageChange,
                    onCapture: (index) => takePicture(groupIds[index], index),
                    children: List.generate(
                      groupIds.length,
                      (index) => groupCard(groupIds[index]),
                    ),
                  ),
                const SizedBox(height: 5),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget groupCard(String groupId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SmallProfilePicture.group(
          groupId: groupId,
          radius: cameraGroupAvatarSize(MediaQuery.sizeOf(context).height) - 3,
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
    final controller = ref.read(cameraControllerProvider).value;
    if (_m.isLocked || controller == null || !controller.value.isInitialized) {
      return;
    }
    await _m.acquire();
    _capturingNotifier.setCapturing(true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      await _handleImage(image, fromGallery: false);
    } catch (e) {
      if (kDebugMode) print(e);
    } finally {
      _m.release();
      if (mounted) {
        _capturingNotifier.setCapturing(false);
      }
    }
  }

  Future<void> capturePinPhoto() async {
    final controller = ref.read(cameraControllerProvider).value;
    if (_m.isLocked || controller == null || !controller.value.isInitialized) {
      return;
    }
    await _m.acquire();
    setState(() => _pinCapturing = true);
    try {
      final image = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(image);
    } catch (error) {
      if (mounted) {
        CustomErrorSnackBar.message(
          message: 'Could not take photo. Try again.',
        );
      }
      debugPrint('Could not take pin photo: $error');
    } finally {
      _m.release();
      if (mounted) setState(() => _pinCapturing = false);
    }
  }

  Future<void> choosePinPhotoFromGallery() async {
    final pickedFile = await CustomImagePicker.pick(context: context);
    if (pickedFile != null && mounted) {
      Navigator.of(context).pop(pickedFile);
    }
  }

  Future<void> _handleImage(XFile file, {required bool fromGallery}) async {
    final controller = ref.read(cameraControllerProvider).value;
    var openedReview = false;
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
      // Browser history can remove a pushed route without completing its
      // Future. End capture when review opens; didChangeDependencies resumes
      // the preview when the camera route becomes current again.
      if (coords != null && !fromGallery) {
        unawaited(
          context.pushNamed<void>(
            'imageUpload',
            queryParameters: {
              "lat": coords.latitude.toString(),
              "long": coords.longitude.toString(),
            },
            extra: croppedImage,
          ),
        );
      } else {
        unawaited(
          context.pushNamed<void>(
            'selectLocation',
            queryParameters: coords != null
                ? {
                    "lat": coords.latitude.toString(),
                    "long": coords.longitude.toString(),
                  }
                : {},
            extra: croppedImage,
          ),
        );
      }
      openedReview = true;
    } catch (e) {
      CustomErrorSnackBar.message(message: "Could not load or crop image");
      debugPrint(e.toString());
    } finally {
      if (!openedReview &&
          mounted &&
          controller != null &&
          controller.value.isInitialized) {
        await controller.resumePreview().catchError((_) {});
      }
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
          final frameSize = cameraPreviewFrameSize(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          if (frameSize == Size.zero) return const SizedBox.shrink();
          // Browser video is already upright. Keep its orientation and crop
          // both platforms to the same centered 3:4 frame used on capture.
          final sourceAspectRatio = useWebPreview
              ? previewSize!.width / previewSize.height
              : cameraPreviewAspectRatio(
                  sensorAspectRatio: value.aspectRatio,
                  orientation: value.deviceOrientation,
                );
          // The browser video already uses object-fit: cover. Keep its
          // platform view at the visible frame's actual size instead of
          // scaling the HTML view with a FittedBox.
          final preview = useWebPreview
              ? KeyedSubtree(
                  key: const ValueKey('camera-platform-preview'),
                  child: controller.buildPreview(),
                )
              : FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: sourceAspectRatio,
                    height: 1,
                    child: CameraPreview(controller),
                  ),
                );

          return Center(
            child: SizedBox.fromSize(
              key: const ValueKey('camera-preview-frame'),
              size: frameSize,
              child: ClipRect(child: preview),
            ),
          );
        },
      );
    },
  );
}
