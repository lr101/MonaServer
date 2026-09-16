import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/camera.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CameraPlatform extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];
}

void main() {
  testWidgets('leaving the camera clears an in-progress capture', (
    tester,
  ) async {
    final originalPlatform = CameraPlatform.instance;
    CameraPlatform.instance = _CameraPlatform();
    addTearDown(() => CameraPlatform.instance = originalPlatform);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
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
    container.read(cameraCapturingProvider.notifier).setCapturing(true);
    expect(container.read(cameraCapturingProvider), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(container.read(cameraCapturingProvider), isFalse);
  });
}
