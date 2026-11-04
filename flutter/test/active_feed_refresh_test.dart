import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/feed/presentation/active_group_feed.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  testWidgets(
    'newly captured photo appears first when the feed is at the top',
    (tester) async {
      final updates = StreamController<List<PinEntity>>.broadcast();
      addTearDown(updates.close);
      PinEntity pin(String id, int day, {String? photoId}) => PinEntity(
        pinId: id,
        photoId: photoId,
        latitude: 0,
        longitude: 0,
        creationDate: DateTime.utc(2026, 1, day),
        creator: '',
        groupId: '',
        ttl: DateTime.utc(2026),
        onlySession: false,
      );
      final old = [pin('older', 2), pin('oldest', 1)];
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
            home: Scaffold(
              body: SizedBox(height: 100, child: ActiveGroupFeed()),
            ),
          ),
        ),
      );
      updates.add(old);
      await tester.pump();
      await tester.pump();
      final controller = tester
          .widget<PagingListener<int, PinEntity>>(
            find.byType(PagingListener<int, PinEntity>),
          )
          .controller;
      controller.value = PagingState(pages: [old], keys: [0]);
      updates.add([pin('older', 3, photoId: 'new'), ...old]);
      await tester.idle();
      expect(controller.value.items?.map((item) => item.entryId), [
        'new',
        'older',
      ]);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      scroll.jumpTo(20);
      updates.add([pin('newest', 4), pin('older', 3, photoId: 'new'), ...old]);
      await tester.idle();
      expect(controller.value.items?.map((item) => item.entryId), [
        'new',
        'older',
      ]);
      scroll.jumpTo(0);
      expect(controller.value.items?.map((item) => item.entryId), [
        'newest',
        'new',
      ]);
    },
  );

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
    updates.add(pins);
    await tester.pump();
    await tester.pump();
    final controller = tester
        .widget<PagingListener<int, PinEntity>>(
          find.byType(PagingListener<int, PinEntity>),
        )
        .controller;
    controller.value = PagingState(pages: [pins.take(9).toList()], keys: [0]);
    updates.add(List.of(pins));
    await tester.idle();
    expect(controller.value.items?.length, 9);
    expect(controller.value.hasNextPage, isTrue);
  });
}
