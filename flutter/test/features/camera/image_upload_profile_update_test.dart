import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/camera/data/camera_state.dart';
import 'package:buff_lisa/features/camera/presentation/image_upload.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets(
    'adding a photo to another user’s pin immediately publishes it on profile',
    (tester) async {
      final previousGeolocator = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _FixedGeolocator(_nearbyPosition());
      addTearDown(() => GeolocatorPlatform.instance = previousGeolocator);

      final database = AppDatabase(NativeDatabase.memory());
      final profileRepository = UserPinsRepository(database);
      final syncWatermark = DateTime.utc(2026, 2);
      await profileRepository.put(
        UserPinsEntity(
          userId: 'updater',
          pins: const [],
          ttl: syncWatermark,
          keepAlive: true,
          onlySession: false,
        ),
      );

      final pin = _originalPin();
      final group = GroupEntity(
        groupId: 'group-id',
        name: 'Sample group',
        visibility: 0,
        userIsMember: true,
        ttl: DateTime.utc(2027),
        onlySession: false,
      );
      final api = _PhotoUploadApi();
      final container = ProviderContainer(
        overrides: [
          accountDatabaseProvider.overrideWithValue(database),
          userIdProvider.overrideWithValue('updater'),
          pinApiProvider.overrideWithValue(api),
          cameraSelectedGroupProvider.overrideWith((_) => Future.value(group)),
          groupOrderServiceProvider.overrideWithValue(const ['group-id']),
          groupDetailsPinsProvider('group-id')
              .overrideWithValue(AsyncData<List<PinEntity>?>([pin])),
          pinImageForDetailsProvider('place')
              .overrideWith((_) => Future<Uint8List?>.value()),
          groupProfilePictureSmallByIdProvider('group-id')
              .overrideWith((_) => Stream.value(kTransparentImage)),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );

      final profileUpdate = Completer<List<PinEntity>>();
      final profileSubscription = container.listen(
        userPinEntriesProvider('updater'),
        (_, next) {
          if (next case AsyncData<List<PinEntity>>(:final value)
              when value.any((entry) => entry.entryId == 'photo-update')) {
            if (!profileUpdate.isCompleted) profileUpdate.complete(value);
          } else if (next case AsyncError<List<PinEntity>>(:final error)) {
            if (!profileUpdate.isCompleted) profileUpdate.completeError(error);
          }
        },
      );

      addTearDown(() async {
        profileSubscription.close();
        container.dispose();
        await database.close();
        GeolocatorPlatform.instance = previousGeolocator;
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ImageUpload(
              image: Uint8List.fromList(kTransparentImage),
              position: const LatLng(50, 8),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Old place'), findsOneWidget);
      await tester.tap(find.text('Old place'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Add photo update'), findsOneWidget);

      await tester.tap(find.text('Add photo update'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(api.uploadedPinIds, ['place']);
      final entries = (await tester.runAsync(
        () => profileUpdate.future.timeout(const Duration(seconds: 5)),
      ))!;
      final update = entries.singleWhere(
        (entry) => entry.entryId == 'photo-update',
      );
      expect(update.pinId, 'place');
      expect(update.creator, 'updater');
      expect(update.photoUrl, 'https://example.test/photo-update.png');
      expect(
        await container.read(pinRepositoryProvider).get('place'),
        isNotNull,
      );

      final indexedProfile = await profileRepository.get('updater');
      expect(indexedProfile?.pins, ['place']);
      expect(
        indexedProfile?.ttl.millisecondsSinceEpoch,
        syncWatermark.millisecondsSinceEpoch,
      );
    },
  );
}

class _FixedGeolocator extends GeolocatorPlatform {
  _FixedGeolocator(this.position);

  final Position position;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => position;
}

class _PhotoUploadApi extends PinsApi {
  _PhotoUploadApi() : super(ApiClient());

  final uploadedPinIds = <String>[];

  @override
  Future<PinPhotoDto?> addPinPhoto(
    String pinId,
    PinPhotoRequestDto pinPhotoRequestDto,
  ) async {
    uploadedPinIds.add(pinId);
    return PinPhotoDto(
      id: 'photo-update',
      pinId: pinId,
      contributorId: 'updater',
      contributorUsername: 'updater',
      image: 'https://example.test/photo-update.png',
      observedAt: DateTime.utc(2026, 3),
      isOriginal: false,
    );
  }

  @override
  Future<List<PinPhotoDto>?> getPinPhotos(String pinId) async => [
    PinPhotoDto(
      id: 'photo-update',
      pinId: pinId,
      contributorId: 'updater',
      contributorUsername: 'updater',
      image: 'https://example.test/photo-update.png',
      observedAt: DateTime.utc(2026, 3),
      isOriginal: false,
    ),
  ];
}

class _EmptyPins extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) => Stream.value([]);
}

PinEntity _originalPin() => PinEntity(
  pinId: 'place',
  latitude: 50,
  longitude: 8,
  creationDate: DateTime.utc(2026),
  title: 'Old place',
  creator: 'original-author',
  groupId: 'group-id',
  lastSynced: DateTime.utc(2026),
  ttl: DateTime.utc(2027),
  onlySession: false,
  keepAlive: true,
);

Position _nearbyPosition() => Position(
  longitude: 8,
  latitude: 50,
  timestamp: DateTime.utc(2026, 3),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);
