import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/features/settings/presentation/settings.dart';
import 'package:buff_lisa/features/settings/presentation/state/notification_state.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/change_email.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/change_password.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_posts.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_users.dart';
import 'package:buff_lisa/util/theme/service/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings groups preferences and toggles dark appearance', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        themeStateProvider.overrideWith(_TestThemeState.new),
        notificationStateProvider.overrideWith(_TestNotificationState.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Settings()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Dark appearance'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);

    final darkSwitch = find.ancestor(
      of: find.text('Dark appearance'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(darkSwitch).value, isFalse);

    await tester.tap(darkSwitch);
    expect(container.read(themeStateProvider), ThemeMode.dark);
  });

  testWidgets('change email uses the shared labeled form and action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChangeEmailPage()));

    expect(find.text('Change email'), findsOneWidget);
    expect(find.text('New email address'), findsOneWidget);
    expect(find.text('Update email'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, 'Update email');
    expect(tester.getSize(button).width, 288);
  });

  testWidgets('empty hidden-posts screen explains how hidden items work', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiddenPostsServiceProvider.overrideWithValue(const [])],
        child: const MaterialApp(home: EditHiddenPosts()),
      ),
    );

    expect(find.text('No hidden posts'), findsOneWidget);
    expect(
      find.text('Posts you hide from the map and feed will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('restoring a hidden post asks for confirmation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiddenPostsServiceProvider.overrideWithValue(const ['artwork-123']),
        ],
        child: const MaterialApp(home: EditHiddenPosts()),
      ),
    );

    expect(find.text('Hidden artwork'), findsOneWidget);
    await tester.tap(find.byTooltip('Show this post again'));
    await tester.pumpAndSettle();

    expect(find.text('Show this post again?'), findsOneWidget);
    expect(
      find.text('This artwork will return to your map and feed.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Show post'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden artwork'), findsOneWidget);
  });

  testWidgets('empty hidden-users screen has a useful empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiddenUserServiceProvider.overrideWithValue(const [])],
        child: const MaterialApp(home: EditHiddenUsers()),
      ),
    );

    expect(find.text('No hidden users'), findsOneWidget);
    expect(
      find.text('Users you hide from the map and feed will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('change password keeps labeled fields and a clear save action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChangePassword()));

    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    expect(find.text('Update password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestThemeState extends ThemeState {
  @override
  ThemeMode build() => ThemeMode.light;

  @override
  void setTheme(bool? isLightTheme) {
    state = getThemeByBool(isLightTheme);
  }
}

class _TestNotificationState extends NotificationState {
  @override
  Future<bool> build() async => false;
}
