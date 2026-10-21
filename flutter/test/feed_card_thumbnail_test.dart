import 'dart:async';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pin_image_test_cache.dart';

void main() {
  for (final photoId in <String?>[null, 'update']) {
    testWidgets(
      '${photoId == null ? 'original' : 'update'} in a profile photo list upgrades its preview to the full image',
      (tester) async {
        PaintingBinding.instance.imageCache.clear();
        final cache = PinImageTestCache()..install();
        addTearDown(cache.dispose);
        final full = Completer<void>();
        cache.gates['https://test/full'] = full;
        addTearDown(() {
          if (!full.isCompleted) full.complete();
        });
        final item = PinEntity(
          pinId: 'pin',
          photoId: photoId,
          photoThumbnailUrl: 'https://test/thumb',
          photoUrl: 'https://test/full',
          latitude: 0,
          longitude: 0,
          creator: 'viewer',
          groupId: 'group',
          creationDate: DateTime(2026),
          ttl: DateTime(2026),
          onlySession: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pinImageSourcesProvider.overrideWithValue(
                createTestImageSources(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: FeedCardThumbnail(
                  item: item,
                  maxWidth: 300,
                  maxHeight: 400,
                ),
              ),
            ),
          ),
        );
        await pumpImageLoads(tester);
        expect(
          cache.urls,
          containsAll(['https://test/thumb', 'https://test/full']),
        );
        final preview = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is CachedNetworkImage &&
                widget.imageUrl == 'https://test/thumb',
          ),
          matching: find.byType(RawImage),
        );
        expect(tester.widget<RawImage>(preview).image, isNotNull);
        full.complete();
        await pumpImageLoads(tester);
        expect(
          tester
              .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .map((image) => image.imageUrl),
          ['https://test/full'],
        );
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      },
    );
  }
}
