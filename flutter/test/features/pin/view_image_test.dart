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
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/data/like_service.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('pin page keeps photo details and actions in a compact layout', (
    tester,
  ) async {
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
      groupId: 'group',
      description: 'A note on this pin',
      lastSynced: DateTime.utc(2026),
      ttl: DateTime.utc(2099),
      onlySession: false,
    );
    final likes = _PendingLikeService();
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
          likeServiceProvider('pin').overrideWith(() => likes),
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
          pinByIdProvider('pin').overrideWith((ref) => Stream.value(pin)),
          pinImageForDetailsProvider('pin')
              .overrideWith((ref) => kTransparentImage),
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
                contributorUsername: List.filled(64, 'walker').join(' '),
                image: 'https://example.test/update.png',
                caption: 'Still here today',
                observedAt: DateTime.utc(2026, 2),
                isOriginal: false,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: ViewImage(pinId: 'pin')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Photo information'), findsNothing);
    expect(find.byTooltip('Show Original'), findsOneWidget);
    expect(find.text('The riverside gate'), findsOneWidget);
    expect(find.text('Original photographer'), findsOneWidget);
    expect(find.text('A note on this pin'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byTooltip('Previous photo'), findsOneWidget);
    expect(find.byTooltip('Next photo'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Mark as gone'), findsOneWidget);
    expect(find.text('Waiting for a location fix.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pump();
    expect(likes.request?.like, true);
    likes.pending.complete();
    await tester.pumpAndSettle();

    final nextPhotoButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Next photo',
    );
    await tester.tap(nextPhotoButton);
    await tester.pumpAndSettle();
    final longUsername = List.filled(64, 'walker').join(' ');
    expect(find.byTooltip('Show Update 1'), findsOneWidget);
    expect(find.text(longUsername), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(longUsername)).overflow,
      TextOverflow.ellipsis,
    );
    expect(find.byType(ClickableUser), findsNothing);
    expect(find.text('Still here today'), findsOneWidget);
    expect(find.text('A note on this pin'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
    final updateDate = MaterialLocalizations.of(
      tester.element(find.text(longUsername)),
    ).formatFullDate(DateTime.utc(2026, 2).toLocal());
    expect(find.text('· $updateDate'), findsNothing);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(PageView));
    await tester.pump();
    expect(updateLikes.request?.like, true);
    updateLikes.pending.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Photo information'), findsNothing);

    expect(tester.takeException(), isNull);
  });
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
