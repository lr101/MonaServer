import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/map_home/data/nearby_pin_cue.dart';
import 'package:buff_lisa/features/map_home/presentation/nearby_pin_cue_overlay.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects invalid or unreliable location readings', () {
    expect(hasCredibleNearbyLocation(_position(accuracy: 50)), isTrue);
    expect(hasCredibleNearbyLocation(_position(accuracy: 50.01)), isFalse);
    expect(
      hasCredibleNearbyLocation(_position(accuracy: 5, latitude: double.nan)),
      isFalse,
    );
  });

  test('requests visible pins around an accurate current location', () async {
    final api = _RecordingPinsApi();
    final positions = StreamController<Position>();
    final container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) => positions.stream),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(() async {
      await positions.close();
      container.dispose();
    });
    final result = _watchResults(container, api);

    positions.add(_position(accuracy: 50));
    final pins = await result.future;

    expect(pins, hasLength(1));
    expect(api.requestedLatitude, 51.5);
    expect(api.requestedLongitude, -0.12);
    expect(api.requestedRadius, 75);
  });

  test('does not query when the location estimate is too inaccurate', () async {
    final api = _RecordingPinsApi();
    final positions = StreamController<Position>();
    final container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) => positions.stream),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(() async {
      await positions.close();
      container.dispose();
    });
    final locationReady = Completer<void>();
    container.listen(currentLocationProvider, (previous, next) {
      if (next.value != null && !locationReady.isCompleted) {
        locationReady.complete();
      }
    });
    container.listen(nearbyPinCandidatesProvider, (previous, next) {});

    positions.add(_position(accuracy: 50.01));
    await locationReady.future;
    expect(await container.read(nearbyPinCandidatesProvider.future), isEmpty);
    expect(api.requestedRadius, isNull);
  });

  test('refreshes candidates when the user moves to a new location', () async {
    final api = _RecordingPinsApi();
    final positions = StreamController<Position>();
    final container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) => positions.stream),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(() async {
      await positions.close();
      container.dispose();
    });
    final firstResult = _watchResults(container, api);
    final secondResult = Completer<void>();
    container.listen(nearbyPinCandidatesProvider, (previous, next) {
      final candidates = next.whenOrNull(data: (value) => value);
      if (candidates != null &&
          candidates.isNotEmpty &&
          candidates.first.pin.latitude == 51.51 &&
          !secondResult.isCompleted) {
        secondResult.complete();
      }
    });

    positions.add(_position(accuracy: 5));
    await firstResult.future;
    positions.add(_position(accuracy: 5, latitude: 51.51));
    await secondResult.future;

    expect(api.requestCount, 2);
    expect(api.requestedLatitude, 51.51);
  });

  test('clears the cue candidates when the nearby request fails', () async {
    final api = _RecordingPinsApi(error: StateError('offline'));
    final positions = StreamController<Position>();
    final container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) => positions.stream),
        pinApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(() async {
      await positions.close();
      container.dispose();
    });
    final result = _watchResults(container, api);

    positions.add(_position(accuracy: 5));
    expect(await result.future, isEmpty);
  });

  testWidgets('nearby cue opens the pin and persists a daily dismissal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final openedPinIds = <String>[];
    final nearbyPin = _nearbyPin();

    Future<void> showCue() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyPinCandidatesProvider.overrideWith((ref) => [nearbyPin]),
            sharedPreferencesProvider.overrideWithValue(preferences),
            userIdProvider.overrideWithValue('walker-1'),
            groupMetadataProvider('group-1').overrideWith((ref) async* {
              yield null;
            }),
            groupPinImageByIdProvider('group-1')
                .overrideWith((ref) => Stream.value(null)),
            defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NearbyPinCueOverlay(onOpenPin: openedPinIds.add),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showCue();
    expect(find.text('Pin nearby'), findsOneWidget);
    expect(find.text('Walkers'), findsOneWidget);
    expect(find.text('21 m away'), findsOneWidget);

    await tester.tap(find.text('Walkers'));
    expect(openedPinIds, ['pin-1']);

    await tester.tap(find.byTooltip('Dismiss nearby pin for today'));
    await tester.pumpAndSettle();
    expect(find.text('Pin nearby'), findsNothing);
    expect(
      preferences.getString('nearbyPinCueDismissed:walker-1'),
      _dateStamp(DateTime.now()),
    );

    await showCue();
    expect(find.text('Pin nearby'), findsNothing);
  });
}

Completer<List<NearbyPinDto>> _watchResults(
  ProviderContainer container,
  _RecordingPinsApi api,
) {
  final result = Completer<List<NearbyPinDto>>();
  container.listen(nearbyPinCandidatesProvider, (previous, next) {
    final candidates = next.whenOrNull(data: (value) => value);
    if (api.requestedRadius != null &&
        candidates != null &&
        !result.isCompleted) {
      result.complete(candidates);
    }
  });
  return result;
}

Position _position({
  required double accuracy,
  double latitude = 51.5,
  double longitude = -0.12,
}) => Position(
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

NearbyPinDto _nearbyPin() => NearbyPinDto(
  pin: PinWithOptionalImageDto(
    id: 'pin-1',
    creationDate: DateTime.utc(2026),
    latitude: 51.5,
    longitude: -0.12,
    creationUser: 'creator',
    groupId: 'group-1',
  ),
  distanceMeters: 21,
  groupName: 'Walkers',
);

String _dateStamp(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _RecordingPinsApi extends PinsApi {
  _RecordingPinsApi({this.error}) : super(ApiClient());

  final Object? error;
  num? requestedLatitude;
  num? requestedLongitude;
  int? requestedRadius;
  int requestCount = 0;

  @override
  Future<NearbyPinsDto?> getNearbyPins(
    num latitude,
    num longitude,
    int radiusMeters,
  ) async {
    requestCount++;
    requestedLatitude = latitude;
    requestedLongitude = longitude;
    requestedRadius = radiusMeters;
    if (error != null) throw error!;
    return NearbyPinsDto(
      items: [
        NearbyPinDto(
          pin: PinWithOptionalImageDto(
            id: 'pin-1',
            creationDate: DateTime.utc(2026),
            latitude: latitude,
            longitude: longitude,
            creationUser: 'creator',
            groupId: 'group-1',
          ),
          distanceMeters: 21,
          groupName: 'Walkers',
        ),
      ],
    );
  }
}
