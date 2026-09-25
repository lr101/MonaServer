import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pin marker shows the selected frame and gone state', (
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
      find.bySemanticsLabel('Pin marked gone · Moss frame'),
      findsOneWidget,
    );

    await expectLater(
      find.byKey(markerKey),
      matchesGoldenFile('goldens/pin_marker_gone_moss.png'),
    );
  });
}
