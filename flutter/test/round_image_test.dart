import 'dart:typed_data';

import 'package:buff_lisa/widgets/round_image/presentation/round_cached_image.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

// AsyncValue.copyWithPrevious is internal in Riverpod but is the state shape
// produced during a seamless provider refresh.
// ignore_for_file: invalid_use_of_internal_member

void main() {
  testWidgets('decodes cached round images at their physical display width', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(kTransparentImage);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: RoundCachedImage(image: bytes, size: 20),
        ),
      ),
    );

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
    final provider = image.image as ResizeImage;

    expect(provider.width, 120);
    expect((provider.imageProvider as MemoryImage).bytes, same(bytes));
  });

  testWidgets('decodes sized images at their physical display width', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3]);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: RoundImage(size: 20, imageCallback: AsyncData(bytes)),
        ),
      ),
    );

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
    final provider = image.image as ResizeImage;

    expect(provider.width, 120);
    expect((provider.imageProvider as MemoryImage).bytes, same(bytes));
  });

  testWidgets('keeps the previous image visible while loading', (tester) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final loadingWithPrevious = const AsyncLoading<Uint8List?>()
        .copyWithPrevious(AsyncData(bytes), isRefresh: false);

    await tester.pumpWidget(
      MaterialApp(home: RoundImage(imageCallback: loadingWithPrevious)),
    );

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));

    expect((image.image as MemoryImage).bytes, same(bytes));
  });
}
