@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/remote_image/remote_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:transparent_image/transparent_image.dart';

import '../support/pin_image_test_cache.dart';

void main() {
  testWidgets('web feed photos decode within their physical display width', (
    tester,
  ) async {
    final cache = PinImageTestCache()..install();
    addTearDown(cache.dispose);
    final source = img.Image(width: 1800, height: 2400);
    img.fill(source, color: img.ColorRgb8(0x12, 0x34, 0x56));
    final bytes = Uint8List.fromList(img.encodePng(source));
    final url = 'data:image/png;base64,${base64Encode(bytes)}';
    final thumbnailUrl =
        'data:image/png;base64,${base64Encode(kTransparentImage)}';
    cache.bytes[url] = bytes;
    cache.bytes[thumbnailUrl] = Uint8List.fromList(kTransparentImage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
        ],
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: RemoteImage(
                image: RemoteImageReference(
                  kind: RemoteImageKind.pin,
                  id: 'large',
                  photoId: 'photo',
                  thumbnailUrl: thumbnailUrl,
                  imageUrl: url,
                ),
                policy: RemoteImagePolicy.previewThenFull,
              ),
            ),
          ),
        ),
      ),
    );
    await pumpImageLoads(tester);
    await tester.pump(const Duration(seconds: 1));
    final frames = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((raw) => raw.image != null)
        .toList();
    expect(frames, isNotEmpty);
    final image = frames.last.image!;
    final targetWidth = (200 * tester.view.devicePixelRatio).ceil();
    final targetHeight = (300 * tester.view.devicePixelRatio).ceil();
    expect(
      image.width,
      greaterThan(1),
      reason: 'The full photo must replace the tiny preview',
    );
    expect(image.width, lessThanOrEqualTo(targetWidth));
    expect(image.height, lessThanOrEqualTo(targetHeight));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });
}
