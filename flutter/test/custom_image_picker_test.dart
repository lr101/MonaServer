import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late ImageCropperPlatform originalPlatform;
  late _RecordingImageCropper platform;

  setUp(() {
    originalPlatform = ImageCropperPlatform.instance;
    platform = _RecordingImageCropper();
    ImageCropperPlatform.instance = platform;
  });

  tearDown(() {
    ImageCropperPlatform.instance = originalPlatform;
  });

  testWidgets('uses a page cropper on a portrait phone viewport', (
    tester,
  ) async {
    final context = await _pumpContext(tester, const Size(393, 820));

    await CustomImagePicker.crop(
      res: XFile('/tmp/group-image.jpg'),
      minHeight: 100,
      minWidth: 100,
      context: context,
    );

    final webSettings = platform.settings!.whereType<WebUiSettings>().single;
    expect(webSettings.presentStyle, WebPresentStyle.page);
  });

  testWidgets('keeps a dialog cropper on a wide desktop viewport', (
    tester,
  ) async {
    final context = await _pumpContext(tester, const Size(1280, 900));

    await CustomImagePicker.crop(
      res: XFile('/tmp/group-image.jpg'),
      minHeight: 100,
      minWidth: 100,
      context: context,
    );

    final webSettings = platform.settings!.whereType<WebUiSettings>().single;
    expect(webSettings.presentStyle, WebPresentStyle.dialog);
  });
}

Future<BuildContext> _pumpContext(WidgetTester tester, Size size) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return context;
}

class _RecordingImageCropper extends ImageCropperPlatform {
  List<PlatformUiSettings>? settings;

  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    settings = uiSettings;
    return null;
  }
}
