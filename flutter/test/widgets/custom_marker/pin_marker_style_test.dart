import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback pin shapes match the earned preset shapes', () {
    expect(MapPinDesign.forStyle('sunset').shape, 'circle');
    expect(MapPinDesign.forStyle('aurora').shape, 'shield');
    expect(MapPinDesign.forStyle('jade').shape, 'circle');
    expect(MapPinDesign.forStyle('rose').shape, 'circle');
    expect(MapPinDesign.forStyle('midnight').shape, 'shield');
  });

  testWidgets('hard group pin style displays an earned emblem', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PinMarkerImage(
            isGone: false,
            style: 'orchid',
            image: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('pin-style-emblem-orchid')),
      findsOneWidget,
    );
  });

  testWidgets('pin marker shows the selected design and gone state', (
    tester,
  ) async {
    final markerKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: markerKey,
              child: const PinMarkerImage(
                isGone: true,
                style: 'moss',
                image: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('pin-style-frame-moss')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Pin marked gone · Moss pin design'),
      findsOneWidget,
    );

    await expectLater(
      find.byKey(markerKey),
      matchesGoldenFile('goldens/pin_marker_gone_moss.png'),
    );
  });
}
