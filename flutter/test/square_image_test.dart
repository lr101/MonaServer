import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

import 'support/pin_image_test_cache.dart';

void main() {
  late PinImageTestCache cache;
  late SuppliedImageUrlRegistry registry;
  late BatchReadCoalescer batch;
  late PinImageSources sources;
  var historyRequests = 0;
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    cache = PinImageTestCache()..install();
    registry = SuppliedImageUrlRegistry();
    batch = BatchReadCoalescer(
      window: Duration.zero,
      read: (items) async => [
        for (final item in items)
          BatchReadResult(
            kind: batchResultKind(item.kind),
            id: item.id,
            status: 404,
          ),
      ],
    );
    historyRequests = 0;
    sources = PinImageSources(
      registry: registry,
      batch: batch,
      namespace: 'session',
      getPhotos: (id) async {
        historyRequests++;
        return [
          PinPhotoDto(
            id: 'photo',
            pinId: id,
            contributorUsername: 'a',
            observedAt: DateTime(2026),
            imageThumbnail: 'https://example.test/renewed.png',
            image: 'https://example.test/full.png',
            isOriginal: false,
          ),
        ];
      },
    );
  });
  tearDown(() async {
    registry.dispose();
    batch.dispose();
    await cache.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? photoId,
    String? thumb,
    String? full,
    void Function(int)? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(sources)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 3),
            child: Center(
              child: SizedBox.square(
                dimension: 100,
                child: SquareImage(
                  pinId: 'pin-1',
                  photoId: photoId,
                  photoThumbnailUrl: thumb,
                  photoUrl: full,
                  groupId: 'group',
                  index: 7,
                  onTap: onTap ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 11));
  }

  testWidgets(
    'loads a supplied URL through the package without waiting for byte storage',
    (tester) async {
      registry.register(
        BatchReadKind.pinImageThumbnail,
        'pin-1',
        'https://example.test/thumb.png',
      );
      await mount(tester);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(cache.urls, ['https://example.test/thumb.png']);
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(provider.width, 300);
      expect(provider.imageProvider, isA<CachedNetworkImageProvider>());
    },
  );
  testWidgets('does not download a full photo when the thumbnail succeeds', (
    tester,
  ) async {
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png',
      full: 'https://example.test/full.png',
    );
    expect(cache.urls, ['https://example.test/thumb.png']);
    expect(historyRequests, 0);
  });
  testWidgets('falls back from a failed thumbnail to the full photo', (
    tester,
  ) async {
    cache.statuses['https://example.test/thumb.png'] = 404;
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png',
      full: 'https://example.test/full.png',
    );
    expect(cache.urls, [
      'https://example.test/thumb.png',
      'https://example.test/full.png',
    ]);
    expect(find.byType(Image), findsOneWidget);
    expect(historyRequests, 0);
  });
  testWidgets('renews expired photo metadata and displays the new image', (
    tester,
  ) async {
    cache.statuses['https://example.test/expired-thumb.png'] = 403;
    cache.statuses['https://example.test/expired-full.png'] = 403;
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/expired-thumb.png',
      full: 'https://example.test/expired-full.png',
    );
    expect(cache.urls, [
      'https://example.test/expired-thumb.png',
      'https://example.test/expired-full.png',
      'https://example.test/renewed.png',
    ]);
    expect(historyRequests, 1);
    expect(find.byType(Image), findsOneWidget);
  });
  testWidgets('stops automatic retries and keeps a missing tile tappable', (
    tester,
  ) async {
    var tapped = -1;
    await mount(tester, onTap: (i) => tapped = i);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    await tester.tap(find.byType(SquareImage), warnIfMissed: false);
    expect(tapped, 7);
    await tester.pump(const Duration(seconds: 30));
    expect(cache.urls, isEmpty);
  });
  testWidgets('a metadata-only URL rotation reuses the decoded image', (
    tester,
  ) async {
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png?signature=old',
    );
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png?signature=new',
    );
    expect(cache.urls, ['https://example.test/thumb.png?signature=old']);
  });
  testWidgets('a new session cannot reuse a previous session decoded frame', (
    tester,
  ) async {
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png',
    );
    sources = PinImageSources(
      registry: registry,
      batch: batch,
      namespace: 'new-session',
      getPhotos: (_) async => [],
    );
    await mount(
      tester,
      photoId: 'photo',
      thumb: 'https://example.test/thumb.png',
    );
    expect(cache.urls, [
      'https://example.test/thumb.png',
      'https://example.test/thumb.png',
    ]);
  });
  testWidgets(
    'renews a failed object when thumbnail and full URLs share its cache key',
    (tester) async {
      const expired = 'https://example.test/shared.png?signature=expired';
      const renewed = 'https://example.test/shared.png?signature=renewed';
      cache.statuses[expired] = 403;
      sources = PinImageSources(
        registry: registry,
        batch: batch,
        namespace: 'session',
        getPhotos: (id) async => [
          PinPhotoDto(
            id: 'photo',
            pinId: id,
            contributorUsername: 'a',
            observedAt: DateTime(2026),
            image: renewed,
            imageThumbnail: renewed,
            isOriginal: false,
          ),
        ],
      );
      await mount(tester, photoId: 'photo', thumb: expired, full: expired);
      expect(cache.urls, contains(renewed));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
