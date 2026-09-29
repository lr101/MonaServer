import 'dart:async';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera_group_selector.dart';
import 'package:buff_lisa/features/camera/presentation/camera_selector.dart';
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
  const Camera({super.key, this.pinPhotoMode = false, this.isActive = true});

  /// Captures a photo for an existing pin and returns it to the calling page.
  final bool pinPhotoMode;
  final bool isActive;

  @override
  ConsumerState<Camera> createState() => _CameraState();
}

class _CameraState extends ConsumerState<Camera> with WidgetsBindingObserver {
  // Keep these dimensions aligned with the compact row and the web app shell.
  static const double _compactContentMaxWidth = 450;
  static const double _compactPreviewWidthFraction = .4;
  static const double _compactPreviewPanelGap = 12;

  late PageController pageController;
  double scaleFactor = 1.0;
  double basScaleFactor = 1.0;
  final _m = Mutex();
  late final ZoomUpdateCoalescer _zoomUpdates;
  late final CameraCapturing _capturingNotifier;
  bool _discoveringCameras = false;
  bool _discoveryInProgress = false;
  bool _hasDiscoveredCameras = false;
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
    if (widget.isActive) {
      _discoveringCameras = true;
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

  @override
  void didUpdateWidget(covariant Camera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive &&
        widget.isActive &&
        !_hasDiscoveredCameras &&
        !_discoveryInProgress) {
      _discoveryError = null;
      _discoveringCameras = true;
      unawaited(_discoverCameras());
    }
  }

