import 'package:buff_lisa/features/navigation/presentation/adaptive_navigation.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  testWidgets(
    'navigation changes presentation on resize and preserves content',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 2;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AdaptiveNavigation(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                child: const TextField(key: ValueKey('content')),
              );
            },
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('floating-navigation-dock')),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('content')), 'draft');
      tester.view.physicalSize = const Size(900, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        find.byKey(const ValueKey('floating-navigation-dock')),
        findsNothing,
      );
      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Collapse navigation'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand navigation'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        3,
      );
    },
  );
  testWidgets('wide short windows keep navigation reachable', (tester) async {
    tester.view.physicalSize = const Size(900, 250);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigation(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('rail avoids the system status bar', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigation(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.byType(NavigationRail)).dy,
      greaterThanOrEqualTo(32),
    );
  });

  testWidgets(
    'every compact destination shares the centered dock and transparent surround',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var backgroundTaps = 0;
      for (final index in [0, 1, 2, 3, 4]) {
        await tester.pumpWidget(
          MaterialApp(
            home: AdaptiveNavigation(
              selectedIndex: index,
              onDestinationSelected: (_) {},
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => backgroundTaps++,
                child: const ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dock = find.byKey(const ValueKey('floating-navigation-dock'));
        expect(dock, findsOneWidget);
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
          isNull,
        );
        final rect = tester.getRect(dock);
        expect(rect.center.dx, closeTo(160, .1));
        expect(rect.left, greaterThan(0));
        expect(rect.right, lessThan(320));
        expect(rect.bottom, lessThan(740));
        for (final label in ['Groups', 'Camera', 'Map', 'Feed', 'Profile']) {
          expect(find.byTooltip(label), findsOneWidget);
          final target = tester.getSize(find.byTooltip(label));
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));
        }
        await tester.tapAt(Offset(2, rect.center.dy));
      }
      expect(backgroundTaps, 5);
    },
  );

  testWidgets(
    'selection slides and the selected icon expands without showing captions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) => AdaptiveNavigation(
              selectedIndex: selected,
              onDestinationSelected: (value) =>
                  setState(() => selected = value),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      final indicator = find.byKey(const ValueKey('floating-dock-indicator'));
      final start = tester.getTopLeft(indicator).dx;
      await tester.tap(find.byTooltip('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester.getTopLeft(indicator).dx;
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(indicator).dx;
      expect(middle, greaterThan(start));
      expect(middle, lessThan(end));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.person)).size,
        greaterThan(tester.widget<Icon>(find.byIcon(Icons.map_outlined)).size!),
      );
      expect(find.text('Profile'), findsNothing);
    },
  );

  testWidgets('last list action can scroll clear of the floating dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigation(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: Scaffold(
            body: ListView.builder(
              itemCount: 30,
              itemBuilder: (_, index) =>
                  ListTile(title: Text('Row $index'), onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Row 29'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Row 29')).dy,
      lessThanOrEqualTo(
        tester
            .getTopLeft(find.byKey(const ValueKey('floating-navigation-dock')))
            .dy,
      ),
    );
  });
  testWidgets('group list fills the overlay and its last row clears the dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paging = PagingController<int, int>(
      getNextPageKey: (_) => null,
      fetchPage: (_) => <int>[],
    );
    addTearDown(paging.dispose);
    paging.value = PagingState(
      pages: [List.generate(30, (index) => index)],
      keys: [0],
      hasNextPage: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AdaptiveNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            child: CustomScaffold<int>(
              title: const Text('Your groups'),
              pagingController: paging,
              listBuilder: (_, item, _) => SizedBox(
                height: 80,
                child: TextButton(onPressed: () {}, child: Text('Group $item')),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getBottomRight(find.byType(CustomScrollView)).dy, 740);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Group 29'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Group 29')).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('floating-navigation-dock')))
            .dy,
      ),
    );
  });
  testWidgets('dock respects the safe inset and hides for the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveNavigation(
          selectedIndex: 2,
          onDestinationSelected: (_) {},
          child: const SizedBox(),
        ),
      ),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('floating-navigation-dock')))
          .bottom,
      704,
    );
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('floating-navigation-dock')),
      findsNothing,
    );
  });

  testWidgets('reduced motion updates selection without a sliding animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 740),
            disableAnimations: true,
          ),
          child: StatefulBuilder(
            builder: (_, setState) => AdaptiveNavigation(
              selectedIndex: selected,
              onDestinationSelected: (index) =>
                  setState(() => selected = index),
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    final indicator = find.byKey(const ValueKey('floating-dock-indicator'));
    final start = tester.getTopLeft(indicator).dx;
    await tester.tap(find.byTooltip('Profile'));
    await tester.pump();
    expect(tester.getTopLeft(indicator).dx, greaterThan(start + 150));
    final end = tester.getRect(indicator);
    expect(tester.widget<Icon>(find.byIcon(Icons.person)).size, 28);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(indicator), end);
  });
}
