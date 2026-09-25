import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_card_image_header.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('pin page shows one picture without a feed map overlay', (
    tester,
  ) async {
    final pin = PinEntity(
      pinId: 'pin',
      latitude: 50,
      longitude: 8,
      creationDate: DateTime.utc(2026),
      creator: 'maker',
      groupId: 'group',
      description: 'A note on this pin',
      lastSynced: DateTime.utc(2026),
      ttl: DateTime.utc(2099),
      onlySession: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'viewer',
              refreshToken: null,
              cameras: [],
            ),
          ),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          pinByIdProvider('pin').overrideWith((ref) => Stream.value(pin)),
          pinImageBytesProvider('pin')
              .overrideWith((ref) => Stream.value(kTransparentImage)),
          currentLocationProvider.overrideWith((ref) => const Stream.empty()),
          pinPhotoHistoryProvider('pin').overrideWith(
            (ref) => Future.value([
              PinPhotoDto(
                id: 'original',
                pinId: 'pin',
                contributorUsername: 'maker',
                observedAt: DateTime.utc(2026),
                isOriginal: true,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: ViewImage(pinId: 'pin')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(PageView), matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(FeedMap), findsNothing);
    expect(
      tester.getTopLeft(find.byType(FeedCardImageHeader)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(PageView)).dy),
    );
    expect(find.text('Original pin photo'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(find.text('Add photo update'), findsOneWidget);
    expect(find.text('Mark gone'), findsOneWidget);
    expect(find.text('A note on this pin'), findsOneWidget);
  });
}
