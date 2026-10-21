import 'dart:async';

import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/remote_image_source.dart';
import 'package:buff_lisa/widgets/remote_image/remote_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

import 'support/pin_image_test_cache.dart';

void main() {
  late PinImageTestCache cache;
  late PinImageSources pins;
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    cache = PinImageTestCache()..install();
    pins = createTestImageSources();
  });
  tearDown(() => cache.dispose());

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> mount(WidgetTester tester, {bool reduceMotion = false}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const SizedBox(
                width: 200,
                height: 300,
                child: RemoteImage(
                  image: RemoteImageReference(
                    kind: RemoteImageKind.pin,
                    id: 'pin',
                    photoId: 'photo',
                    thumbnailUrl: 'https://test/thumb',
                    imageUrl: 'https://test/full',
                  ),
                  policy: RemoteImagePolicy.previewThenFull,
                ),
              ),
            ),
          ),
        ),
      );
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  }

  double visibleOpacity(WidgetTester tester, [Finder? target]) {
    final raw = target ?? find.byType(RawImage).last;
    expect(tester.widget<RawImage>(raw).image, isNotNull);
    var opacity = 1.0;
    RenderObject? node = tester.renderObject(raw);
    while (node != null) {
      if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
      if (node is RenderOpacity) opacity *= node.opacity;
      node = node.parent;
    }
    return opacity;
  }

  testWidgets(
    'a batch of decoded thumbnails fades in instead of appearing in one frame',
    (tester) async {
      final batch = Completer<void>();
      for (var index = 0; index < 3; index++) {
        cache.gates['https://test/thumb$index'] = batch;
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
          child: MaterialApp(
            home: Row(
              children: [
                for (var index = 0; index < 3; index++)
                  SizedBox.square(
                    dimension: 100,
                    child: RemoteImage(
                      image: RemoteImageReference(
                        kind: RemoteImageKind.pin,
                        id: 'pin$index',
                        thumbnailUrl: 'https://test/thumb$index',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await frames(tester);
      expect(find.byType(RawImage), findsNothing);
      batch.complete();
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(RawImage).evaluate().length == 3) break;
      }
      expect(find.byType(RawImage), findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(visibleOpacity(tester, find.byType(RawImage).at(i)), 0);
      }
      await tester.pump(const Duration(milliseconds: 120));
      for (var i = 0; i < 3; i++) {
        expect(
          visibleOpacity(tester, find.byType(RawImage).at(i)),
          inExclusiveRange(0, 1),
        );
      }
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 3; i++) {
        expect(visibleOpacity(tester, find.byType(RawImage).at(i)), 1);
      }
      await finish(tester);
    },
  );

  for (final kind in RemoteImageKind.values) {
    testWidgets(
      'a cached $kind remounts without a placeholder or repeated fade',
      (tester) async {
        var shown = true;
        Widget view() => ProviderScope(
          overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
          child: MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 100,
                child: shown
                    ? RemoteImage(
                        image: RemoteImageReference(
                          kind: kind,
                          id: 'pin',
                          photoId: 'photo',
                          thumbnailUrl: 'https://test/thumb',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpWidget(view());
        await frames(tester);
        shown = false;
        await tester.pumpWidget(view());
        await tester.pump();
        shown = true;
        await tester.pumpWidget(view());
        expect(find.byType(RawImage), findsOneWidget);
        expect(visibleOpacity(tester), 1);
        expect(cache.urls, ['https://test/thumb']);
        await finish(tester);
      },
    );
  }

  testWidgets('metadata refresh keeps the decoded image fully visible', (
    tester,
  ) async {
    var signature = 'old';
    Widget view() => ProviderScope(
      overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
      child: MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 100,
            child: RemoteImage(
              image: RemoteImageReference(
                kind: RemoteImageKind.pin,
                id: 'pin',
                photoId: 'photo',
                thumbnailUrl: 'https://test/thumb?signature=$signature',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view());
    await frames(tester);
    final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
    signature = 'new';
    await tester.pumpWidget(view());
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      expect(visibleOpacity(tester), 1);
      expect(
        tester
            .widget<RawImage>(find.byType(RawImage).last)
            .image!
            .isCloneOf(pixels),
        isTrue,
      );
    }
    expect(cache.urls, ['https://test/thumb?signature=old']);
    await finish(tester);
  });

  for (final policy in RemoteImagePolicy.values) {
    for (final fails in [false, true]) {
      testWidgets(
        '$policy metadata replacement retains pixels (failure: $fails)',
        (tester) async {
          var path = 'offline';
          final replacement = Completer<void>();
          cache.gates['https://test/online'] = replacement;
          Widget view() => ProviderScope(
            overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
            child: MaterialApp(
              home: Center(
                child: SizedBox.square(
                  dimension: 100,
                  child: RemoteImage(
                    image: RemoteImageReference(
                      kind: RemoteImageKind.pin,
                      id: 'pin',
                      photoId: 'photo',
                      thumbnailUrl: 'https://test/$path',
                      imageUrl: 'https://test/$path',
                    ),
                    policy: policy,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(view());
          await frames(tester);
          final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
          path = 'online';
          await tester.pumpWidget(view());
          await frames(tester);
          expect(find.byType(RawImage), findsOneWidget);
          expect(visibleOpacity(tester), 1);
          expect(
            tester
                .widget<RawImage>(find.byType(RawImage))
                .image!
                .isCloneOf(pixels),
            isTrue,
          );
          replacement.complete();
          if (fails) cache.statuses['https://test/online'] = 404;
          await frames(tester);
          expect(cache.urls.toSet(), {
            'https://test/offline',
            'https://test/online',
          });
          expect(cache.urls.length, lessThanOrEqualTo(3));
          expect(visibleOpacity(tester), 1);
          expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
          if (fails) {
            expect(
              tester
                  .widget<RawImage>(find.byType(RawImage))
                  .image!
                  .isCloneOf(pixels),
              isTrue,
            );
            final downloads = cache.urls.length;
            await tester.pump(const Duration(seconds: 30));
            expect(cache.urls.length, downloads);
          } else {
            expect(
              tester
                  .widget<RawImage>(find.byType(RawImage))
                  .image!
                  .isCloneOf(pixels),
              isFalse,
            );
          }
          await finish(tester);
        },
      );
    }
  }

  Finder variant(String name) => find.byWidgetPredicate(
    (widget) =>
        widget is CachedNetworkImage && widget.imageUrl == 'https://test/$name',
  );
  for (final kind in [RemoteImageKind.user, RemoteImageKind.group]) {
    testWidgets(
      'an ID-only $kind updates from sync without clearing its frame',
      (tester) async {
        final batchKind = kind == RemoteImageKind.user
            ? BatchReadKind.userImageSmall
            : BatchReadKind.groupImageSmall;
        pins.registry.register(batchKind, 'resource', 'https://test/offline');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
            child: MaterialApp(
              home: Center(
                child: SizedBox.square(
                  dimension: 100,
                  child: RemoteImage(
                    image: RemoteImageReference(kind: kind, id: 'resource'),
                  ),
                ),
              ),
            ),
          ),
        );
        await frames(tester);
        final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
        pins.registry.register(
          batchKind,
          'resource',
          'https://test/offline?signature=new',
        );
        await frames(tester);
        expect(visibleOpacity(tester), 1);
        expect(cache.urls, ['https://test/offline']);
        final online = Completer<void>();
        cache.gates['https://test/online'] = online;
        pins.registry.register(batchKind, 'resource', 'https://test/online');
        await frames(tester);
        expect(cache.urls, contains('https://test/online'));
        expect(visibleOpacity(tester), 1);
        expect(
          tester
              .widget<RawImage>(find.byType(RawImage))
              .image!
              .isCloneOf(pixels),
          isTrue,
        );
        online.complete();
        await frames(tester);
        expect(
          tester
              .widget<RawImage>(find.byType(RawImage))
              .image!
              .isCloneOf(pixels),
          isFalse,
        );
        final latest = tester.widget<RawImage>(find.byType(RawImage)).image!;
        cache.statuses['https://test/retry'] = 403;
        pins.registry.register(batchKind, 'resource', 'https://test/retry');
        await frames(tester);
        expect(
          tester
              .widget<RawImage>(find.byType(RawImage))
              .image!
              .isCloneOf(latest),
          isTrue,
        );
        final downloads = cache.urls.length;
        cache.statuses['https://test/retry'] = 200;
        pins.registry.register(batchKind, 'resource', 'https://test/retry');
        await frames(tester);
        expect(cache.urls.length, greaterThan(downloads));
        expect(
          tester
              .widget<RawImage>(find.byType(RawImage))
              .image!
              .isCloneOf(latest),
          isFalse,
        );
        await finish(tester);
      },
    );
  }
  testWidgets(
    'late online metadata revives a failed replacement without blanking its retained image',
    (tester) async {
      var path = 'offline';
      cache.statuses['https://test/expired'] = 403;
      Widget view() => ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 100,
              child: RemoteImage(
                image: RemoteImageReference(
                  kind: RemoteImageKind.pin,
                  id: 'pin',
                  thumbnailUrl: 'https://test/$path',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await frames(tester);
      final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
      path = 'expired';
      await tester.pumpWidget(view());
      await frames(tester);
      expect(visibleOpacity(tester), 1);
      final online = Completer<void>();
      cache.gates['https://test/online'] = online;
      pins.registry.register(
        BatchReadKind.pinImageThumbnail,
        'pin',
        'https://test/online',
      );
      await frames(tester);
      expect(cache.urls, contains('https://test/online'));
      expect(visibleOpacity(tester), 1);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isTrue,
      );
      online.complete();
      await frames(tester);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isFalse,
      );
      await finish(tester);
    },
  );
  testWidgets(
    'online metadata during fallback restarts at the corrected thumbnail',
    (tester) async {
      var path = 'offline';
      final expired = Completer<void>();
      cache.statuses['https://test/expired'] = 403;
      cache.gates['https://test/expired'] = expired;
      Widget view() => ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 100,
              child: RemoteImage(
                image: RemoteImageReference(
                  kind: RemoteImageKind.pin,
                  id: 'pin',
                  thumbnailUrl: 'https://test/$path',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await frames(tester);
      final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
      path = 'expired';
      await tester.pumpWidget(view());
      await frames(tester);
      expired.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final online = Completer<void>();
      cache.gates['https://test/online'] = online;
      pins.registry.register(
        BatchReadKind.pinImageThumbnail,
        'pin',
        'https://test/online',
      );
      await frames(tester);
      expect(cache.urls, contains('https://test/online'));
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isTrue,
      );
      expect(visibleOpacity(tester), 1);
      online.complete();
      await frames(tester);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isFalse,
      );
      await finish(tester);
    },
  );
  Future<void> decodeFull(WidgetTester tester, Completer<void> full) async {
    full.complete();
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find
          .descendant(of: variant('full'), matching: find.byType(RawImage))
          .evaluate()
          .isNotEmpty)
        break;
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'full photo fades over its thumbnail before releasing the preview',
    (tester) async {
      final full = Completer<void>();
      cache.gates['https://test/full'] = full;
      await mount(tester);
      await frames(tester);
      await decodeFull(tester, full);
      final layer = find.ancestor(
        of: variant('full'),
        matching: find.byType(AnimatedOpacity),
      );
      expect(variant('thumb'), findsOneWidget);
      expect(
        tester.renderObject<RenderAnimatedOpacity>(layer).opacity.value,
        0,
      );
      await tester.pump(const Duration(milliseconds: 120));
      final opacity = tester
          .renderObject<RenderAnimatedOpacity>(layer)
          .opacity
          .value;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      expect(variant('thumb'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        tester.renderObject<RenderAnimatedOpacity>(layer).opacity.value,
        1,
      );
      expect(variant('thumb'), findsNothing);
      await finish(tester);
    },
  );

  testWidgets('reduced motion replaces the preview without an animated fade', (
    tester,
  ) async {
    final full = Completer<void>();
    cache.gates['https://test/full'] = full;
    await mount(tester, reduceMotion: true);
    await frames(tester);
    await decodeFull(tester, full);
    final layer = find.ancestor(
      of: variant('full'),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.renderObject<RenderAnimatedOpacity>(layer).opacity.value, 1);
    expect(variant('thumb'), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'keeps a decoded thumbnail visible until the full photo arrives',
    (tester) async {
      final full = Completer<void>();
      cache.gates['https://test/full'] = full;
      await mount(tester);
      await frames(tester);
      expect(
        cache.urls,
        containsAll(['https://test/thumb', 'https://test/full']),
      );
      final preview = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is CachedNetworkImage &&
              widget.imageUrl.endsWith('/thumb'),
        ),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(preview).image, isNotNull);
      full.complete();
      await frames(tester);
      expect(
        tester
            .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .map((image) => image.imageUrl),
        ['https://test/full'],
      );
      final displayed = tester.widget<Image>(find.byType(Image).last);
      expect(displayed.image, isA<ResizeImage>());
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'retains a successful preview after all full-photo attempts fail',
    (tester) async {
      cache.statuses['https://test/full'] = 403;
      await mount(tester);
      await frames(tester);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      final preview = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is CachedNetworkImage &&
              widget.imageUrl.endsWith('/thumb'),
        ),
        matching: find.byType(RawImage),
      );
      expect(tester.widget<RawImage>(preview).image, isNotNull);
      final count = cache.urls.length;
      await tester.pump(const Duration(seconds: 30));
      expect(cache.urls.length, count);
      await finish(tester);
    },
  );

  testWidgets('renews the full photo while leaving its preview visible', (
    tester,
  ) async {
    cache.statuses['https://test/full'] = 403;
    final renewed = Completer<void>();
    cache.gates['https://test/renewed'] = renewed;
    pins = PinImageSources(
      registry: pins.registry,
      batch: pins.batch,
      namespace: pins.namespace,
      getPhotos: (id) async => [
        PinPhotoDto(
          id: 'photo',
          pinId: id,
          contributorUsername: 'a',
          observedAt: DateTime(2026),
          isOriginal: false,
          image: 'https://test/renewed',
          imageThumbnail: 'https://test/thumb',
        ),
      ],
    );
    await mount(tester);
    await frames(tester);
    expect(cache.urls, contains('https://test/renewed'));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    renewed.complete();
    await frames(tester);
    expect(
      tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((image) => image.imageUrl),
      ['https://test/renewed'],
    );
    await finish(tester);
  });

  testWidgets('a mounted original recovers when sync supplies metadata later', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
        child: const MaterialApp(
          home: SizedBox.square(
            dimension: 100,
            child: RemoteImage(
              image: RemoteImageReference(
                kind: RemoteImageKind.pin,
                id: 'cold',
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    pins.registry.register(
      BatchReadKind.pinImageThumbnail,
      'cold',
      'https://test/late-thumb',
    );
    await frames(tester);
    expect(cache.urls, contains('https://test/late-thumb'));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    await finish(tester);
  });

  testWidgets(
    'new photo metadata recovers a previously failed progressive display',
    (tester) async {
      var suffix = 'missing';
      Widget view() => ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
        child: MaterialApp(
          home: SizedBox.square(
            dimension: 100,
            child: RemoteImage(
              image: RemoteImageReference(
                kind: RemoteImageKind.pin,
                id: 'pin',
                photoId: 'photo',
                thumbnailUrl: 'https://test/$suffix-thumb',
                imageUrl: 'https://test/$suffix-full',
              ),
              policy: RemoteImagePolicy.previewThenFull,
            ),
          ),
        ),
      );
      cache.statuses['https://test/missing-thumb'] = 404;
      cache.statuses['https://test/missing-full'] = 404;
      await tester.pumpWidget(view());
      await frames(tester);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      suffix = 'recovered';
      await tester.pumpWidget(view());
      await frames(tester);
      expect(cache.urls, contains('https://test/recovered-full'));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'a signature-only update keeps decoded pixels during URL resolution',
    (tester) async {
      var signature = 'old';
      Widget view() => ProviderScope(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
        child: MaterialApp(
          home: SizedBox.square(
            dimension: 100,
            child: RemoteImage(
              image: RemoteImageReference(
                kind: RemoteImageKind.pin,
                id: 'pin',
                photoId: 'photo',
                thumbnailUrl: 'https://test/stable-thumb?signature=$signature',
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view());
      await frames(tester);
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image;
      expect(decoded, isNotNull);
      signature = 'new';
      await tester.pumpWidget(view());
      expect(
        tester
            .widget<RawImage>(find.byType(RawImage))
            .image!
            .isCloneOf(decoded!),
        isTrue,
      );
      await frames(tester);
      expect(cache.urls, ['https://test/stable-thumb?signature=old']);
      await finish(tester);
    },
  );

  testWidgets(
    'an avatar replacement reloads pixels at an unchanged object URL',
    (tester) async {
      final container = ProviderContainer(
        overrides: [pinImageSourcesProvider.overrideWithValue(pins)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SizedBox.square(
              dimension: 80,
              child: RemoteImage(
                image: RemoteImageReference(
                  kind: RemoteImageKind.user,
                  id: 'user',
                  thumbnailUrl: 'https://test/avatar',
                ),
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      expect(cache.urls, ['https://test/avatar']);
      final pixels = tester.widget<RawImage>(find.byType(RawImage)).image!;
      final replacement = Completer<void>();
      cache.gates['https://test/avatar'] = replacement;
      await tester.runAsync(
        () => container
            .read(imageContentRevisionsProvider.notifier)
            .replace('user:user'),
      );
      await frames(tester);
      expect(visibleOpacity(tester), 1);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isTrue,
      );
      replacement.complete();
      await frames(tester);
      expect(cache.urls, ['https://test/avatar', 'https://test/avatar']);
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(pixels),
        isFalse,
      );
      await finish(tester);
    },
  );
}
