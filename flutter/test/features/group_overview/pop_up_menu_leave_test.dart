import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/user_group_overview.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_HOST=https://preview-api.example.test',
    );
  });
  tearDown(dotenv.clean);

  testWidgets('member group shares its invite link from beside the dropdown', (
    tester,
  ) async {
    final group = _memberGroup(inviteUrl: 'a1b2c3');
    String? clipboardText;
    Map<String, dynamic>? sharedContent;
    var shareUnavailable = false;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<String, dynamic>)['text'] as String;
        }
        return null;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        if (call.method == 'share') {
          if (shareUnavailable) {
            throw PlatformException(code: 'share_unavailable');
          }
          sharedContent = Map<String, dynamic>.from(
            call.arguments as Map<Object?, Object?>,
          );
        }
        return 'dev.fluttercommunity.plus/share/unavailable';
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      );
    });

    await _pumpGroupOverview(tester, group);

    final shareButton = find.byTooltip('Share group');
    final dropdownButton = find.byType(PopupMenuButton<int>);
    expect(shareButton, findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(
      tester.getCenter(shareButton).dx,
      lessThan(tester.getCenter(dropdownButton).dx),
    );

    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(sharedContent?['title'], 'Join Public group');
    expect(
      sharedContent?['text'],
      'Join Public group on Stick-It: '
      'https://preview-api.example.test/#/groups/group-id?invite=a1b2c3',
    );
    expect(clipboardText, isNull);

    shareUnavailable = true;
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(
      clipboardText,
      'https://preview-api.example.test/#/groups/group-id?invite=a1b2c3',
    );
    expect(find.text('Share unavailable. Link copied.'), findsOneWidget);
  });

  testWidgets('member group without an invite link hides the share action', (
    tester,
  ) async {
    await _pumpGroupOverview(tester, _memberGroup());

    expect(find.byTooltip('Share group'), findsNothing);
    expect(find.byType(PopupMenuButton<int>), findsOneWidget);
  });
}

GroupEntity _memberGroup({String? inviteUrl}) => GroupEntity(
  groupId: 'group-id',
  name: 'Public group',
  visibility: 0,
  userIsMember: true,
  inviteUrl: inviteUrl,
  groupAdmin: 'alice',
  ttl: DateTime(2025),
  onlySession: false,
);

Future<void> _pumpGroupOverview(WidgetTester tester, GroupEntity group) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        globalDataServiceProvider.overrideWithValue(
          const GlobalDataDto(userId: 'alice', refreshToken: null, cameras: []),
        ),
        userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
        groupDetailsProvider(group.groupId)
            .overrideWith((ref) => Stream.value(_details(group))),
        memberServiceProvider(group.groupId)
            .overrideWith(_EmptyMemberService.new),
        defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
      ],
      child: MaterialApp(home: UserGroupOverview(groupId: group.groupId)),
    ),
  );
  await tester.pump();
}

GroupDetailsState _details(GroupEntity group) => GroupDetailsState(
  group: group,
  pins: const AsyncData<List<PinEntity>>([]),
  profileImage: const AsyncData<Uint8List?>(null),
);

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
