import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test(
    'a cold profile downloads original thumbnails from its own photo metadata',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final batches = BatchReadCoalescer(
        read: (_) async => throw StateError('URL lookup unavailable'),
      );
      addTearDown(batches.dispose);
      final container = ProviderContainer(
        overrides: [
          batchReadCoalescerProvider.overrideWithValue(batches),
          accountDatabaseProvider.overrideWithValue(db),
          userIdProvider.overrideWithValue('original-author'),
          pinUserServiceProvider('original-author')
              .overrideWith(_EmptyPins.new),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(pinRepositoryProvider)
          .put(PinEntity.fromDto(_pinDto('place'), false));
      await container.read(pinPhotoHistoryRepositoryProvider).putMultiple({
        'place': [
          PinPhotoDto(
            id: 'original-photo',
            pinId: 'place',
            contributorId: 'original-author',
            contributorUsername: 'original-author',
            observedAt: DateTime.utc(2026),
            isOriginal: true,
            image: 'https://images.example/original.jpg',
            imageThumbnail: 'https://images.example/thumbnail.jpg',
          ),
        ],
      });
      await container
          .read(userPinsRepositoryProvider)
          .put(
            UserPinsEntity(
              userId: 'original-author',
              pins: ['place'],
              ttl: DateTime.now(),
              onlySession: false,
            ),
          );
      final entries = await _waitForEntries(
        container,
        userPinEntriesProvider('original-author'),
        (entries, _) => entries.isNotEmpty,
      );
      final source = await container.read(pinImageSourcesProvider).resolve((
        pinId: entries.single.pinId,
        photoId: null,
        thumbnailUrl: null,
        imageUrl: null,
        attempt: 0,
      ));
      expect(source?.url, 'https://images.example/thumbnail.jpg');
    },
  );

  test(
    'original metadata arriving later becomes available to the shared resolver',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final registry = SuppliedImageUrlRegistry();
      final batch = BatchReadCoalescer(
        window: Duration.zero,
        read: (_) async => throw StateError('URL lookup unavailable'),
      );
      addTearDown(registry.dispose);
      addTearDown(batch.dispose);
      final container = ProviderContainer(
        overrides: [
          accountDatabaseProvider.overrideWithValue(db),
          userIdProvider.overrideWithValue('original-author'),
          pinUserServiceProvider('original-author')
              .overrideWith(_EmptyPins.new),
          batchReadCoalescerProvider.overrideWithValue(batch),
          suppliedImageUrlRegistryProvider.overrideWithValue(registry),
          hiddenUserServiceProvider.overrideWithValue(const []),
          hiddenPostsServiceProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(pinRepositoryProvider)
          .put(PinEntity.fromDto(_pinDto('place'), false));
      await container
          .read(userPinsRepositoryProvider)
          .put(
            UserPinsEntity(
              userId: 'original-author',
              pins: ['place'],
              ttl: DateTime.now(),
              onlySession: false,
            ),
          );
      await _waitForEntries(
        container,
        userPinEntriesProvider('original-author'),
        (entries, _) => entries.isNotEmpty,
      );
      const request = (
        pinId: 'place',
        photoId: null,
        thumbnailUrl: null,
        imageUrl: null,
        attempt: 0,
      );
      await expectLater(
        container.read(pinImageSourcesProvider).resolve(request),
        throwsStateError,
      );
      await container.read(pinPhotoHistoryRepositoryProvider).putMultiple({
        'place': [
          PinPhotoDto(
            id: 'original-photo',
            pinId: 'place',
            contributorId: 'original-author',
            contributorUsername: 'original-author',
            observedAt: DateTime.utc(2026),
            isOriginal: true,
            image: 'https://images.example/original.jpg',
            imageThumbnail: 'https://images.example/thumbnail.jpg',
          ),
        ],
      });
      await _waitForEntries(
        container,
        userPinEntriesProvider('original-author'),
        (entries, _) =>
            registry.lookup(BatchReadKind.pinImageThumbnail, 'place') != null,
      );
      expect(
        (await container.read(pinImageSourcesProvider).resolve(request))?.url,
        'https://images.example/thumbnail.jpg',
      );
    },
  );

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

  test('group snapshot waits for every pin page and update history', () async {
    final history = Completer<List<PinPhotoDto>>();
    final historyStarted = Completer<void>();
    final firstPage = List.generate(100, (index) => _pinDto('page-$index'));
    final api = _ContributorPinsApi(
      pages: [
        firstPage,
        [_pinDto('last-page')],
      ],
      photoHistory: (pinId) {
        if (pinId != 'last-page') return Future.value([]);
        if (!historyStarted.isCompleted) historyStarted.complete();
        return history.future;
      },
    );
    final container = ProviderContainer(
      overrides: [
        pinApiProvider.overrideWithValue(api),
        groupDetailsPinsProvider('group')
            .overrideWithValue(AsyncData([_profilePin('cached')])),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    final snapshots = <List<PinEntity>>[];
    final ready = Completer<List<PinEntity>>();
    final subscription = container.listen(groupPinEntriesProvider('group'), (
      _,
      next,
    ) {
      if (next case AsyncData<List<PinEntity>>(:final value)) {
        snapshots.add(value);
        if (!ready.isCompleted) ready.complete(value);
      }
    });
    addTearDown(subscription.close);
    try {
      await historyStarted.future.timeout(const Duration(seconds: 5));
      expect(
        snapshots,
        isEmpty,
        reason: 'The group must not reveal cached originals or early pages',
      );
      expect(api.queriedGroups, ['group', 'group']);
      expect(api.photoRequests, contains('last-page'));
      history.complete([_photoUpdate('last-update', 'last-page')]);
      final entries = await ready.future.timeout(const Duration(seconds: 5));
      expect(
        entries.map((entry) => entry.entryId),
        containsAll(['last-page', 'last-update']),
      );
      expect(
        entries.where((entry) => entry.pinId.startsWith('page-')),
        hasLength(100),
      );
      expect(snapshots, hasLength(1));
    } finally {
      if (!history.isCompleted) history.complete([]);
    }
  });

  test(
    'group snapshot excludes blocked parents, posts and update contributors',
    () async {
      final api = _ContributorPinsApi(
        items: [
          _pinDto('visible'),
          _pinDto('blocked-parent')..creationUser = 'blocked',
          _pinDto('hidden-post'),
        ],
        photoHistory: (_) async => [
          _photoUpdate('allowed-update', 'visible'),
          _photoUpdate('blocked-update', 'visible')..contributorId = 'blocked',
        ],
      );
      final container = ProviderContainer(
        overrides: [
          pinApiProvider.overrideWithValue(api),
          groupDetailsPinsProvider('group')
              .overrideWithValue(const AsyncData([])),
          hiddenUserServiceProvider.overrideWithValue(const ['blocked']),
          hiddenPostsServiceProvider.overrideWithValue(const ['hidden-post']),
        ],
      );
      addTearDown(container.dispose);
      final entries = await _waitForEntries(
        container,
        groupPinEntriesProvider('group'),
        (_, _) => true,
      );
      expect(entries.map((entry) => entry.entryId).toSet(), {
        'visible',
        'allowed-update',
      });
      expect(api.photoRequests, ['visible']);
    },
  );

  test('group metadata loading does not publish an empty gallery', () async {
    final api = _ContributorPinsApi();
    final container = ProviderContainer(
      overrides: [
        pinApiProvider.overrideWithValue(api),
        groupDetailsPinsProvider('group')
            .overrideWithValue(const AsyncLoading()),
      ],
    );
    addTearDown(container.dispose);
    final states = <AsyncValue<List<PinEntity>>>[];
    final subscription = container.listen(
      groupPinEntriesProvider('group'),
      (_, next) => states.add(next),
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(groupPinEntriesProvider('group')).isLoading, isTrue);
    expect(states.where((state) => state.hasValue), isEmpty);
    expect(api.pinQueries, 0);
  });

  test('own profile waits for newly discovered update histories before its first snapshot', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final history = Completer<List<PinPhotoDto>>();
    final historyStarted = Completer<void>();
    final api = _ContributorPinsApi(
      items: [
        _pinDto('place')..creationUser = 'updater',
        _pinDto('update-place'),
      ],
      photoHistory: (pinId) {
        if (pinId != 'update-place') return Future.value([]);
        if (!historyStarted.isCompleted) historyStarted.complete();
        return history.future;
      },
    );
    final container = ProviderContainer(
      overrides: [
        accountDatabaseProvider.overrideWithValue(db),
        userIdProvider.overrideWithValue('updater'),
        syncingServiceProvider.overrideWith(_FinishedSync.new),
        pinUserServiceProvider('updater').overrideWith(_CachedUserPins.new),
        pinApiProvider.overrideWithValue(api),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pinRepositoryProvider).put(_profilePin('place'));
    await container.read(pinPhotoHistoryRepositoryProvider).putMultiple({
      'place': [],
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
    final snapshots = <List<PinEntity>>[];
    final ready = Completer<List<PinEntity>>();
    final subscription = container.listen(
      profileGridEntriesProvider('updater'),
      (_, state) {
        if (state case AsyncData<List<PinEntity>>(:final value)) {
          snapshots.add(value);
          if (!ready.isCompleted) ready.complete(value);
        }
      },
    );
    addTearDown(subscription.close);
    try {
      await historyStarted.future.timeout(const Duration(seconds: 5));
      expect(
        snapshots,
        isEmpty,
        reason: 'Cached originals must wait for update discovery',
      );
      expect(api.photoRequests, containsAll(['place', 'update-place']));
      history.complete([_photoUpdate('new-update', 'update-place')]);
      final entries = await ready.future.timeout(const Duration(seconds: 5));
      expect(entries.map((entry) => entry.entryId).toSet(), {
        'place',
        'new-update',
      });
      expect(snapshots, hasLength(1));
      expect(
        api.pinQueries,
        1,
        reason: 'Initial cache subscriptions must not restart discovery',
      );
    } finally {
      if (!history.isCompleted) history.complete([]);
    }
  });

  for (final failure in ['index', 'history']) {
    test(
      'own profile retains cached updates when the $failure refresh fails',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final api = _ContributorPinsApi(
          items: [_pinDto('place')..creationUser = 'updater'],
          queryError: failure == 'index' ? StateError('Offline') : null,
          photoHistory: (_) async => throw StateError('Offline'),
        );
        final container = ProviderContainer(
          overrides: [
            accountDatabaseProvider.overrideWithValue(db),
            userIdProvider.overrideWithValue('updater'),
            syncingServiceProvider.overrideWith(_FinishedSync.new),
            pinUserServiceProvider('updater').overrideWith(_CachedUserPins.new),
            pinApiProvider.overrideWithValue(api),
            hiddenUserServiceProvider.overrideWithValue(const []),
            hiddenPostsServiceProvider.overrideWithValue(const []),
          ],
        );
        addTearDown(container.dispose);
        await container.read(pinRepositoryProvider).put(_profilePin('place'));
        await container.read(pinPhotoHistoryRepositoryProvider).putMultiple({
          'place': [_photoUpdate('cached-update', 'place')],
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
          profileGridEntriesProvider('updater'),
          (entries, _) => entries.isNotEmpty,
        );
        expect(entries.map((entry) => entry.entryId).toSet(), {
          'place',
          'cached-update',
        });
      },
    );
  }

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

  test('current user profile includes synced cached pins while its index lags', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        accountDatabaseProvider.overrideWithValue(db),
        userIdProvider.overrideWithValue('updater'),
        pinUserServiceProvider('updater').overrideWith(_CachedUserPins.new),
        pinApiProvider.overrideWithValue(_ContributorPinsApi()),
        hiddenUserServiceProvider.overrideWithValue(const []),
        hiddenPostsServiceProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);

    final pins = container.read(pinRepositoryProvider);
    await pins.put(_profilePin('first'));
    await container
        .read(userPinsRepositoryProvider)
        .put(
          UserPinsEntity(
            userId: 'updater',
            pins: ['first'],
            ttl: DateTime.utc(2026, 2),
            onlySession: false,
            keepAlive: true,
          ),
        );

    final firstEmission = Completer<List<PinEntity>>();
    final cachedPinEmission = Completer<List<PinEntity>>();
    final subscription = container.listen(userPinEntriesProvider('updater'), (
      _,
      next,
    ) {
      if (next case AsyncData<List<PinEntity>>(:final value)) {
        if (!firstEmission.isCompleted) firstEmission.complete(value);
        if (value.any((pin) => pin.pinId == 'new-synced-pin') &&
            !cachedPinEmission.isCompleted) {
          cachedPinEmission.complete(value);
        }
      } else if (next case AsyncError<List<PinEntity>>(:final error)) {
        if (!firstEmission.isCompleted) firstEmission.completeError(error);
        if (!cachedPinEmission.isCompleted) {
          cachedPinEmission.completeError(error);
        }
      }
    });
    addTearDown(subscription.close);

    expect(
      (await firstEmission.future.timeout(const Duration(seconds: 5)))
          .map((pin) => pin.pinId),
      ['first'],
    );

    // Feed/map sync has cached this pin, while the profile index write has not
    // arrived yet. The synced flag alone should not hide it from the profile.
    await pins.put(_profilePin('new-synced-pin'));

    final entries = await cachedPinEmission.future.timeout(
      const Duration(seconds: 5),
    );
    expect(entries.map((pin) => pin.pinId).toSet(), {
      'first',
      'new-synced-pin',
    });
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

  for (final completeOnly in [false, true]) {
    test(
      'profile entries wait for photo history (complete snapshot: $completeOnly)',
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
        final snapshots = <List<PinEntity>>[];
        final allUpdatesEmitted = Completer<void>();
        final subscription = container.listen(
          completeOnly
              ? profileGridEntriesProvider('updater')
              : userPinEntriesProvider('updater'),
          (_, next) {
            if (next case AsyncData<List<PinEntity>>(:final value)) {
              snapshots.add(value);
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
          },
        );
        addTearDown(subscription.close);

        // Wait until both requests have been started by the profile provider.
        await requestsStarted.future.timeout(const Duration(seconds: 5));

        histories['place-a']!.complete([_photoUpdate('update-a', 'place-a')]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(emittedUpdateIds, isEmpty);
        if (completeOnly) expect(snapshots, isEmpty);

        histories['place-b']!.complete([_photoUpdate('update-b', 'place-b')]);
        await allUpdatesEmitted.future.timeout(const Duration(seconds: 5));
        if (completeOnly) expect(snapshots, hasLength(1));
        expect(emittedUpdateIds, [
          {'update-a', 'update-b'},
        ]);
      },
    );
  }

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

class _CachedUserPins extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) {
    return ref.watch(pinRepositoryProvider).getPinsByUser(userId);
  }
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
  _ContributorPinsApi({
    this.items,
    this.pages,
    this.photoHistory,
    this.queryError,
  }) : super(ApiClient());

  final List<PinWithOptionalImageDto>? items;
  final List<List<PinWithOptionalImageDto>>? pages;
  final queriedGroups = <String?>[];
  final Object? queryError;
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
    queriedGroups.add(groupId);
    if (pages != null) {
      return PinsSyncDto(items: pages![beforeId == null ? 0 : 1]);
    }
    if (queryError != null) throw queryError!;
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

class _FinishedSync extends SyncingService {
  @override
  SyncState build() => SyncState.finished;
}
