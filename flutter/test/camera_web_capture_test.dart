import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

// Like the web plugin, this picker does not implement getLostData.
class _ImagePickerPlatform extends ImagePickerPlatform {
  _ImagePickerPlatform(this.image);

  final XFile? image;
  ImageSource? requestedSource;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    requestedSource = source;
    return image;
  }
}

class _AndroidImagePickerPlatform extends _ImagePickerPlatform {
  _AndroidImagePickerPlatform(this.recoveredImage) : super(null);

  final XFile recoveredImage;

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse(
    file: recoveredImage,
    files: [recoveredImage],
    type: RetrieveType.image,
  );
}

void main() {
  Future<BuildContext> mountPicker(
    WidgetTester tester,
    ImagePickerPlatform platform,
  ) async {
    final originalPlatform = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = platform;
    addTearDown(() {
      ImagePickerPlatform.instance = originalPlatform;
      debugDefaultTargetPlatformOverride = null;
    });

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const Scaffold();
          },
        ),
      ),
    );
    return context;
  }

  for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('camera preserves the selected image on $target', (
      tester,
    ) async {
      // Android here also covers Android browsers when run with --platform chrome.
      debugDefaultTargetPlatformOverride = target;
      final image = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'photo.jpg',
      );
      final platform = _ImagePickerPlatform(image);
      final context = await mountPicker(tester, platform);

      final result = await pickCameraImage(context: context);
      debugDefaultTargetPlatformOverride = null;

      expect(result, same(image));
      expect(platform.requestedSource, ImageSource.camera);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }, skip: !kIsWeb && target == TargetPlatform.android);

    testWidgets('camera cancellation is silent on $target', (tester) async {
      debugDefaultTargetPlatformOverride = target;
      final context = await mountPicker(tester, _ImagePickerPlatform(null));

      final result = await pickCameraImage(context: context);
      debugDefaultTargetPlatformOverride = null;
      expect(result, isNull);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }, skip: !kIsWeb && target == TargetPlatform.android);
  }

  testWidgets('native Android still recovers a lost image', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final recovered = XFile.fromData(
      Uint8List.fromList([4, 5, 6]),
      name: 'lost.jpg',
    );
    final context = await mountPicker(
      tester,
      _AndroidImagePickerPlatform(recovered),
    );

    final result = await pickCameraImage(context: context);
    debugDefaultTargetPlatformOverride = null;
    expect(result, same(recovered));
  }, skip: kIsWeb);
}
