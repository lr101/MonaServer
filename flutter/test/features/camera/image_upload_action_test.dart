import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/camera/data/app_review_state.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/image_upload.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  setUp(() {
    final previous = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _NoLocation();
    addTearDown(() => GeolocatorPlatform.instance = previous);
  });

  testWidgets(
    'approval action floats above content and stays visible above the keyboard',
    (tester) async {
      await _pump(tester);
      final scroll = find.byType(SingleChildScrollView).first;
      expect(tester.getBottomRight(scroll).dy, 851);
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('approval-upload-action')))
            .dx,
        closeTo(196.5, 2),
      );
      await _pump(tester, keyboard: 250);
      expect(find.text('Upload'), findsOneWidget);
      expect(tester.getBottomRight(find.text('Upload')).dy, lessThan(601));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing group gives visible feedback and leaves approval retryable',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group before uploading.'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group before uploading.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unexpected approval errors do not leave the upload action locked',
    (tester) async {
      final service = _PendingSave();
      await _pump(tester, groups: ['group-id'], service: service, userId: null);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save this photo. Please try again.'),
        findsOneWidget,
      );
      expect(service.calls, 0);
      await _pump(tester, groups: ['group-id'], service: service);
      await tester.tap(find.text('Upload'));
      await tester.pump();
      expect(service.calls, 1);
      service.pending.complete('Unavailable');
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a saved photo cannot be submitted again while approval is closing',
    (tester) async {
      final service = _PendingSave();
      await _pump(tester, groups: ['group-id'], service: service);
      await tester.tap(find.text('Upload'));
      await tester.pump();
      service.pending.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Saving photo…'), findsOneWidget);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => !field.enabled),
        isTrue,
      );
      await tester.tap(find.text('Saving photo…'));
      await tester.pump();
      expect(service.calls, 1);
    },
  );
  testWidgets(
    'saving shows progress, prevents duplicate saves and recovers for retry',
    (tester) async {
      final service = _PendingSave();
      await _pump(tester, groups: ['group-id'], service: service);
      await tester.tap(find.text('Upload'));
      await tester.pump();
      expect(service.calls, 1);
      expect(find.text('Saving photo…'), findsOneWidget);
      await tester.tap(find.text('Saving photo…'));
      await tester.pump();
      expect(service.calls, 1);
      service.pending.completeError(StateError('Local storage failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save post on this device. Please try again.'),
        findsOneWidget,
      );
      service.pending = Completer<String?>();
      await tester.tap(find.text('Upload'));
      await tester.pump();
      expect(service.calls, 2);
      service.pending.complete('Still unavailable');
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  double keyboard = 0,
  List<String> groups = const [],
  _PendingSave? service,
  String? userId = 'viewer',
}) async {
  tester.view.physicalSize = const Size(393, 851);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraSelectedGroupProvider.overrideWith((_) => Future.value()),
        groupOrderServiceProvider.overrideWithValue(groups),
        globalDataOnceProvider.overrideWithValue(
          GlobalDataDto(userId: userId, refreshToken: null, cameras: const []),
        ),
        appReviewStateProvider.overrideWith(_NoReview.new),
        if (service != null) pinServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 851),
            padding: const EdgeInsets.only(bottom: 24),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: ImageUpload(
            image: Uint8List.fromList(kTransparentImage),
            position: const LatLng(48, 11),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoLocation extends GeolocatorPlatform {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Future.error(StateError('No location'));
}

class _NoReview extends AppReviewState {
  @override
  bool build() => false;
}

class _PendingSave implements PinService {
  int calls = 0;
  Completer<String?> pending = Completer<String?>();
  @override
  Future<String?> addPinToGroup(PinEntity pin, Uint8List image) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
