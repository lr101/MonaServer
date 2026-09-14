import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CameraPlatform extends CameraPlatform {
  Completer<List<CameraDescription>> discovery = Completer();

  @override
  Future<List<CameraDescription>> availableCameras() => discovery.future;
}

void main() {
  late _CameraPlatform platform;
  late CameraPlatform original;
  late SharedPreferences preferences;

  setUp(() async {
    original = CameraPlatform.instance;
    platform = _CameraPlatform();
    CameraPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(() => CameraPlatform.instance = original);

  Future<void> openCamera(WidgetTester tester) {
    platform.discovery = Completer();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(userId: null, refreshToken: null, cameras: []),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          groupOrderServiceProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(home: Camera()),
      ),
    );
  }

  testWidgets('opening camera waits for permission before showing no devices', (
    tester,
  ) async {
    await openCamera(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No cameras are available on this device.'), findsNothing);
    platform.discovery.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('No cameras are available on this device.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'denied camera access is distinct from no devices and can retry',
    (tester) async {
      await openCamera(tester);
      platform.discovery.completeError(
        CameraException('NotAllowedError', 'Permission denied'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow camera access'), findsOneWidget);
      expect(
        find.text('No cameras are available on this device.'),
        findsNothing,
      );
      platform.discovery = Completer();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      platform.discovery.complete([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No cameras are available on this device.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'leaving while permission is pending does not update disposed page',
    (tester) async {
      await openCamera(tester);
      await tester.pumpWidget(const SizedBox());
      platform.discovery.complete([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
