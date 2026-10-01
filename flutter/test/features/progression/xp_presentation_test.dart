import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/data/xp_gain_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/features/progression/presentation/xp_gain_banner.dart';
import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'XP header and notification fit narrow enlarged text (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            accountSessionProvider.overrideWithValue(AccountSession(true)),
            userIdProvider.overrideWithValue(''),
            userGroupServiceProvider.overrideWith(_Groups.new),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          ],
        );
        addTearDown(container.dispose);
        final progress = XpLevelProgress.fromValues(
          level: 7,
          totalXp: 900,
          currentLevelXp: 700,
          nextLevelXp: 1050,
        );
        final theme = MaterialTheme(ThemeData().textTheme);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? theme.dark() : theme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: XpGainBannerHost(child: child!),
              ),
              home: Scaffold(
                bottomNavigationBar: NavigationBar(
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ],
                ),
                body: DefaultTabController(
                  length: 1,
                  child: CustomAvatarScaffold(
                    avatar: const AsyncData(null),
                    title: const Text('Profile'),
                    avatarBuilder: (avatar) => UserXpAvatarIndicator(
                      progress: progress,
                      avatar: avatar,
                      radius: 40,
                    ),
                    avatarEditAction: () {},
                    bottom: const TabBar(tabs: [Tab(text: 'Pins')]),
                    body: const Center(child: Text('Your pins')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lv 7'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('profile-level-badge')))
              .height,
          closeTo(
            tester
                .getSize(
                  find.ancestor(
                    of: find.byIcon(Icons.edit),
                    matching: find.byType(IconButton),
                  ),
                )
                .height,
            2,
          ),
        );
        expect(find.textContaining('200 / 350 XP'), findsNothing);
        expect(
          find.byTooltip(
            'Level 7, 900 total XP, 200 of 350 XP into this level, '
            '150 XP to next level',
          ),
          findsOneWidget,
        );
        final gains = container.read(xpGainsProvider.notifier);
        gains.observe('user:a', 900, 7);
        gains.observe('group:b', 400, 4);
        await tester.pump();
        expect(find.byType(XpGainBanner), findsNothing);
        gains.observe('user:a', 920, 7);
        gains.observe('group:b', 410, 4);
        await tester.pumpAndSettle();
        expect(find.textContaining('+20 XP'), findsOneWidget);
        expect(find.textContaining('+10 XP'), findsOneWidget);
        final bannerRect = tester.getRect(find.byType(SingleChildScrollView));
        expect(
          bannerRect.top,
          greaterThan(tester.view.physicalSize.height / 2),
        );
        expect(
          bannerRect.bottom,
          lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
        );
        expect(tester.getTopLeft(find.byType(CustomAvatarScaffold)).dy, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(XpGainBanner), findsNothing);
      },
    );
  }
}

class _Groups extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
