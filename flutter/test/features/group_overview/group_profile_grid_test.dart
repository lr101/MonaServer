import 'dart:async';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transparent_image/transparent_image.dart';

import '../../support/pin_image_test_cache.dart';

void main() {
  testWidgets(
    'group pins wait for every thumbnail and keep the selected feed index',
    (tester) async {
      final cache = PinImageTestCache()..install();
      addTearDown(cache.dispose);
      final slow = Completer<void>();
      cache.gates['https://test/update-thumb'] = slow;
      final group = GroupEntity(
        groupId: 'group',
        name: 'Group',
        visibility: 0,
        userIsMember: true,
        ttl: DateTime(2026),
        onlySession: false,
      );
      final entries = [
        PinEntity(
          pinId: 'place',
          photoId: 'update',
          photoThumbnailUrl: 'https://test/update-thumb',
          photoUrl: 'https://test/update-full',
          latitude: 0,
          longitude: 0,
          creator: 'viewer',
          groupId: 'group',
          creationDate: DateTime(2026),
          ttl: DateTime(2026),
          onlySession: false,
        ),
      ];
      final router = GoRouter(
        initialLocation: '/group',
        routes: [
          GoRoute(
            path: '/group',
            builder: (_, _) => GroupOverview(
              groupId: 'group',
              details: GroupDetailsState(
                group: group,
                pins: AsyncData(entries),
              ),
            ),
          ),
          GoRoute(
            path: '/feed/:id/:index',
            name: 'groupImageFeed',
            builder: (_, state) => Scaffold(
              body: Text(
                'Selected ${state.pathParameters['id']} ${state.pathParameters['index']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
            userIdProvider.overrideWithValue('viewer'),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
            memberServiceProvider('group').overrideWith(_EmptyMembers.new),
            groupProgressionProvider('group').overrideWith((ref) => null),
            groupDetailsPinsProvider('group')
                .overrideWithValue(AsyncData(entries)),
            groupPinEntriesProvider('group')
                .overrideWith((ref) => Stream.value(entries)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(Tab, 'Pins'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpImageLoads(tester);
      expect(
        find.byType(CircularProgressIndicator).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(SquareImage).hitTestable(), findsNothing);
      slow.complete();
      await pumpImageLoads(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byType(CircularProgressIndicator).hitTestable(),
        findsNothing,
      );
      expect(
        find
            .descendant(
              of: find.byType(SquareImage),
              matching: find.byType(RawImage),
            )
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('update')));
      await tester.pumpAndSettle();
      expect(find.text('Selected group 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    },
  );
}

class _EmptyMembers extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
