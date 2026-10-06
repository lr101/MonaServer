import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'contributor profile includes an update on another user’s location',
    () async {
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('current-user'),
          pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
          pinApiProvider.overrideWithValue(
            _ContributorPinsApi(
              photoHistory: (_) async => [
                PinPhotoDto(
                  id: 'update',
                  pinId: 'place',
                  contributorId: 'updater',
                  contributorUsername: 'updater',
                  observedAt: DateTime.utc(2026, 2),
                  isOriginal: false,
                ),
              ],
            ),
          ),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);
      final entries = await _waitForEntries(
        container,
        userPinEntriesProvider('updater'),
        (entries, _) => entries.any((entry) => entry.entryId == 'update'),
      );
      expect(entries.map((entry) => entry.entryId), ['update']);
      expect(entries.single.pinId, 'place');
    },
  );

  test(
    'current user profile reads prewarmed entries without network requests',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _ContributorPinsApi();
      final container = ProviderContainer(
        overrides: [
          accountDatabaseProvider.overrideWithValue(db),
          userIdProvider.overrideWithValue('updater'),
          pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
          pinApiProvider.overrideWithValue(api),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(pinRepositoryProvider)
          .put(
            PinEntity(
              pinId: 'place',
              latitude: 48.1,
              longitude: 11.6,
              creationDate: DateTime.utc(2026),
              creator: 'original-author',
              groupId: 'group',
              ttl: DateTime.now(),
              onlySession: false,
              keepAlive: true,
            ),
          );
      await container.read(pinPhotoHistoryRepositoryProvider).putMultiple({
        'place': [_photoUpdate('update', 'place')],
      });
      await container
          .read(userPinsRepositoryProvider)
          .put(
            UserPinsEntity(
              userId: 'updater',
              pins: ['place'],
              ttl: DateTime.now(),
              onlySession: false,
              keepAlive: true,
            ),
          );

      final entries = await _waitForEntries(
        container,
        userPinEntriesProvider('updater'),
        (entries, _) => entries.any((entry) => entry.entryId == 'update'),
      );

      expect(entries.single.photoUrl, 'https://example.test/update.png');
      expect(entries.single.entryId, 'update');
      expect(api.pinQueries, 0);
      expect(api.photoRequests, isEmpty);
    },
  );

  test('current user profile emits newly indexed pins with the same sync watermark', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final watermark = DateTime.utc(2026, 2);
    final container = ProviderContainer(
      overrides: [
        accountDatabaseProvider.overrideWithValue(db),
        userIdProvider.overrideWithValue('updater'),
        pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
        pinApiProvider.overrideWithValue(_ContributorPinsApi()),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);

    final pins = container.read(pinRepositoryProvider);
    final profile = container.read(userPinsRepositoryProvider);
    await pins.put(_profilePin('first'));
    await pins.put(_profilePin('new-pin'));
    await profile.put(
      UserPinsEntity(
        userId: 'updater',
        pins: ['first'],
        ttl: watermark,
        onlySession: false,
        keepAlive: true,
      ),
    );

    final firstEmission = Completer<List<PinEntity>>();
    final newPinEmission = Completer<List<PinEntity>>();
    final subscription = container.listen(userPinEntriesProvider('updater'), (
      _,
      next,
    ) {
      if (next case AsyncData<List<PinEntity>>(:final value)) {
        if (!firstEmission.isCompleted) firstEmission.complete(value);
        if (value.any((entry) => entry.pinId == 'new-pin') &&
            !newPinEmission.isCompleted) {
          newPinEmission.complete(value);
        }
      } else if (next case AsyncError<List<PinEntity>>(:final error)) {
        if (!firstEmission.isCompleted) firstEmission.completeError(error);
        if (!newPinEmission.isCompleted) newPinEmission.completeError(error);
      }
    });
    addTearDown(subscription.close);

    expect(
      (await firstEmission.future.timeout(const Duration(seconds: 5)))
          .map((entry) => entry.pinId),
      ['first'],
    );
    await profile.put(
      UserPinsEntity(
        userId: 'updater',
        pins: ['first', 'new-pin'],
        ttl: watermark,
        onlySession: false,
        keepAlive: true,
      ),
    );

    final entries = await newPinEmission.future.timeout(
      const Duration(seconds: 5),
    );
    expect(entries.map((entry) => entry.pinId).toSet(), {'first', 'new-pin'});
  });

  test('current user profile emits newly cached photo updates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        accountDatabaseProvider.overrideWithValue(db),
        userIdProvider.overrideWithValue('updater'),
        pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
        pinApiProvider.overrideWithValue(_ContributorPinsApi()),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pinRepositoryProvider).put(_profilePin('place'));
    await container
        .read(userPinsRepositoryProvider)
        .put(
          UserPinsEntity(
            userId: 'updater',
            pins: ['place'],
            ttl: DateTime.utc(2026, 2),
            onlySession: false,
            keepAlive: true,
          ),
        );
    final history = container.read(pinPhotoHistoryRepositoryProvider);
    await history.putMultiple({'place': const []});

    final photoHistoryChanged = Completer<void>();
    final historySubscription = container.listen(
      profilePhotoHistoryRevisionProvider,
      (_, next) {
        if (next case AsyncData<int>(:final value)
            when value > 1 && !photoHistoryChanged.isCompleted) {
          photoHistoryChanged.complete();
        }
      },
    );
    addTearDown(historySubscription.close);
    final directHistoryChange = history.watchChanges().firstWhere(
      (revision) => revision > 1,
    );
    await Future<void>.delayed(Duration.zero);

    final initialEmission = Completer<List<PinEntity>>();
    final updateEmission = Completer<List<PinEntity>>();
    final subscription = container.listen(userPinEntriesProvider('updater'), (
      _,
      next,
    ) {
      if (next case AsyncData<List<PinEntity>>(:final value)) {
        if (!initialEmission.isCompleted) initialEmission.complete(value);
        if (value.any((entry) => entry.entryId == 'new-update') &&
            !updateEmission.isCompleted) {
          updateEmission.complete(value);
        }
      } else if (next case AsyncError<List<PinEntity>>(:final error)) {
        if (!updateEmission.isCompleted) updateEmission.completeError(error);
      }
    });
    addTearDown(subscription.close);

    expect(
      (await initialEmission.future.timeout(const Duration(seconds: 5)))
          .map((entry) => entry.entryId),
      ['place'],
    );
    await history.putMultiple({
      'place': [_photoUpdate('new-update', 'place')],
    });

    await directHistoryChange.timeout(const Duration(seconds: 5));
    await photoHistoryChanged.future.timeout(const Duration(seconds: 5));
    final entries = await updateEmission.future.timeout(
      const Duration(seconds: 5),
    );
    expect(entries.map((entry) => entry.entryId).toSet(), {
      'place',
      'new-update',
    });
    final update = entries.singleWhere(
      (entry) => entry.entryId == 'new-update',
    );
    expect(update.photoUrl, 'https://example.test/update.png');
  });

  test('cached originals appear while update history is pending', () async {
    final history = Completer<List<PinPhotoDto>>();
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('current-user'),
        pinUserServiceProvider('original-author').overrideWith(_EmptyPins.new),
        pinApiProvider.overrideWithValue(
          _ContributorPinsApi(photoHistory: (_) => history.future),
        ),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    final provider = userPinEntriesProvider('original-author');
    final entries = await _waitForEntries(
      container,
      provider,
      (entries, _) => entries.any((entry) => entry.entryId == 'place'),
    );
    expect(entries.map((entry) => entry.entryId), ['place']);
    history.complete([]);
  });

  test(
    'profile update entries are emitted together after photo history loads',
    () async {
      final histories = {
        'place-a': Completer<List<PinPhotoDto>>(),
        'place-b': Completer<List<PinPhotoDto>>(),
      };
      final requestsStarted = Completer<void>();
      var startedCount = 0;
      final api = _ContributorPinsApi(
        items: [_pinDto('place-a'), _pinDto('place-b')],
        photoHistory: (pinId) {
          startedCount++;
          if (startedCount == histories.length &&
              !requestsStarted.isCompleted) {
            requestsStarted.complete();
          }
          return histories[pinId]!.future;
        },
      );
      final container = ProviderContainer(
        overrides: [
          userIdProvider.overrideWithValue('current-user'),
          pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
          pinApiProvider.overrideWithValue(api),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      final emittedUpdateIds = <Set<String>>[];
      final allUpdatesEmitted = Completer<void>();
      final subscription = container.listen(userPinEntriesProvider('updater'), (
        _,
        next,
      ) {
        if (next case AsyncData<List<PinEntity>>(:final value)) {
          final updateIds = value
              .where((entry) => entry.isPhotoUpdate)
              .map((entry) => entry.entryId)
              .toSet();
          if (updateIds.isNotEmpty) {
            emittedUpdateIds.add(updateIds);
            if (updateIds.length == histories.length &&
                !allUpdatesEmitted.isCompleted) {
              allUpdatesEmitted.complete();
            }
          }
        }
      });
      addTearDown(subscription.close);

      // Wait until both requests have been started by the profile provider.
      await requestsStarted.future.timeout(const Duration(seconds: 5));

      histories['place-a']!.complete([_photoUpdate('update-a', 'place-a')]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(emittedUpdateIds, isEmpty);

      histories['place-b']!.complete([_photoUpdate('update-b', 'place-b')]);
      await allUpdatesEmitted.future.timeout(const Duration(seconds: 5));
      expect(emittedUpdateIds, [
        {'update-a', 'update-b'},
      ]);
    },
  );

  test('remote refresh preserves an unsynced local draft', () async {
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('current-user'),
        pinUserServiceProvider('updater').overrideWith(_DraftPins.new),
        pinApiProvider.overrideWithValue(_ContributorPinsApi(items: const [])),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    final provider = userPinEntriesProvider('updater');
    final entries = await _waitForEntries(
      container,
      provider,
      (entries, emission) =>
          emission >= 2 && entries.any((entry) => entry.entryId == 'draft'),
    );
    expect(entries.map((entry) => entry.entryId), ['draft']);
  });

  test('a refreshed parent fetches newly added photo history', () async {
    var hasUpdate = false;
    var historyRequests = 0;
    final firstHistory = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWithValue('current-user'),
        pinUserServiceProvider('updater').overrideWith(_EmptyPins.new),
        pinApiProvider.overrideWithValue(
          _ContributorPinsApi(
            photoHistory: (_) async {
              historyRequests++;
              if (!firstHistory.isCompleted) firstHistory.complete();
              return hasUpdate
                  ? [
                      PinPhotoDto(
                        id: 'new-update',
                        pinId: 'place',
                        contributorId: 'updater',
                        contributorUsername: 'updater',
                        observedAt: DateTime.utc(2026, 2),
                        isOriginal: false,
                      ),
                    ]
                  : <PinPhotoDto>[];
            },
          ),
        ),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    final provider = userPinEntriesProvider('updater');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await firstHistory.future.timeout(const Duration(seconds: 5));
    final previousRequests = historyRequests;
    final updatedEntries = _waitForEntries(
      container,
      provider,
      (entries, _) => entries.any((entry) => entry.entryId == 'new-update'),
    );
    hasUpdate = true;
    container.invalidate(pinUserServiceProvider('updater'));
    final entries = await updatedEntries;
    expect(entries.map((entry) => entry.entryId), ['new-update']);
    expect(historyRequests, greaterThan(previousRequests));
  });

  test('one map location becomes separate original and update entries', () {
    final pin = PinEntity(
      pinId: 'place',
      latitude: 48.1,
      longitude: 11.6,
      creationDate: DateTime.utc(2026),
      creator: 'original-author',
      groupId: 'group',
      ttl: DateTime.utc(2027),
      onlySession: false,
    );
    final photos = <String, List<PinPhotoDto>>{
      'place': [
        PinPhotoDto(
          id: 'place',
          pinId: 'place',
          contributorUsername: 'original',
          contributorId: 'original-author',
          observedAt: DateTime.utc(2026),
          isOriginal: true,
        ),
        PinPhotoDto(
          id: 'update',
          pinId: 'place',
          contributorUsername: 'updater',
          contributorId: 'update-author',
          image: 'https://example.test/update.png',
          caption: 'Still here',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
        ),
      ],
    };

    final groupEntries = buildPinEntries([pin], photos);
    expect(groupEntries.map((entry) => entry.entryId), ['update', 'place']);
    expect(groupEntries.map((entry) => entry.pinId), ['place', 'place']);
    expect(groupEntries.first.creator, 'update-author');
    expect(groupEntries.first.description, 'Still here');

    final updaterEntries = buildPinEntries(
      [pin],
      photos,
      contributorId: 'update-author',
    );
    expect(updaterEntries.map((entry) => entry.entryId), ['update']);
    expect(
      buildPinEntries(
        [pin],
        photos,
        contributorId: 'original-author',
      ).map((entry) => entry.entryId),
      ['place'],
    );
  });
}

Future<List<PinEntity>> _waitForEntries(
  ProviderContainer container,
  StreamProvider<List<PinEntity>> provider,
  bool Function(List<PinEntity>, int) matches,
) async {
  final result = Completer<List<PinEntity>>();
  var emission = 0;
  final subscription = container.listen(provider, (_, next) {
    if (next case AsyncData<List<PinEntity>>(:final value)) {
      emission++;
      if (!result.isCompleted && matches(value, emission)) {
        result.complete(value);
      }
    } else if (next case AsyncError<List<PinEntity>>(:final error)) {
      if (!result.isCompleted) {
        result.completeError(error);
      }
    }
  });
  try {
    return await result.future.timeout(const Duration(seconds: 5));
  } finally {
    subscription.close();
  }
}

class _EmptyPins extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) => Stream.value([]);
}

