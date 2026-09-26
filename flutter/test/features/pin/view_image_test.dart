import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/widgets/clickable_names/presentation/clickable_user.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
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

    expect(
      find.descendant(of: find.byType(PageView), matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('The riverside gate'), findsOneWidget);
    expect(find.text('Original photographer'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ClickableUser && widget.userId == 'photo-maker-id',
      ),
      findsOneWidget,
    );
    final originalDate = MaterialLocalizations.of(
      tester.element(find.text('Original photographer')),
    ).formatMediumDate(DateTime.utc(2025, 12, 31).toLocal());
    expect(find.text('· $originalDate'), findsOneWidget);
    expect(find.text('Map pin'), findsNothing);
    expect(find.text('50.00000, 8.00000'), findsNothing);
    expect(find.byType(FeedMap), findsNothing);
    expect(
      tester.getTopLeft(find.text('The riverside gate')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(PageView)).dy),
    );
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('Original pin photo'), findsNothing);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    expect(find.text('Upload'), findsNothing);
    expect(find.text('Mark as gone'), findsOneWidget);
    expect(find.text('A note on this pin'), findsOneWidget);
    expect(
      tester.getTopLeft(find.widgetWithText(FilledButton, 'Update')).dy,
      closeTo(
        tester
            .getTopLeft(find.widgetWithText(OutlinedButton, 'Mark as gone'))
            .dy,
        0.1,
      ),
    );
    expect(
      tester.getBottomRight(find.text('Update')).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    final longUsername = List.filled(64, 'walker').join(' ');
    expect(find.text(longUsername), findsOneWidget);
    final authorText = tester.widget<Text>(find.text(longUsername));
    expect(authorText.maxLines, 1);
    expect(authorText.overflow, TextOverflow.ellipsis);
    expect(find.byType(ClickableUser), findsNothing);
    expect(find.text('Still here today'), findsOneWidget);
    expect(find.text('A note on this pin'), findsNothing);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
    final updateDate = MaterialLocalizations.of(
      tester.element(find.text(longUsername)),
    ).formatMediumDate(DateTime.utc(2026, 2).toLocal());
    expect(find.text('· $updateDate'), findsOneWidget);
  });
}
