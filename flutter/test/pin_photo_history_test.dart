import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:camera/camera.dart';
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('upload photo still picks from the gallery', (tester) async {
    final originalPicker = ImagePickerPlatform.instance;
    final picker = _PinGalleryPlatform(
      XFile.fromData(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 10))),
      ),
    );
    ImagePickerPlatform.instance = picker;
    addTearDown(() => ImagePickerPlatform.instance = originalPicker);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinApiProvider.overrideWithValue(_FakePinsApi())],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PinPhotoHistoryPanel(
                pin: _pin(),
                userPosition: _position(50, 8),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload photo'));
    await _waitForComposer(tester);

    expect(picker.requestedSource, ImageSource.gallery);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('captured pin photo opens the existing update composer', (
    tester,
  ) async {
    const cameraDescription = CameraDescription(
      name: 'pin-camera',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );
    final originalPlatform = CameraPlatform.instance;
    CameraPlatform.instance = _PinCameraPlatform(cameraDescription);
    final controller = _PinCameraController(cameraDescription);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _FakePinsApi();
    addTearDown(() async {
      CameraPlatform.instance = originalPlatform;
      await controller.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'walker',
              refreshToken: null,
              cameras: [cameraDescription],
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          cameraControllerProvider.overrideWith(
            (ref) => Future.value(controller),
          ),
          pinApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PinPhotoHistoryPanel(
                pin: _pin(),
                userPosition: _position(50, 8),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Upload photo'), findsOneWidget);

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Take pin photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Take photo'));
    await _waitForComposer(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Still standing');
    await tester.tap(find.text('Share update'));
    await tester.pumpAndSettle();
    expect(api.submittedPinId, 'pin');
    expect(api.submitted?.caption, 'Still standing');
    expect(api.submitted?.image, isNotEmpty);
    expect(api.submitted?.latitude, 50);
    expect(api.submitted?.longitude, 8);
    expect(api.submitted?.accuracyMeters, 5);

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Take photo'))
          .onPressed,
      isNotNull,
    );
  });

  test('photo updates require a synced nearby pin and usable accuracy', () {
    final pin = _pin();

    expect(canAddPinPhotoHere(_position(50, 8, accuracy: 50), pin), isTrue);
    expect(canAddPinPhotoHere(_position(50.001, 8), pin), isFalse);
    expect(canAddPinPhotoHere(_position(50, 8, accuracy: 50.1), pin), isFalse);
    expect(canAddPinPhotoHere(null, pin), isFalse);
    expect(canAddPinPhotoHere(_position(50, 8), _pin(synced: false)), isFalse);
  });

  test('photo DTO accepts a missing image URL', () {
    final photo = PinPhotoDto.fromJson({
      'id': 'photo',
      'pinId': 'pin',
      'contributorUsername': 'walker',
      'observedAt': DateTime.utc(2026).toIso8601String(),
      'isOriginal': true,
    });

    expect(photo, isNotNull);
    expect(photo!.image, isNull);
  });

  testWidgets('photo history shows contributors and disables distant uploads', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pinApiProvider.overrideWithValue(_FakePinsApi())],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PinPhotoHistoryPanel(
                pin: _pin(),
                userPosition: _position(50.001, 8),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original pin photo'), findsOneWidget);
    expect(find.text('Update by walker'), findsOneWidget);
    expect(find.text('The sign is still here'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(
      find.text('Get within 50 m of this pin to add a photo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Take photo'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Upload photo'),
          )
          .onPressed,
      isNull,
    );
  });

  test(
    'photo upload retry preserves its exact request until success',
    () async {
      final session = PinPhotoUploadRetry();
      final request = PinPhotoRequestDto(
        image: 'encoded photo',
        idempotencyKey: 'retry-key',
        latitude: 50,
        longitude: 8,
        accuracyMeters: 5,
        caption: 'Still here',
      );
      final submitted = <PinPhotoRequestDto>[];
      session.prepare(request);

      await expectLater(
        session.submit((request) {
          submitted.add(request);
          return Future<PinPhotoDto?>.error(
            StateError('response lost after server committed'),
          );
        }),
        throwsA(isA<StateError>()),
      );

      expect(session.pendingRequest, same(request));
      await session.submit((request) async {
        submitted.add(request);
        return null;
      });

      expect(submitted, hasLength(2));
      expect(submitted[0], same(request));
      expect(submitted[1], same(request));
      expect(session.pendingRequest, isNull);
    },
  );

  test(
    'photo upload clears definitive client failures but keeps ambiguous ones',
    () {
      final session = PinPhotoUploadRetry();
      final request = PinPhotoRequestDto(
        image: 'encoded photo',
        idempotencyKey: 'retry-key',
        latitude: 50,
        longitude: 8,
        accuracyMeters: 5,
      );

      session.prepare(request);
      session.handleApiFailure(ApiException(403, 'outside the allowed range'));
      expect(session.pendingRequest, isNull);

      session.prepare(request);
      session.handleApiFailure(
        ApiException.withInner(
          400,
          'connection failed',
          Exception('connection reset after request was sent'),
          StackTrace.current,
        ),
      );
      expect(session.pendingRequest, same(request));

      session.handleApiFailure(ApiException(503, 'temporary server failure'));
      expect(session.pendingRequest, same(request));
    },
  );
}

Future<void> _waitForComposer(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    if (find.byType(AlertDialog).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

PinEntity _pin({bool synced = true}) => PinEntity(
  pinId: 'pin',
  latitude: 50,
  longitude: 8,
  creationDate: DateTime.utc(2026),
  creator: 'user',
  groupId: 'group',
  isGone: true,
  lastSynced: synced ? DateTime.utc(2026) : null,
  ttl: DateTime.utc(2099),
  onlySession: false,
);

Position _position(double latitude, double longitude, {double accuracy = 5}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakePinsApi extends PinsApi {
  _FakePinsApi() : super(ApiClient());

  String? submittedPinId;
  PinPhotoRequestDto? submitted;

  @override
  Future<PinPhotoDto?> addPinPhoto(
    String pinId,
    PinPhotoRequestDto pinPhotoRequestDto,
  ) async {
    submittedPinId = pinId;
    submitted = pinPhotoRequestDto;
    return null;
  }

  @override
  Future<List<PinPhotoDto>?> getPinPhotos(String pinId) async => [
    PinPhotoDto(
      id: 'original',
      pinId: pinId,
      contributorUsername: 'walker',
      image: 'https://example.test/original.png',
      caption: 'The sign is still here',
      observedAt: DateTime.utc(2026),
      isOriginal: true,
    ),
    PinPhotoDto(
      id: 'later',
      pinId: pinId,
      contributorUsername: 'walker',
      image: 'https://example.test/update.png',
      observedAt: DateTime.utc(2026, 1, 2),
      isOriginal: false,
    ),
  ];
}

class _PinCameraPlatform extends CameraPlatform {
  _PinCameraPlatform(this.camera);

  final CameraDescription camera;

  @override
  Future<List<CameraDescription>> availableCameras() async => [camera];
}

class _PinCameraController extends CameraController {
  _PinCameraController(CameraDescription camera)
    : super(camera, ResolutionPreset.low, enableAudio: false) {
    value = CameraValue(
      isInitialized: true,
      previewSize: const Size(16, 9),
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      flashMode: FlashMode.auto,
      exposureMode: ExposureMode.auto,
      exposurePointSupported: false,
      focusMode: FocusMode.auto,
      focusPointSupported: false,
      deviceOrientation: DeviceOrientation.portraitUp,
      description: camera,
    );
  }

  @override
  Widget buildPreview() => const SizedBox.expand();

  @override
  Future<double> getMinZoomLevel() async => 1;

  @override
  Future<double> getMaxZoomLevel() async => 1;

  @override
  Future<void> resumePreview() async {}

  @override
  Future<XFile> takePicture() async => XFile.fromData(
    Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 10))),
    name: 'pin-update.jpg',
  );
}

class _PinGalleryPlatform extends ImagePickerPlatform {
  _PinGalleryPlatform(this.image);

  final XFile image;
  ImageSource? requestedSource;

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse();

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    requestedSource = source;
    return image;
  }
}
