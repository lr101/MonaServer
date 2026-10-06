import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('shows one photo at a time and swipes to the next update', (
    tester,
  ) async {
    var selectedIndex = -1;
    final updateBytes = Uint8List.fromList(kTransparentImage);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinPhotoProgressiveImageBytesProvider((
            photoId: 'update',
            thumbnailUrl: null,
            imageUrl: 'https://example.test/update.png',
          )).overrideWith((ref) => Stream<Uint8List?>.value(updateBytes)),
          pinPhotoThumbnailBytesProvider((
            photoId: 'update',
            thumbnailUrl: null,
            imageUrl: 'https://example.test/update.png',
          )).overrideWith((ref) => Stream<Uint8List?>.value(updateBytes)),
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
    expect(find.text('Photos & updates'), findsOneWidget);
    expect(find.byTooltip('Show Update 1'), findsOneWidget);
    expect(find.text('Still here today'), findsNothing);
    expect(
      tester.getSize(find.byType(PageView)).height,
      closeTo(tester.getSize(find.byType(PageView)).width * 4 / 3, 0.1),
    );
    final originalImage = tester.widget<Image>(
      find
          .descendant(of: find.byType(PageView), matching: find.byType(Image))
          .last,
    );
    expect(originalImage.image, isA<ResizeImage>());

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Update 1'), findsOneWidget);
    expect(selectedIndex, 1);
    final updateImage = tester.widget<Image>(
      find
          .descendant(of: find.byType(PageView), matching: find.byType(Image))
          .last,
    );
    final updateProvider = updateImage.image as ResizeImage;
    expect(
      (updateProvider.imageProvider as MemoryImage).bytes,
      same(updateBytes),
    );
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
    expect(find.text('Photos & updates'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('opens the selected update after history arrives', (
    tester,
  ) async {
    List<PinPhotoDto> photos = [];
    Widget carousel() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: PinPhotoCarousel(
              initialPhotoId: 'update',
              photos: photos,
              originalImage: Uint8List.fromList(kTransparentImage),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(carousel());
    expect(find.text('1/1'), findsOneWidget);

    photos = [
      PinPhotoDto(
        id: 'update',
        pinId: 'pin',
        contributorUsername: 'walker',
        observedAt: DateTime.utc(2026, 2),
        isOriginal: false,
      ),
    ];
    await tester.pumpWidget(carousel());
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Update 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous photo'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    photos = List.of(photos);
    await tester.pumpWidget(carousel());
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Show Update 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show Update 1'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });
}