class _DraftPins extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) => Stream.value([
    PinEntity(
      pinId: 'draft',
      latitude: 48.1,
      longitude: 11.6,
      creationDate: DateTime.utc(2026),
      creator: userId,
      groupId: 'group',
      ttl: DateTime.utc(2027),
      onlySession: false,
    ),
  ]);
}

class _ContributorPinsApi extends PinsApi {
  _ContributorPinsApi({this.items, this.photoHistory}) : super(ApiClient());

  final List<PinWithOptionalImageDto>? items;
  final Future<List<PinPhotoDto>?> Function(String)? photoHistory;
  int pinQueries = 0;
  final photoRequests = <String>[];

  @override
  Future<List<PinPhotoDto>?> getPinPhotos(String pinId) {
    photoRequests.add(pinId);
    return photoHistory?.call(pinId) ?? Future.value(const <PinPhotoDto>[]);
  }

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
    DateTime? beforeCreationDate,
    String? beforeId,
  }) async {
    pinQueries++;
    return PinsSyncDto(
      items:
          items ??
          [
            PinWithOptionalImageDto(
              id: 'place',
              creationDate: DateTime.utc(2026),
              latitude: 48.1,
              longitude: 11.6,
              creationUser: 'original-author',
              groupId: 'group',
            ),
          ],
    );
  }
}

PinWithOptionalImageDto _pinDto(String id) => PinWithOptionalImageDto(
  id: id,
  creationDate: DateTime.utc(2026),
  latitude: 48.1,
  longitude: 11.6,
  creationUser: 'original-author',
  groupId: 'group',
);

PinEntity _profilePin(String id) => PinEntity(
  pinId: id,
  latitude: 48.1,
  longitude: 11.6,
  creationDate: DateTime.utc(2026),
  creator: 'updater',
  groupId: 'group',
  lastSynced: DateTime.utc(2026),
  ttl: DateTime.utc(2027),
  onlySession: false,
  keepAlive: true,
);

PinPhotoDto _photoUpdate(String id, String pinId) => PinPhotoDto(
  id: id,
  pinId: pinId,
  contributorId: 'updater',
  contributorUsername: 'updater',
  image: 'https://example.test/update.png',
  observedAt: DateTime.utc(2026, 2),
  isOriginal: false,
);
