import 'package:buff_lisa/features/navigation/presentation/navigation_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'only the selected destination exposes accessibility content during transitions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NavigationPages(
                selectedIndex: selected,
                children: const [
                  Center(child: Text('First destination')),
                  Center(child: Text('Second destination')),
                ],
              );
            },
          ),
        ),
      );
      update(() => selected = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('First destination'), findsNothing);
      expect(find.bySemanticsLabel('Second destination'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('destination changes slide instead of jumping', (tester) async {
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return NavigationPages(
              selectedIndex: selected,
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.blue),
              ],
            );
          },
        ),
      ),
    );
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    update(() => selected = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.page, greaterThan(0));
    expect(controller.page, lessThan(1));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
  });

  testWidgets(
    'visited page drafts survive navigation and rapid selection changes',
    (tester) async {
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NavigationPages(
                selectedIndex: selected,
                children: const [
                  Material(
                    child: Center(child: TextField(key: ValueKey('draft'))),
                  ),
                  Text('Middle'),
                  Text('Last'),
                ],
              );
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Keep this draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      update(() => selected = 2);
      await tester.pumpAndSettle();
      update(() => selected = 0);
      await tester.pump(const Duration(milliseconds: 60));
      update(() => selected = 1);
      await tester.pump(const Duration(milliseconds: 60));
      update(() => selected = 0);
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion selects the destination immediately', (
    tester,
  ) async {
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return NavigationPages(
                selectedIndex: selected,
                children: const [Text('First'), Text('Second')],
              );
            },
          ),
        ),
      ),
    );
    update(() => selected = 1);
    await tester.pump();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });
}
