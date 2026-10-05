import 'dart:io';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/like_buttons.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  final pin = PinEntity(
    pinId: 'pin',
    latitude: 50.11,
    longitude: 8.68,
    creationDate: DateTime.utc(2026, 10),
    creator: 'artist',
    contributorUsername: 'Mara',
    groupId: 'group',
    title: 'Camera study',
    description: 'An illustration from our neighbourhood photo walk. Follow this location to see how the artwork changes over time. The next photograph records a new visit to the same place.',
    lastSynced: DateTime.utc(2026),
    ttl: DateTime.utc(2099),
    onlySession: false,
  );
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('Signika')
          ..addFont(rootBundle.load('assets/fonts/Signika-VariableFont.ttf')))
        .load();
  });
  testWidgets('feed update entries do not show an update glyph', (
    tester,
  ) async {
    final update = pin.withPhotoUpdate(
      PinPhotoDto(
        id: 'update',
        pinId: pin.pinId,
        contributorId: 'artist',
        contributorUsername: 'Mara',
        observedAt: DateTime.utc(2026, 10, 3),
        isOriginal: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(userId: null, refreshToken: null, cameras: []),
          ),
          groupMetadataProvider('group')
              .overrideWith((ref) => Stream.value(null)),
          likeServiceProvider('update').overrideWith(_Likes.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FeedCardSubtitle(pin: update, showDescription: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
  for (final dark in [false, true]) {
    for (final detail in [false, true]) {
      testWidgets(
        '${detail ? 'details' : 'feed'} ${dark ? 'dark' : 'light'} design',
        (tester) async {
          tester.view.physicalSize = const Size(390, 1300);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bytes = File('assets/achievements/photography.jpeg')
              .readAsBytesSync();
          final theme = MaterialTheme(
            ThemeData.light().textTheme.apply(fontFamily: 'Signika'),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                defaultErrorImageProvider.overrideWithValue(bytes),
                getUserProfileSmallProvider('artist')
                    .overrideWith((ref) => Stream.value(bytes)),
                groupProfilePictureSmallByIdProvider('group')
                    .overrideWith((ref) => Stream.value(bytes)),
                feedMapBuilderProvider.overrideWithValue(
                  (pin) => const ColoredBox(
                    color: Color(0xffd9e5d1),
                    child: Center(
                      child: Icon(Icons.map_outlined, color: Color(0xff334533)),
                    ),
                  ),
                ),
                globalDataServiceProvider.overrideWithValue(
                  const GlobalDataDto(
                    userId: 'viewer',
                    refreshToken: null,
                    cameras: [],
                  ),
                ),
                groupMetadataProvider('group').overrideWith(
                  (ref) => Stream.value(
                    GroupEntity(
                      groupId: 'group',
                      name: 'Neighbourhood Art Crew',
                      visibility: 0,
                      userIsMember: true,
                      ttl: DateTime.utc(2099),
                      onlySession: false,
                    ),
                  ),
                ),
                likeServiceProvider('pin').overrideWith(_Likes.new),
                pinByIdProvider('pin').overrideWith((ref) => Stream.value(pin)),
                pinImageBytesProvider('pin')
                    .overrideWith((ref) => Stream.value(bytes)),
                pinImageForDetailsProvider('pin').overrideWith((ref) => bytes),
                currentLocationProvider.overrideWith(
                  (ref) => const Stream.empty(),
                ),
                pinPhotoHistoryProvider('pin').overrideWith(
                  (ref) => [
                    PinPhotoDto(
                      id: 'original',
                      pinId: 'pin',
                      contributorId: 'artist',
                      contributorUsername: 'Mara',
                      observedAt: DateTime.utc(2026, 10),
                      isOriginal: true,
                    ),
                    PinPhotoDto(
                      id: 'update',
                      pinId: 'pin',
                      contributorUsername: 'Noah',
                      caption: 'Still here after the rain.',
                      observedAt: DateTime.utc(2026, 10, 3),
                      isOriginal: false,
                    ),
                  ],
                ),
              ],
              child: MaterialApp(
                theme: dark ? theme.dark() : theme.light(),
                home: RepaintBoundary(
                  key: const Key('design'),
                  child: detail
                      ? const ViewImage(pinId: 'pin')
                      : Scaffold(
                          appBar: AppBar(title: const Text('Feed')),
                          body: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: FeedCardImage(
                              item: pin,
                              maxHeight: 477,
                              maxWidth: 358,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('design')),
            matchesGoldenFile(
              'goldens/pin-${detail ? 'details' : 'feed'}-${dark ? 'dark' : 'light'}.png',
            ),
          );
        },
      );
    }
  }
  for (final width in [320.0, 800.0]) {
    testWidgets('metadata fits $width with large text', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
            groupProfilePictureSmallByIdProvider('group')
                .overrideWith((ref) => Stream.value(kTransparentImage)),
            feedMapBuilderProvider.overrideWithValue(
              (pin) => const ColoredBox(color: Colors.grey),
            ),
            pinImageForDetailsProvider('pin')
                .overrideWith((ref) => kTransparentImage),
            pinPhotoHistoryProvider('pin').overrideWith((ref) => []),
            currentLocationProvider.overrideWith((ref) => const Stream.empty()),
            groupMetadataProvider('group')
                .overrideWith((ref) => Stream.value(null)),
            likeServiceProvider('pin').overrideWith(_Likes.new),
            globalDataServiceProvider.overrideWithValue(
              const GlobalDataDto(
                userId: 'viewer',
                refreshToken: null,
                cameras: [],
              ),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: FeedCardImage(
                    item: pin,
                    maxWidth: width - 32,
                    maxHeight: (width - 32) * 4 / 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Photo information'), findsNothing);
      expect(find.textContaining('50.1100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Likes extends LikeService {
  @override
  Future<PinLikeDto> build(String pinId) async =>
      PinLikeDto(likeCount: 12, likedByUser: false);
}
