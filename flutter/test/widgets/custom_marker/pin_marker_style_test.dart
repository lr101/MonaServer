import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pin marker shows the selected frame and gone state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PinMarkerImage(
              isGone: true,
              style: 'moss',
              image: ColoredBox(color: Colors.blue),
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
  });
}
