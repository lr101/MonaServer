import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_map_state.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/feed_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pin = PinEntity(
    pinId: 'pin-1',
    latitude: 50.11,
    longitude: 8.68,
    creationDate: DateTime.utc(2026),
    creator: 'artist',
    groupId: 'group-1',
    ttl: DateTime.utc(2099),
    onlySession: false,
  );

  testWidgets('collapsed FeedMap does not mount FlutterMap until expanded', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: FeedMap(item: pin),
            ),
          ),
        ),
      ),
    );

    expect(container.read(feedMapStateProvider(pin.entryId)), isTrue);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

    await tester.tap(find.byType(FeedMap));
    expect(container.read(feedMapStateProvider(pin.entryId)), isFalse);
  });
}
