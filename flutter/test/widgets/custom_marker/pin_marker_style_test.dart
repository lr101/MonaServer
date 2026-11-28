import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test('fallback pin shapes match the earned preset shapes', () {
    expect(MapPinDesign.forStyle('sunset').shape, 'circle');
    expect(MapPinDesign.forStyle('aurora').shape, 'shield');
    expect(MapPinDesign.forStyle('jade').shape, 'circle');
    expect(MapPinDesign.forStyle('rose').shape, 'circle');
    expect(MapPinDesign.forStyle('midnight').shape, 'shield');
  });

  for (final style in ['aurora', 'honey', 'orchid', 'ember', 'midnight']) {
    testWidgets('$style pins use color and shape without decorative emblems', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinMarkerImage(
              isGone: false,
              style: style,
              image: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );
      expect(find.byKey(ValueKey('pin-style-frame-$style')), findsOneWidget);
      expect(find.byKey(ValueKey('pin-style-emblem-$style')), findsNothing);
    });
  }

  for (final badge in [
    GroupPinDesignBadge.sun,
    GroupPinDesignBadge.star,
    GroupPinDesignBadge.spark,
  ]) {
    testWidgets(
      'legacy ${badge.value} decoration is omitted from catalog pins',
      (tester) async {
        final original = MapPinDesign.forStyle('honey');
        final dto = original.toDto()..badge = badge;
        final design = MapPinDesign.fromDto(dto);
        expect(design.shape, original.shape);
        expect(design.bodyColor, original.bodyColor);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PinMarkerImage(
                isGone: false,
                style: design.style,
                design: design,
                image: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('pin-style-frame-honey')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pin-style-emblem-honey')),
          findsNothing,
        );
      },
    );
  }

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
