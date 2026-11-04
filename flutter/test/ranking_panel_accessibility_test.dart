import 'package:buff_lisa/data/repository/geo_json_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/map_home/presentation/ranking_panel.dart';
import 'package:buff_lisa/features/navigation/presentation/adaptive_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('rankings panel expands and collapses by tapping its header', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          zoomGidProvider.overrideWith((ref) => (null, null)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RankingSlidingPanel(headerPixelHeight: 60)),
        ),
      ),
    );
    final header = find.bySemanticsLabel(RegExp('Expand rankings'));
    expect(header, findsOneWidget);
    expect(find.text('Rankings'), findsOneWidget);
    expect(find.text('Region unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Collapse rankings')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Collapse rankings')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Expand rankings')), findsOneWidget);
    semantics.dispose();
  });
  testWidgets(
    'rankings tray shares dock edges and keeps content above navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            zoomGidProvider.overrideWith((ref) => (null, null)),
          ],
          child: MaterialApp(
            home: AdaptiveNavigation(
              selectedIndex: 2,
              onDestinationSelected: (_) {},
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: RankingSlidingPanel(
                  headerPixelHeight: 60,
                  navigationClearance: 76,
                ),
              ),
            ),
          ),
        ),
      );
      final dock = tester.getRect(
        find.byKey(const ValueKey('floating-navigation-dock')),
      );
      final trayFinder = find.byKey(const ValueKey('ranking-tray'));
      final tray = tester.getRect(trayFinder);
      expect(tray.left, closeTo(dock.left, .1));
      expect(tray.right, closeTo(dock.right, .1));
      expect(tray.bottom, closeTo(dock.bottom, .1));
      expect(
        tester.getBottomRight(find.text('Rankings')).dy,
        lessThan(dock.top),
      );
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      expect(tester.getRect(trayFinder).height, greaterThan(tray.height));
      expect(tester.getRect(trayFinder).bottom, closeTo(dock.bottom, .1));
      final list = find.descendant(
        of: trayFinder,
        matching: find.byType(CustomScrollView),
      );
      expect(tester.getBottomRight(list).dy, lessThanOrEqualTo(dock.top));
      await tester.drag(find.text('Rankings'), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(tester.getRect(trayFinder).height, closeTo(tray.height, .1));
    },
  );
  testWidgets('rankings snap immediately when reduced motion is enabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          zoomGidProvider.overrideWith((ref) => (null, null)),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(800, 600), disableAnimations: true),
            child: Scaffold(
              body: RankingSlidingPanel(
                headerPixelHeight: 60,
                navigationClearance: 76,
              ),
            ),
          ),
        ),
      ),
    );
    final tray = find.byKey(const ValueKey('ranking-tray'));
    final collapsed = tester.getSize(tray).height;
    await tester.tap(find.text('Rankings'));
    await tester.pump();
    final expanded = tester.getSize(tray).height;
    expect(expanded, greaterThan(collapsed));
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getSize(tray).height, expanded);
  });
  testWidgets('ranking panel remains valid in a short window', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(320, 150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          zoomGidProvider.overrideWith((ref) => (null, null)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RankingSlidingPanel(headerPixelHeight: 60)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  for (final height in [150.0, 700.0]) {
    testWidgets('rankings header fits 200% text at 320 x $height', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = Size(320, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            zoomGidProvider.overrideWith((ref) => (null, null)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, height),
                textScaler: const TextScaler.linear(2),
              ),
              child: const Scaffold(
                body: RankingSlidingPanel(
                  headerPixelHeight: 60,
                  navigationClearance: 76,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Rankings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
