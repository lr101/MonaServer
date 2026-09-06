import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

// ignore: avoid_classes_with_only_static_members
class CustomImagePicker {
  static Future<XFile?> pick({required BuildContext context}) async {
    try {
      final picker = ImagePicker();
      XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
      );
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.file != null) {
        pickedFile = response.file;
      }
      return pickedFile;
    } catch (e) {
      CustomErrorSnackBar.message(message: e.toString());
    }
    return null;
  }

  /// opens the input picker for selecting an image from the gallery
  /// after selecting an image it is opened in an image cropper
  /// check if 100 < width, height and image is square
  static Future<Uint8List?> pickAndCrop({
    required int minHeight,
    required int minWidth,
    required BuildContext context,
    CropAspectRatio? initAspectRatio,
  }) async {
    try {
      final XFile? res = await CustomImagePicker.pick(context: context);
      if (!context.mounted) return null;
      return await crop(
        res: res,
        minHeight: minHeight,
        minWidth: minWidth,
        context: context,
        initAspectRatio: initAspectRatio,
      );
    } catch (e) {
      CustomErrorSnackBar.message(message: e.toString());
    }
    return null;
  }

  /// crops the image programmatically to a 3:4 aspect ratio
  static Future<Uint8List?> autoCrop({required XFile? res}) async {
    if (res == null) return null;
    final Uint8List bytes = await res.readAsBytes();
    return compute(_normalizePinImage, bytes);
  }

  /// opens the input picker for selecting an image from the gallery
  /// after selecting an image it is opened in an image cropper
  /// check if 100 < width, height and image is square
  static Future<Uint8List?> crop({
    required XFile? res,
    required int minHeight,
    required int minWidth,
    required BuildContext context,
    CropAspectRatio? initAspectRatio,
  }) async {
    if (res != null && context.mounted) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: res.path,
        aspectRatio:
            initAspectRatio ?? const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarWidgetColor: Colors.white,
            toolbarColor: Theme.of(context).primaryColor,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Cropper',
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
          ),
          WebUiSettings(
            context: context,
            dragMode: WebDragMode.move,
            scalable: false,
            viewwMode: WebViewMode.mode_1,
          ),
        ],
      );
      if (croppedFile == null) return null;
      final Uint8List image = await croppedFile.readAsBytes();
      final dimensions = await decodeImageFromList(image);
      if (dimensions.width < minHeight && dimensions.height < minHeight) {
        return null;
      }
      return image;
    }
    return null;
  }
}

Uint8List? _normalizePinImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final image = img.bakeOrientation(decoded);

  const targetWidth = 720;
  const targetHeight = 960;
  const targetRatio = targetWidth / targetHeight;
  final currentRatio = image.width / image.height;

  late final int cropWidth;
  late final int cropHeight;
  late final int offsetX;
  late final int offsetY;
  if (currentRatio > targetRatio) {
    cropWidth = (image.height * targetRatio).round();
    cropHeight = image.height;
    offsetX = (image.width - cropWidth) ~/ 2;
    offsetY = 0;
  } else {
    cropWidth = image.width;
    cropHeight = (image.width / targetRatio).round();
    offsetX = 0;
    offsetY = (image.height - cropHeight) ~/ 2;
  }

  var normalized = img.copyCrop(
    image,
    x: offsetX,
    y: offsetY,
    width: cropWidth,
    height: cropHeight,
  );
  if (normalized.width != targetWidth || normalized.height != targetHeight) {
    normalized = img.copyResize(
      normalized,
      width: targetWidth,
      height: targetHeight,
    );
  }

  return Uint8List.fromList(img.encodeJpg(normalized, quality: 80));
}
