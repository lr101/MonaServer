import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

// ignore: avoid_classes_with_only_static_members
class CustomImagePicker {

  static Future<XFile?> pick({required BuildContext context}) async {


    try {
      final picker = ImagePicker();
      XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
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
  static Future<Uint8List?> pickAndCrop({required int minHeight, required int minWidth,required BuildContext context, CropAspectRatio? initAspectRatio}) async {
    try {
      final XFile? res =  await CustomImagePicker.pick(context: context);
      if (!context.mounted) return null;
      return await crop(res: res, minHeight: minHeight, minWidth: minWidth, context: context, initAspectRatio: initAspectRatio);
    } catch (e) {
      CustomErrorSnackBar.message(message: e.toString());
    }
    return null;
  }

  /// crops the image programmatically to a 3:4 aspect ratio
  static Future<Uint8List?> autoCrop({
    required XFile? res,
  }) async {
    if (res == null) return null;
    final Uint8List bytes = await res.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    // Target aspect ratio 3:4 (width/height = 0.75)
    const double targetRatio = 3 / 4;
    final double currentRatio = image.width / image.height;

    int newWidth;
    int newHeight;
    int offsetX;
    int offsetY;

    if (currentRatio > targetRatio) {
      // Image is too wide, crop the sides
      newWidth = (image.height * targetRatio).toInt();
      newHeight = image.height;
      offsetX = (image.width - newWidth) ~/ 2;
      offsetY = 0;
    } else {
      // Image is too tall, crop the top and bottom
      newWidth = image.width;
      newHeight = (image.width / targetRatio).toInt();
      offsetX = 0;
      offsetY = (image.height - newHeight) ~/ 2;
    }

    final img.Image cropped = img.copyCrop(image, x: offsetX, y: offsetY, width: newWidth, height: newHeight);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 80));
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
          aspectRatio: initAspectRatio ?? const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Cropper',
              toolbarWidgetColor: Colors.white,
              toolbarColor: Theme.of(context).primaryColor,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Cropper',
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
              resetAspectRatioEnabled: false,
            ),
            WebUiSettings(
              context: context,
              dragMode: WebDragMode.move,
              scalable: false,
              viewwMode: WebViewMode.mode_1
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
