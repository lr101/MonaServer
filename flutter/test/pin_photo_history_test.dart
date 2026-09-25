import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openapi/api.dart';

void main() {
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
    expect(
      find.text('Get within 50 m of this pin to add a photo.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add photo update'),
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

  @override
  Future<List<PinPhotoDto>?> getPinPhotos(String pinId) async => [
    PinPhotoDto(
      id: 'original',
      pinId: pinId,
      contributorUsername: 'walker',
      caption: 'The sign is still here',
      observedAt: DateTime.utc(2026),
      isOriginal: true,
    ),
    PinPhotoDto(
      id: 'later',
      pinId: pinId,
      contributorUsername: 'walker',
      observedAt: DateTime.utc(2026, 1, 2),
      isOriginal: false,
    ),
  ];
}
