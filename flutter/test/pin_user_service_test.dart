import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'fetches pins for the requested user when the current user has cached pins',
    () async {
      final repository = FakePinRepository({
        'current-user': [_pin('current-pin', 'current-user')],
        'profile-user': [],
      });
      final api = RecordingPinsApi();
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('current-user'),
          pinRepositoryProvider.overrideWithValue(repository),
          pinApiProvider.overrideWithValue(api),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      container.listen(pinUserServiceProvider('profile-user'), (_, _) {});

      await expectLater(
        api.requestStarted.future.timeout(const Duration(milliseconds: 100)),
        completes,
      );
      expect(api.requestedUserId, 'profile-user');
    },
  );
}

PinEntity _pin(String pinId, String creator) {
  return PinEntity(
    pinId: pinId,
    latitude: 0,
    longitude: 0,
    creationDate: DateTime(2024),
    creator: creator,
    groupId: 'group',
    ttl: DateTime(2024),
    onlySession: false,
  );
}

class RecordingPinsApi extends PinsApi {
  RecordingPinsApi() : super(ApiClient());

  final requestStarted = Completer<void>();
  String? requestedUserId;

  @override
  Future<PinsSyncDto?> getPinImagesByIds({
    List<String>? ids,
    String? groupId,
    String? userId,
    bool? withImage,
    int? compression,
    int? height,
    int? page,
    int? size,
    DateTime? updatedAfter,
  }) async {
    requestedUserId = userId;
    requestStarted.complete();
    return PinsSyncDto();
  }
}

class FakePinRepository implements IPinRepository {
  FakePinRepository(this._pinsByUser);

  final Map<String, List<PinEntity>> _pinsByUser;

  @override
  Stream<List<PinEntity>> getPinsByUser(String userId) {
    return Stream.value(List.of(_pinsByUser[userId] ?? const []));
  }

  @override
  Future<void> putMultiple(List<PinEntity> items) async {
    for (final item in items) {
      (_pinsByUser[item.creator] ??= []).add(item);
    }
  }

  @override
  Future<void> put(PinEntity item) async {
    (_pinsByUser[item.creator] ??= []).add(item);
  }

  @override
  Stream<PinEntity?> watchById(String id) => Stream.value(null);

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<PinEntity?> get(String id) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<PinEntity>> getAll() async =>
      _pinsByUser.values.expand((e) => e).toList();

  @override
  Future<List<PinEntity?>> getList(List<String> ids) async => [];

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> deleteOldestItems() async {}

  @override
  Stream<List<PinEntity>> getPinsByGroup(String groupId) => Stream.value([]);

  @override
  Future<void> deleteByGroupId(String groupId) async {}

  @override
  Future<void> replacePin(String oldPinId, PinEntity newPin) async {}

  @override
  Future<void> updateKeepAlive(
    String groupId,
    bool keepAlive,
    bool onlySession,
  ) async {}
}
