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
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_web/camera_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets(
    'pin update camera renders a live preview and captures an image',
    (tester) async {
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
          child: const MaterialApp(home: Camera(pinPhotoMode: true)),
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
      await tester.pumpAndSettle();
      final controller = await container.read(cameraControllerProvider.future);
      final plugin = CameraPlatform.instance as CameraPlugin;
      final camera = plugin.getCamera(controller.cameraId);
      final video = camera.videoElement;
      expect(video.videoWidth, greaterThan(0));
      expect(video.videoHeight, greaterThan(0));
      expect(video.paused, isFalse, reason: 'camera stream should be playing');
      expect(video.style.objectFit, 'cover');
      final canvas = web.HTMLCanvasElement()
        ..width = 16
        ..height = 16;
      final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      context.drawImage(video, 0, 0, 16, 16);
      final pixels = context.getImageData(0, 0, 16, 16).data;
      var litPixels = 0;
      for (var index = 0; index < 16 * 16; index++) {
        final red = pixels.getProperty<JSNumber>('${index * 4}'.toJS).toDartInt;
        final green = pixels
            .getProperty<JSNumber>('${index * 4 + 1}'.toJS)
            .toDartInt;
        final blue = pixels
            .getProperty<JSNumber>('${index * 4 + 2}'.toJS)
            .toDartInt;
        if (red + green + blue > 48) litPixels++;
      }
      expect(litPixels, greaterThan(0), reason: 'camera frames are not black');
      final frameSize = tester.getSize(
        find.byKey(const ValueKey('camera-preview-frame')),
      );
      expect(frameSize.height, closeTo(frameSize.width * 4 / 3, 0.1));
      expect(
        requests,
        2,
        reason: 'Only permission and selected-camera streams should open',
      );
      expect(find.byTooltip('Select camera'), findsOneWidget);
      expect(find.byTooltip('Choose from gallery'), findsOneWidget);
      expect(find.text('Take photo'), findsNothing);
      final bytes = await tester.runAsync(() async {
        final picture = await controller.takePicture().timeout(
          const Duration(seconds: 10),
        );
        return picture.readAsBytes().timeout(const Duration(seconds: 10));
      });
      expect(bytes, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
