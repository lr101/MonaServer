import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_switchable_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('decodes feed images at their physical display width', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(kTransparentImage);
    final pin = PinEntity(
      pinId: 'pin-1',
      latitude: 0,
      longitude: 0,
      creationDate: DateTime(2026),
      creator: 'user-1',
      groupId: 'group-1',
      ttl: DateTime(2026),
      onlySession: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Center(
              child: SizedBox.square(
                dimension: 100,
                child: FeedSwitchableImage(
                  item: pin,
                  image: bytes,
                  likeImage: _ignoreTap,
                  onTab: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
    final provider = image.image as ResizeImage;

    expect(provider.width, 300);
    expect((provider.imageProvider as MemoryImage).bytes, same(bytes));
  });
}

void _ignoreTap() {}
