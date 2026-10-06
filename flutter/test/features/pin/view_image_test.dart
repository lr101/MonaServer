import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image_header.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets(
    'pin details reuse the feed card and keep the opened photo selected',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pin = PinEntity(
        pinId: 'pin',
        latitude: 50,
        longitude: 8,
        creationDate: DateTime.utc(2026),
        title: 'The riverside gate',
        creator: 'maker',
        contributorUsername: 'Original photographer',
        groupId: 'group',
        description: 'A note on this pin',
        lastSynced: DateTime.utc(2026),
        ttl: DateTime.utc(2099),
        onlySession: false,
      );
      final updateLikes = _PendingLikeService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProfilePictureSmallByIdProvider('group')
                .overrideWith((ref) => Stream.value(kTransparentImage)),
            feedMapBuilderProvider.overrideWithValue(
              (pin) => const ColoredBox(color: Colors.grey),
            ),
            groupMetadataProvider('group')
                .overrideWith((ref) => Stream.value(null)),
            likeServiceProvider('update').overrideWith(() => updateLikes),
            globalDataServiceProvider.overrideWithValue(
              const GlobalDataDto(
                userId: 'viewer',
                refreshToken: null,
                cameras: [],
              ),
            ),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
            getUserProfileSmallProvider('photo-maker-id')
                .overrideWith((ref) => Stream.value(kTransparentImage)),
            getUserProfileSmallProvider('maker')
                .overrideWith((ref) => Stream.value(kTransparentImage)),
            pinByIdProvider('pin').overrideWith((ref) => Stream.value(pin)),
            pinImageForDetailsProvider('pin')
                .overrideWith((ref) => kTransparentImage),
            pinThumbnailBytesProvider('pin')
                .overrideWith((ref) => Stream.value(kTransparentImage)),
            currentLocationProvider.overrideWith((ref) => const Stream.empty()),
            pinPhotoHistoryProvider('pin').overrideWith(
              (ref) => Future.value([
                PinPhotoDto(
                  id: 'original',
                  pinId: 'pin',
                  contributorId: 'photo-maker-id',
                  contributorUsername: 'Original photographer',
                  observedAt: DateTime.utc(2025, 12, 31),
                  isOriginal: true,
                ),
                PinPhotoDto(
                  id: 'update',
                  pinId: 'pin',
                  contributorId: 'photo-maker-id',
                  contributorUsername: List.filled(64, 'walker').join(' '),
                  image: 'https://example.test/update.png',
                  caption: 'Still here today',
                  observedAt: DateTime.utc(2026, 2),
                  isOriginal: false,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: ViewImage(pinId: 'pin', initialPhotoId: 'update'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Photo information'), findsNothing);
      expect(find.byType(FeedCardImage), findsOneWidget);
      expect(find.text('The riverside gate'), findsOneWidget);
      final longUsername = List.filled(64, 'walker').join(' ');
      expect(find.text(longUsername), findsOneWidget);
      expect(find.text('Still here today'), findsOneWidget);
      expect(find.text('Original photographer'), findsNothing);
      expect(find.text('A note on this pin'), findsNothing);
      expect(
        tester.getSize(find.byType(FeedCardImageHeader)).height,
        kMinInteractiveDimension,
      );
      expect(find.byTooltip('Pin options'), findsOneWidget);
      expect(find.byTooltip('Post options'), findsNothing);
      expect(find.byTooltip('Previous photo'), findsNothing);
      expect(find.byTooltip('Next photo'), findsNothing);
      expect(find.text('Update'), findsNothing);
      expect(find.text('Mark as gone'), findsNothing);
      expect(find.text('Waiting for a location fix.'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PageView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PageView));
      await tester.pump();
      expect(updateLikes.request?.like, true);
      updateLikes.pending.complete();
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(find.text('Original photographer'), findsOneWidget);
      expect(find.text('A note on this pin'), findsOneWidget);
      expect(find.text('Still here today'), findsNothing);
      expect(find.text(longUsername), findsNothing);

      expect(find.byTooltip('Photo information'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
}

class _PendingLikeService extends LikeService {
  final pending = Completer<void>();
  CreateLikeDto? request;
  @override
  Future<PinLikeDto> build(String pinId) async =>
      PinLikeDto(likeCount: 0, likedByUser: false);
  @override
  Future<void> addLike(String creatorId, CreateLikeDto dto) async {
    request = dto;
    state = AsyncData(PinLikeDto(likeCount: 1, likedByUser: true));
    await pending.future;
    state = AsyncData(PinLikeDto(likeCount: 0, likedByUser: false));
  }
}