  Future<void> _discoverCameras() async {
    if (_discoveryInProgress) return;
    _discoveryInProgress = true;
    try {
      await ref.read(globalDataServiceProvider.notifier).refreshCameraList();
      _hasDiscoveredCameras = true;
      _discoveryError = null;
    } catch (error) {
      _discoveryError = error;
    } finally {
      _discoveryInProgress = false;
      if (mounted) setState(() => _discoveringCameras = false);
    }
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

    final screenSize = MediaQuery.sizeOf(context);
    final compactContentWidth = screenSize.width < _compactContentMaxWidth
        ? screenSize.width
        : _compactContentMaxWidth;
    final compactCarouselWidth =
        compactContentWidth * (1 - _compactPreviewWidthFraction) -
        _compactPreviewPanelGap;
    final viewportFraction = screenSize.height < 500
        ? cameraGroupSelectorViewportFraction(compactCarouselWidth)
        : cameraGroupSelectorViewportFraction(screenSize.width);
    if (pageController.viewportFraction != viewportFraction) {
      final groupIds = ref.read(groupOrderServiceProvider);
      final selectedIndex = cameraIndexForLength(
        ref.read(cameraGroupIndexProvider),
        groupIds.length,
      );
      final oldController = pageController;
      pageController = PageController(
        viewportFraction: viewportFraction,
        initialPage: selectedIndex ?? 0,
      );
      oldController.dispose();
    }

    final route = ModalRoute.of(context);
    if (!_discoveringCameras &&
        widget.isActive &&
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
    if (!widget.isActive) return const SizedBox.shrink();
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
      final timedOut =
          error is CameraException && error.code == 'CameraAccessTimeout';
      return _cameraDiscoveryStatus(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timedOut
                  ? 'Camera access is taking too long. Check the browser permission prompt or settings, then retry.'
                  : denied
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
    final colorScheme = Theme.of(context).colorScheme;
    final groupIds = widget.pinPhotoMode
        ? <String>[]
        : ref.watch(groupOrderServiceProvider);
    final selectedGroupIndex =
        cameraIndexForLength(
          ref.watch(cameraGroupIndexProvider),
          groupIds.length,
        ) ??
        0;
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
    final compactLayout = MediaQuery.sizeOf(context).height < 500;
    final previewLayer = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colorScheme.surface),
        controllerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not start the camera. Check camera access and close other camera apps.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(cameraControllerProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (controller) => cameraStateAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text(err.toString(), textAlign: TextAlign.center),
            ),
            data: (cameraState) => GestureDetector(
              onDoubleTap: ref.read(cameraIndexProvider.notifier).increment,
              onScaleStart: (_) => basScaleFactor = scaleFactor,
              onScaleUpdate: (details) => handleZoom(details, cameraState),
              child: cameraPreviewViewport(controller),
            ),
          ),
        ),
        if (!widget.pinPhotoMode && ref.watch(cameraCapturingProvider))
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _capturingIndicator(context)),
          ),
      ],
    );
    final controlRail = _cameraControlRail(
      cameras: cameras,
      cameraIndex: cameraIndex,
      cameraFlashMode: cameraFlashMode,
      controllerReady: controllerAsync.value?.value.isInitialized == true,
      compact: compactLayout,
    );
    final groupSelector = groupIds.isEmpty
        ? null
        : CameraGroupSelector(
            controller: pageController,
            selectedIndex: selectedGroupIndex,
            onPageChanged: onPageChange,
            onCapture: (index) => takePicture(groupIds[index], index),
            children: List.generate(
              groupIds.length,
              (index) => groupCard(
                groupIds[index],
                selected: index == selectedGroupIndex,
              ),
            ),
          );
    return Scaffold(
      appBar: _pinPhotoAppBar(),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: compactLayout
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final previewWidth =
                      constraints.maxWidth * _compactPreviewWidthFraction;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: previewWidth, child: previewLayer),
                      const SizedBox(width: _compactPreviewPanelGap),
                      Expanded(
                        child: ColoredBox(
                          color: colorScheme.surface,
                          child: LayoutBuilder(
                            builder: (context, panelConstraints) =>
                                SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: panelConstraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          controlRail,
                                          if (groupSelector
                                              case final selector?)
                                            selector,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                children: [
                  Expanded(child: previewLayer),
                  const SizedBox(height: 12),
                  controlRail,
                  if (groupSelector case final selector?) selector,
                  const SizedBox(height: 5),
                ],
              ),
      ),
    );
  }

  Widget _cameraControlRail({
    required List<CameraDescription> cameras,
    required int cameraIndex,
    required bool cameraFlashMode,
    required bool controllerReady,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPinPhotoMode = widget.pinPhotoMode;
    final railHeight = isPinPhotoMode
        ? (compact ? 88.0 : 92.0)
        : (compact ? 60.0 : 64.0);
    final maxMenuHeight = (MediaQuery.sizeOf(context).height - 300).clamp(
      0.0,
      240.0,
    );

    return Container(
      height: railHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: .18),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? (isPinPhotoMode ? 1 : 8) : 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CameraGroupSelector.maxCarouselWidth,
          ),
          child: Row(
            children: [
              _cameraControlButton(
                tooltip: kIsWeb
                    ? 'Flash is unavailable in the browser'
                    : cameraFlashMode
                    ? 'Turn flash off'
                    : 'Set flash to auto',
                icon: cameraFlashMode ? Icons.flash_off : Icons.flash_auto,
                onPressed: kIsWeb
                    ? null
                    : () => handleFlashChange(!cameraFlashMode),
              ),
              const Spacer(),
              if (isPinPhotoMode)
                _pinPhotoShutterButton(
                  enabled: controllerReady && !_pinCapturing,
                ),
              const Spacer(),
              CameraSelectorButton(
                cameras: cameras,
                selectedIndex: cameraIndex,
                onSelected: handleCameraChange,
                maxMenuHeight: maxMenuHeight,
                preferDialog: true,
              ),
              if (!isPinPhotoMode) ...[
                const SizedBox(width: 8),
                _cameraControlButton(
                  tooltip: 'Choose from gallery',
                  icon: Icons.photo_library_outlined,
                  onPressed: uploadFileImage,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraControlButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        backgroundColor: Colors.transparent,
        iconSize: 18,
        minimumSize: const Size.square(44),
        fixedSize: const Size.square(44),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      icon: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: CircleBorder(
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
        child: SizedBox.square(dimension: 30, child: Icon(icon, size: 18)),
      ),
    );
  }

  Widget _pinPhotoShutterButton({required bool enabled}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: Tooltip(
        message: 'Take photo',
        child: Material(
          color: colorScheme.surfaceContainerHighest,
          shape: CircleBorder(
            side: BorderSide(color: colorScheme.onSurface, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? capturePinPhoto : null,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 80,
              child: Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.primary,
                    shape: const CircleBorder(),
                  ),
                  child: SizedBox.square(
                    dimension: 60,
                    child: Center(
                      child: _pinCapturing
                          ? SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 30,
                              color: colorScheme.onPrimary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _capturingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 2,
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Preparing photo…',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
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

  Widget groupCard(String groupId, {required bool selected}) {
    final radius = selected
        ? CameraGroupSelector.shutterImageSize / 2 - 3
        : cameraGroupAvatarSize(MediaQuery.sizeOf(context).height) - 3;
    final image = SmallProfilePicture.group(groupId: groupId, radius: radius);

    if (selected) {
      return Center(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: CameraGroupSelector.shutterImageSize,
          minHeight: 0,
          maxHeight: CameraGroupSelector.shutterImageSize,
          child: SizedBox.square(
            dimension: CameraGroupSelector.shutterImageSize,
            child: image,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AspectRatio(aspectRatio: 1, child: image),
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
            child: Container(
              key: const ValueKey('camera-preview-frame'),
              width: frameSize.width,
              height: frameSize.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: .45),
                ),
              ),
              child: preview,
            ),
          );
        },
      );
    },
  );
}
