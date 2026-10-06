import 'dart:typed_data';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_switchable_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  for (final update in [false, true]) {
    testWidgets('feed photo opens ${update ? 'selected update' : 'original'}', (
      tester,
    ) async {
      var pin = PinEntity(
        pinId: 'pin',
        latitude: 0,
        longitude: 0,
        creationDate: DateTime(2026),
        creator: 'maker',
        groupId: 'group',
        ttl: DateTime(2099),
        onlySession: false,
      );
      if (update) {
        pin = pin.withPhotoUpdate(
          PinPhotoDto(
            id: 'update',
            contributorUsername: 'Mara',
            pinId: 'pin',
            observedAt: DateTime(2026),
            isOriginal: false,
          ),
        );
      }
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: FeedSwitchableImage(
                  item: pin,
                  image: kTransparentImage,
                  likeImage: _ignoreTap,
                  onTab: null,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/pin/:id',
            name: 'viewImage',
            builder: (_, state) => Scaffold(
              body: Text(
                '${state.pathParameters['id']}/${state.uri.queryParameters['photo'] ?? 'original'}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FadeInImage));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(
        find.text('pin/${update ? 'update' : 'original'}'),
        findsOneWidget,
      );
    });
  }

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
          home: Scaffold(
            body: MediaQuery(
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
      ),
    );

    final image = tester.widget<FadeInImage>(find.byType(FadeInImage));
    final provider = image.image as ResizeImage;

    expect(provider.width, 300);
    expect((provider.imageProvider as MemoryImage).bytes, same(bytes));
  });
}

void _ignoreTap() {}
