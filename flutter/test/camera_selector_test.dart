import 'package:buff_lisa/features/camera/presentation/camera_selector.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps camera choices behind a selection button', (tester) async {
    const cameras = [
      CameraDescription(
        name: 'back-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      CameraDescription(
        name: 'front-camera',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CameraSelectorButton(
            cameras: cameras,
            selectedIndex: 0,
            onSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Select camera'), findsOneWidget);
    expect(find.text('Back camera'), findsNothing);
    expect(find.text('Front camera'), findsNothing);

    await tester.tap(find.byTooltip('Select camera'));
    await tester.pumpAndSettle();

    expect(find.text('Back camera'), findsOneWidget);
    expect(find.text('Front camera'), findsOneWidget);
    final menuItems = find.byType(CheckedPopupMenuItem<int>);
    expect(
      tester.widget<CheckedPopupMenuItem<int>>(menuItems.at(0)).checked,
      isTrue,
    );
    expect(
      tester.widget<CheckedPopupMenuItem<int>>(menuItems.at(1)).checked,
      isFalse,
    );

    await tester.tap(menuItems.at(1));
    expect(selectedIndex, 1);
  });
}
