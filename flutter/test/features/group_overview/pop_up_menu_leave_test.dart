import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/pop_up_menu_leave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public group members can copy an invite share link', (
    tester,
  ) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name: 'Public group',
      visibility: 0,
      userIsMember: true,
      inviteUrl: 'a1b2c3',
      groupAdmin: 'alice',
      ttl: DateTime(2025),
      onlySession: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'alice',
              refreshToken: null,
              cameras: [],
            ),
          ),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
        ],
        child: MaterialApp(
          home: Scaffold(body: PopUpMenuLeave(groupDto: group)),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('Copy share link'), findsOneWidget);
  });
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
