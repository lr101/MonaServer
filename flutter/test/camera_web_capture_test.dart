import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class _ImagePickerPlatform extends ImagePickerPlatform {
  ImageSource? requestedSource;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    requestedSource = source;
    return null;
  }

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

void main() {
  testWidgets('web camera capture asks the browser for a camera image', (
    tester,
  ) async {
    final originalPlatform = ImagePickerPlatform.instance;
    final platform = _ImagePickerPlatform();
    ImagePickerPlatform.instance = platform;
    addTearDown(() => ImagePickerPlatform.instance = originalPlatform);

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await pickCameraImage(context: context);

    expect(platform.requestedSource, ImageSource.camera);
  });
}
