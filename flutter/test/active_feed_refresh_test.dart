import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/feed/presentation/active_group_feed.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/custom_feed.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  testWidgets('feed keeps loaded pages when pin data updates', (tester) async {
    final updates = StreamController<List<PinEntity>>.broadcast();
    addTearDown(updates.close);
    final pins = List.generate(
      12,
      (index) => PinEntity(
        pinId: '$index',
        latitude: 0,
        longitude: 0,
        creationDate: DateTime.utc(2026),
        creator: '',
        groupId: '',
        ttl: DateTime.utc(2026),
        onlySession: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePinEntriesProvider.overrideWith((ref) => updates.stream),
          userIdProvider.overrideWithValue(''),
          currentUserProvider.overrideWith((ref) => null),
          groupActiveServiceProvider.overrideWithValue([]),
          defaultErrorImageProvider.overrideWithValue(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(height: 100, child: ActiveGroupFeed())),
        ),
      ),
    );
    final controller = tester
        .widget<CustomFeed>(find.byType(CustomFeed))
        .pagingController;
    updates.add(pins);
    await tester.pump();
    controller.value = PagingState(
      itemList: pins.take(9).toList(),
      nextPageKey: 9,
    );
    updates.add(List.of(pins));
    await tester.idle();
    expect(controller.itemList?.length, 9);
    expect(controller.nextPageKey, 9);
  });
}
