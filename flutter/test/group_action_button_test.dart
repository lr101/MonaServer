import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'admin edit remains restricted; members retain report and leave',
    (tester) async {
      for (final member in [true, false]) {
        for (final userId in ['admin', 'member']) {
          final group = GroupEntity(
            groupId: 'g',
            name: 'Group',
            visibility: 0,
            userIsMember: member,
            groupAdmin: 'admin',
            ttl: DateTime(2027),
            onlySession: false,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                globalDataServiceProvider.overrideWithValue(
                  GlobalDataDto(
                    userId: userId,
                    refreshToken: null,
                    cameras: const [],
                  ),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      for (final action in GroupAction.values)
                        GroupActionButton(group: group, action: action),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(
            find.byTooltip('Edit group'),
            member && userId == 'admin' ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip('Report group'),
            member ? findsOneWidget : findsNothing,
          );
          expect(
            find.byTooltip('Leave group'),
            member ? findsOneWidget : findsNothing,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets('direct edit and report retain route arguments', (tester) async {
    final group = GroupEntity(
      groupId: 'group-123',
      name: 'Group',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'admin',
      ttl: DateTime(2027),
      onlySession: false,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Row(
              children: [
                GroupActionButton(group: group, action: GroupAction.edit),
                GroupActionButton(group: group, action: GroupAction.report),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/edit/:id',
          name: 'groupEdit',
          builder: (_, state) => Text('Edit ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/report',
          name: 'report',
          builder: (_, state) => Text(
            'Report ${state.uri.queryParameters['groupId']} ${(state.extra! as List<String>).single}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'admin',
              refreshToken: null,
              cameras: [],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.byTooltip('Edit group'));
    await tester.pumpAndSettle();
    expect(find.text('Edit group-123'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Report group'));
    await tester.pumpAndSettle();
    expect(find.text('Report group-123 Report Group'), findsOneWidget);
  });
}
