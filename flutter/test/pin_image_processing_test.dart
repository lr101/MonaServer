import 'dart:io';

import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  test('auto crop normalizes oversized pin photos to 720 by 960', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pin-image-processing-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = img.Image(width: 1200, height: 1200);
    final file = File('${directory.path}/source.jpg');
    await file.writeAsBytes(img.encodeJpg(source));

    final encoded = await CustomImagePicker.autoCrop(res: XFile(file.path));
    final normalized = img.decodeJpg(encoded!);

    expect(normalized, isNotNull);
    expect(normalized!.width, 720);
    expect(normalized.height, 960);
  });

  test('auto crop normalizes smaller pin photos to 720 by 960', () async {
    final directory = await Directory.systemTemp.createTemp(
      'small-pin-image-processing-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = img.Image(width: 600, height: 800);
    final file = File('${directory.path}/source.jpg');
    await file.writeAsBytes(img.encodeJpg(source));

    final encoded = await CustomImagePicker.autoCrop(res: XFile(file.path));
    final normalized = img.decodeJpg(encoded!);

    expect(normalized, isNotNull);
    expect(normalized!.width, 720);
    expect(normalized.height, 960);
  });
}
