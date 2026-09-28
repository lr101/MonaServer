import 'dart:typed_data';

import 'package:buff_lisa/features/pin/presentation/pin_photo_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('shows one photo at a time and swipes to the next update', (
    tester,
  ) async {
    var selectedIndex = -1;
    await tester.pumpWidget(
      MaterialApp(
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
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('Still here today'), findsNothing);
    expect(
      tester.getSize(find.byType(PageView)).height,
      closeTo(tester.getSize(find.byType(PageView)).width * 4 / 3, 0.1),
    );
    final originalImage = tester.widget<Image>(find.byType(Image));
    expect(originalImage.image, isA<ResizeImage>());

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(selectedIndex, 1);
    final updateImage = tester.widget<Image>(find.byType(Image));
    expect(updateImage.image, isA<NetworkImage>());
    expect(
      (updateImage.image as NetworkImage).url,
      'https://example.test/update.png',
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
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
