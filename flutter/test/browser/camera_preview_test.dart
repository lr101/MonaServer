@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:camera_web/camera_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('browser camera opens an in-app preview and captures an image', (
    tester,
  ) async {
    CameraPlugin.registerWith(webPluginRegistrar);
    final devices = web.window.navigator.mediaDevices;
    final original = devices.getProperty<JSFunction>('getUserMedia'.toJS);
    var requests = 0;
    devices.setProperty(
      'getUserMedia'.toJS,
      ((JSAny constraints) {
        requests++;
        return original.callAsFunction(devices, constraints);
      }).toJS,
    );
    addTearDown(() => devices.setProperty('getUserMedia'.toJS, original));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        globalDataOnceProvider.overrideWithValue(
          const GlobalDataDto(userId: null, refreshToken: null, cameras: []),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        groupOrderServiceProvider.overrideWithValue([]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Camera()),
      ),
    );
    // Real getUserMedia and HTML video via camera_web. Run Chromium with
    // --use-fake-device-for-media-stream --use-fake-ui-for-media-stream.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (container.read(cameraValuesProvider).hasValue) break;
    }
    final values = container.read(cameraValuesProvider);
    expect(values.hasValue, isTrue, reason: values.toString());
    expect(
      requests,
      2,
      reason: 'Only permission and selected-camera streams should open',
    );
    expect(find.byTooltip('Select camera'), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    final controller = await container.read(cameraControllerProvider.future);
    final bytes = await tester.runAsync(() async {
      final picture = await controller.takePicture().timeout(
        const Duration(seconds: 10),
      );
      return picture.readAsBytes().timeout(const Duration(seconds: 10));
    });
    expect(bytes, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
