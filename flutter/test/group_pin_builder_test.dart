import 'package:buff_lisa/features/group_overview/presentation/group_pin_builder.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('combines earned colors and shapes without a symbol', (
    tester,
  ) async {
    MapPinDesign? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupPinBuilder(
            initial: MapPinDesign.forStyle('moss'),
            unlocked: [
              MapPinDesign.forStyle('moss'),
              MapPinDesign.forStyle('aurora'),
            ],
            onSave: (design) async {
              saved = design;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aurora'));
    await tester.tap(find.text('Shield'));
    await tester.tap(find.text('Save pin appearance'));
    await tester.pump();
    expect(saved?.bodyColor, MapPinDesign.forStyle('aurora').bodyColor);
    expect(saved?.shape, 'shield');
    expect(saved?.badge, 'none');
    expect(saved?.style, 'moss');
  });
  testWidgets('narrow dark builder keeps failed saves recoverable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupPinBuilder(
              initial: MapPinDesign.forStyle('moss'),
              unlocked: [
                MapPinDesign.forStyle('moss'),
                MapPinDesign.forStyle('aurora'),
              ],
              onSave: (_) async {
                attempts++;
                if (attempts == 1) throw StateError('failed');
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save pin appearance'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save pin appearance. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save pin appearance'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      find.text('Could not save pin appearance. Try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
