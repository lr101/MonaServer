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
          body: Align(
            alignment: Alignment.bottomRight,
            child: CameraSelectorButton(
              cameras: cameras,
              selectedIndex: 0,
              onSelected: (index) => selectedIndex = index,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Select camera'), findsOneWidget);
    expect(find.text('Back camera'), findsNothing);
    expect(find.text('Front camera'), findsNothing);

    await tester.tap(find.byTooltip('Select camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final openingPosition = tester.getTopLeft(find.text('Front camera'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Front camera')).dy,
      lessThan(openingPosition.dy),
    );
    expect(find.text('Back camera'), findsOneWidget);
    expect(find.text('Front camera'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Back camera'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Front camera'));
    expect(selectedIndex, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Front camera'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Front camera'), findsNothing);
    await tester.tap(find.byTooltip('Select camera'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(find.text('Back camera'), findsNothing);
    expect(selectedIndex, 1);
  });

  testWidgets('uses a dialog when the preview cannot fit the camera menu', (
    tester,
  ) async {
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
            maxMenuHeight: 0,
            onSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Select camera'));
    await tester.pumpAndSettle();
    expect(find.text('Back camera'), findsOneWidget);
    expect(find.text('Front camera'), findsOneWidget);

    await tester.tap(find.text('Front camera'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
    expect(find.text('Front camera'), findsNothing);
  });
}
