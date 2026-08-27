
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
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
import 'package:latlong2/latlong.dart';
import 'package:mutex/mutex.dart';
import 'package:native_exif/native_exif.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';

class Camera extends ConsumerStatefulWidget {
  const Camera({super.key});

  @override
  ConsumerState<Camera> createState() => _CameraState();
}

class _CameraState extends ConsumerState<Camera>  with WidgetsBindingObserver {

  final PageController pageController = PageController(viewportFraction: 0.3);
  double scaleFactor = 1.0;
  double basScaleFactor = 1.0;
  final _m = Mutex();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (route?.isCurrent ?? false) {
      final controller = ref.read(cameraControllerProvider).value;
      if (controller != null && controller.value.isInitialized) {
        controller.resumePreview();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraTorchProvider, (_, next) {
      ref.read(cameraControllerProvider).value?.setFlashMode(next ? FlashMode.off : FlashMode.auto);
    });
    final controllerAsync = ref.watch(cameraControllerProvider);
    final cameraStateAsync = ref.watch(cameraValuesProvider);
    final cameraIndex = ref.watch(cameraIndexProvider);
    final cameras = ref.watch(globalDataServiceProvider.select((t) => t.cameras));
    final cameraFlashMode = ref.watch(cameraTorchProvider);
    final groupIds = ref.watch(groupOrderServiceProvider);
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
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text("Camera Error: $err")),
                      data: (controller) {
                        // Once controller is ready, we check the Values state
                        return cameraStateAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Text(err.toString()),
                          data: (cameraState) => GestureDetector(
                            onDoubleTap: ref.read(cameraIndexProvider.notifier).increment,
                            onScaleStart: (_) => basScaleFactor = scaleFactor,
                            onScaleUpdate: (details) => handleZoom(details, controller, cameraState),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Center(
                                  child: AspectRatio(
                                    aspectRatio: controller.value.aspectRatio,
                                    child: CameraPreview(controller),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Align(
                  alignment: FractionalOffset.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 75),
                    child: ref.watch(cameraCapturingProvider) ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).highlightColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Padding(padding: EdgeInsets.all(5),
                      child:  Text("Hold steady capturing ...") ,
                      ),
                    ) : const SizedBox.shrink(),
                ),),
                Align(
                    alignment: FractionalOffset.bottomCenter,
                    child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: SizedBox(
                          height: 50,
                          child:  Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                    padding: const EdgeInsets.all(2.5),
                                    child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.grey.withValues(alpha: 0.5),
                                        child: Center(child: IconButton(
                                            onPressed: () => handleFlashChange(!cameraFlashMode),
                                            icon: cameraFlashMode ? const Icon(Icons.flash_off) : const Icon(Icons.flash_auto),
                                        ),),
                                    ),),
                              ListView.builder(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: cameras.length,
                                  itemBuilder: (context, index) => Padding(
                                      padding: const EdgeInsets.all(2.5),
                                      child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: cameraIndex == index ? Colors.grey.withValues(alpha: 0.8) : Colors.grey.withValues(alpha: 0.5),
                                          child: Center(child: IconButton(
                                              onPressed: () => handleCameraChange(index),
                                              icon: cameras[index].lensDirection == CameraLensDirection.back ? const Icon(Icons.landscape) : const Icon(Icons.person),
                                          ),),
                                      ),),
                              ),
                              Padding(
                                  padding: const EdgeInsets.all(2.5),
                                  child:CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey.withValues(alpha: 0.5),
                                      child: Center(
                                          child: GestureDetector(
                                             onTap: uploadFileImage,
                                             child: const Icon(Icons.upload),
                                             ),),
                                  ),
                              ),
                            ],
                          ),
                        ),),
                ),
              ],
            ),
          ),
          SizedBox(
            height: (MediaQuery.of(context).size.height) * 0.15,
            child: Stack(
              children: [
                Center(
                  child: SnappingPageScroll(
                    controller: pageController,
                    onPageChanged: onPageChange,
                    children: List.generate(groupIds.length, (index) => groupCard(groupIds[index], index)),
                    ),
                  ),
                Center(child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                          width: 5.0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      shape: BoxShape.circle,
                    ),
                    height: (MediaQuery.of(context).size.height) * 0.07 * 2,
                  ),
                ),),
              ],
            ),
          ),
          const SizedBox(height: 5,),
        ],
      ),
    ),
    );
  }

  Future<void> handleZoom(ScaleUpdateDetails scale, CameraController controller, CameraState state) async {
    if (scale.scale * basScaleFactor <= state.maxZoom && scale.scale * basScaleFactor >= state.minZoom) {
      scaleFactor = basScaleFactor * scale.scale;
      await controller.setZoomLevel(scaleFactor);
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
    return Center(child: Padding(
        padding: const EdgeInsets.all(5),
        child: GestureDetector(
            onTap: () => takePicture(groupId, index),
            child:  RoundImage(
              size: (MediaQuery.of(context).size.height) * 0.06,
              imageCallback: ref.watch(groupProfilePictureByIdProvider(groupId)),
              child: Container(),
            ),
        ),),
    );
  }

  Future<void> takePicture(String groupId, int index) async {
    final indexProvider = ref.read(cameraGroupIndexProvider);
    if(index != indexProvider) {
      pageController.animateToPage(index, duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
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
    final controller = ref.read(cameraControllerProvider).value;
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
        context.pushNamed('imageUpload', queryParameters: {"lat": coords.latitude.toString(), "long": coords.longitude.toString()}, extra: croppedImage);
      } else {
        context.pushNamed('selectLocation', 
          queryParameters: coords != null ? {"lat": coords.latitude.toString(), "long": coords.longitude.toString()} : {}, 
          extra: croppedImage);
      }
    } catch (e) {
      CustomErrorSnackBar.message(message: "Could not load or crop image");
      debugPrint(e.toString());
    }
  }

}
