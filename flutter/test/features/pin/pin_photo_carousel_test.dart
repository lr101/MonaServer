import 'dart:typed_data';

import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('original photo upgrades from thumbnail to full image', (
    tester,
  ) async {
    final thumbnailBytes = Uint8List.fromList(kTransparentImage);
    final fullImageBytes = Uint8List.fromList(kTransparentImage);

    Widget buildCarousel({Uint8List? originalImage}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: PinPhotoCarousel(
            originalImage: originalImage,
            thumbnailImage: thumbnailBytes,
            photos: const [],
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildCarousel());
    expect(_displayedImageBytes(tester), same(thumbnailBytes));

    await tester.pumpWidget(buildCarousel(originalImage: fullImageBytes));
    expect(_displayedImageBytes(tester), same(fullImageBytes));
  });

  testWidgets('shows unavailable when an update has no image bytes', (
    tester,
  ) async {
    const photo = (
      photoId: 'update',
      thumbnailUrl: null,
      imageUrl: 'https://example.test/update.png',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinPhotoProgressiveImageBytesProvider(photo)
              .overrideWith((ref) => Stream<Uint8List?>.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PinPhotoCarousel(
                originalImage: Uint8List.fromList(kTransparentImage),
                photos: [
                  PinPhotoDto(
                    id: 'original',
                    pinId: 'pin',
                    contributorUsername: 'maker',
                    observedAt: DateTime.utc(2026),
                    isOriginal: true,
                  ),
                  PinPhotoDto(
                    id: 'update',
                    pinId: 'pin',
                    contributorUsername: 'walker',
                    image: photo.imageUrl,
                    observedAt: DateTime.utc(2026, 2),
                    isOriginal: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('shows one photo at a time and swipes to the next update', (
    tester,
  ) async {
    var selectedIndex = -1;
    final updateImageBytes = Uint8List.fromList(kTransparentImage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinPhotoProgressiveImageBytesProvider((
            photoId: 'update',
            thumbnailUrl: null,
            imageUrl: 'https://example.test/update.png',
          )).overrideWith((ref) => Stream<Uint8List?>.value(updateImageBytes)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: PinPhotoCarousel(
                    originalImage: Uint8List.fromList(kTransparentImage),
                    onPageChanged: (index) => selectedIndex = index,
                    photos: [
                      PinPhotoDto(
                        id: 'original',
                        pinId: 'pin',
                        contributorUsername: 'maker',
                        observedAt: DateTime.utc(2026),
                        isOriginal: true,
                      ),
                      PinPhotoDto(
                        id: 'update',
                        pinId: 'pin',
                        contributorUsername: 'walker',
                        image: 'https://example.test/update.png',
                        caption: 'Still here today',
                        observedAt: DateTime.utc(2026, 2),
                        isOriginal: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('UPDATE'), findsNothing);
    expect(find.text('Still here today'), findsNothing);
    expect(
      tester.getSize(find.byType(PageView)).height,
      closeTo(tester.getSize(find.byType(PageView)).width * 4 / 3, 0.1),
    );
    final originalImage = tester.widget<Image>(find.byType(Image));
    expect(originalImage.image, isA<ResizeImage>());

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(find.text('UPDATE'), findsOneWidget);
    expect(selectedIndex, 1);
    final updateImage = tester.widget<Image>(find.byType(Image));
    expect(updateImage.image, isA<ResizeImage>());
  });

  testWidgets('shows one original photo when history has no updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 320, child: PinPhotoCarousel(photos: [])),
          ),
        ),
      ),
    );

    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}

Uint8List _displayedImageBytes(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  final resized = image.image as ResizeImage;
  return (resized.imageProvider as MemoryImage).bytes;
}
