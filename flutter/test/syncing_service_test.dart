import 'package:buff_lisa/data/service/photo_library.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/app/lifecycle/sync_lifecycle.dart';
import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pending_pin_repository.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/pending_pin_uploader.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/syncing_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dotenv.loadFromString(envString: 'API_HOST=http://localhost');
  });

  test(
    'observing or rebuilding sync state does not start remote work',
    () async {
      final f = await _fixture();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(f.api.calls, 0);
      expect(f.container.read(syncingServiceProvider), SyncState.init);
      f.container.invalidate(syncingServiceProvider);
      await f.container.pump();
      expect(f.api.calls, 0);
      await f.container.read(syncingServiceProvider.notifier).syncToBackend();
      expect(f.api.calls, 1);
      expect(f.container.read(syncingServiceProvider), SyncState.finished);
    },
  );

  test('sync warms photo histories for the current profile', () async {
    final f = await _fixture();
    f.api.profilePins = [
      PinWithOptionalImageDto(
        id: 'updated-location',
        latitude: 48.1,
        longitude: 11.6,
        creationDate: DateTime.utc(2026),
        creationUser: 'original-author',
        groupId: 'public-group',
      ),
    ];
    f.api.photoHistories['updated-location'] = [
      PinPhotoDto(
        id: 'update-photo',
        pinId: 'updated-location',
        contributorId: 'alice',
        contributorUsername: 'Alice',
        observedAt: DateTime.utc(2026, 2),
        isOriginal: false,
      ),
    ];

    await f.container.read(syncingServiceProvider.notifier).syncToBackend();

    expect(f.api.profilePinQueries, 1);
    expect(f.api.photoHistoryRequests, isEmpty);
    expect(f.api.profileUpdateWatermarks.single, isNull);

    final profile = await f.container
        .read(userPinsRepositoryProvider)
        .get('alice');
    expect(profile?.pins, ['updated-location']);
    expect(profile?.keepAlive, isTrue);
    final cachedPin = await f.container
        .read(pinRepositoryProvider)
        .get('updated-location');
    expect(cachedPin?.creator, 'original-author');
    final cachedHistory = await f.container
        .read(pinPhotoHistoryRepositoryProvider)
        .get('updated-location');
    expect(cachedHistory?.photos.single.id, 'update-photo');

    f.api.profilePins = const [];
    await f.container.read(syncingServiceProvider.notifier).syncToBackend();
    expect(f.api.profilePinQueries, 2);
    expect(f.api.profileUpdateWatermarks.last, isNotNull);
    expect(f.api.photoHistoryRequests, isEmpty);

    final deleteResponse = Completer<SyncDto?>();
    f.api.response = deleteResponse;
    final deleteSync = f.container
        .read(syncingServiceProvider.notifier)
        .syncToBackend();
    deleteResponse.complete(SyncDto(deletedPins: ['updated-location']));
    await deleteSync;
    expect(
      (await f.container.read(userPinsRepositoryProvider).get('alice'))?.pins,
      isEmpty,
    );
    expect(
      await f.container
          .read(pinPhotoHistoryRepositoryProvider)
          .get('updated-location'),
      isA<CachedPinPhotoHistory>().having((h) => h.photos, 'photos', isEmpty),
    );
  });

  test(
    'one photo history failure does not block current profile publication',
    () async {
      final f = await _fixture();
      f.api.profilePins = [
        PinWithOptionalImageDto(
          id: 'history-unavailable',
          latitude: 48.1,
          longitude: 11.6,
          creationDate: DateTime.utc(2026),
          creationUser: 'alice',
          groupId: 'public-group',
        ),
        PinWithOptionalImageDto(
          id: 'history-available',
          latitude: 48.2,
          longitude: 11.7,
          creationDate: DateTime.utc(2026, 1, 2),
          creationUser: 'alice',
          groupId: 'public-group',
        ),
      ];
      f.api.photoHistoryErrors['history-unavailable'] = StateError(
        'temporary photo history failure',
      );

      await f.container.read(syncingServiceProvider.notifier).syncToBackend();

      expect(f.container.read(syncingServiceProvider), SyncState.finished);
      final profile = await f.container
          .read(userPinsRepositoryProvider)
          .get('alice');
      expect(
        profile?.pins,
        containsAll(['history-unavailable', 'history-available']),
      );
      expect(
        await f.container
            .read(pinRepositoryProvider)
            .get('history-unavailable'),
        isNotNull,
      );
    },
  );

  test('successful pin upload publishes the synced id without advancing profile watermark', () async {
    final f = await _fixture();
    final watermark = DateTime.utc(2026, 2);
    await f.container
        .read(userPinsRepositoryProvider)
        .put(
          UserPinsEntity(
            userId: 'alice',
            pins: const [],
            ttl: watermark,
            onlySession: false,
            keepAlive: true,
          ),
        );
    await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
    f.api.upload = Completer<PinWithOptionalImageDto?>();

    final upload = f.container.read(pendingPinUploaderProvider).upload('draft');
    await f.api.uploadStarted.future.timeout(const Duration(seconds: 2));
    f.api.upload!.complete(_createdPin());
    await upload;

    final profile = await f.container
        .read(userPinsRepositoryProvider)
        .get('alice');
    expect(profile?.pins, ['server-pin']);
    expect(profile?.ttl.isAtSameMomentAs(watermark), isTrue);
  });

  for (final rejoin in [false, true]) {
    test(
      rejoin
          ? 'old pending cleanup preserves fresh authorized photo state after rejoining'
          : 'pending creation cannot restore caches or profile index after group removal',
      () async {
        final f = await _fixture();
        await f.container
            .read(userPinsRepositoryProvider)
            .put(
              UserPinsEntity(
                userId: 'alice',
                pins: const [],
                ttl: DateTime.utc(2026),
                onlySession: false,
              ),
            );
        await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
        f.api.upload = Completer<PinWithOptionalImageDto?>();
        final upload = f.container
            .read(pendingPinUploaderProvider)
            .upload('draft');
        await f.api.uploadStarted.future;
        final library = f.container.read(photoLibraryProvider);
        await library.removeGroup('group');
        if (rejoin) {
          f.api.groupPins = [_createdPin()];
          final groups = f.container.listen(
            userGroupServiceProvider,
            (_, _) {},
          );
          addTearDown(groups.close);
          await f.container.read(userGroupServiceProvider.future);
          expect(
            await f.container
                .read(userGroupServiceProvider.notifier)
                .joinGroup('group'),
            isNull,
          );
          expect(
            library.parent('server-pin'),
            isNull,
            reason: 'the actual group join caches parent rows before gallery discovery',
          );
        }
        f.api.upload!.complete(_createdPin());
        await upload;
        expect(
          await f.container.read(pinRepositoryProvider).get('server-pin'),
          rejoin ? isNotNull : isNull,
        );
        expect(
          await f.container.read(pinRepositoryProvider).get('draft'),
          isNull,
        );
        expect(
          (await f.container.read(userPinsRepositoryProvider).get('alice'))
              ?.pins,
          rejoin ? ['server-pin'] : isEmpty,
        );
        expect(library.history('server-pin'), isEmpty);
        expect(await f.db.select(f.db.pendingPinCreates).get(), isEmpty);
      },
    );
  }

  test(
    'profile metadata publishes without waiting for image downloads',
    () async {
      final f = await _fixture(recordProfileImages: true);
      final imageBytes = Completer<Uint8List?>();
      f.profileImages!.imageResponse = imageBytes;
      f.profileThumbnailImages!.imageResponse = imageBytes;
      f.api.profilePins = [
        PinWithOptionalImageDto(
          id: 'updated-location',
          latitude: 48.1,
          longitude: 11.6,
          creationDate: DateTime.utc(2026),
          creationUser: 'original-author',
          groupId: 'public-group',
        ),
      ];
      f.api.photoHistories['updated-location'] = [
        PinPhotoDto(
          id: 'update-photo',
          pinId: 'updated-location',
          contributorId: 'alice',
          contributorUsername: 'Alice',
          image: 'https://example.test/update.png',
          imageThumbnail: 'https://example.test/update-small.png',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
        ),
      ];

      final sync = f.container
          .read(syncingServiceProvider.notifier)
          .syncToBackend();
      try {
        await sync.timeout(const Duration(seconds: 2));
        expect(f.profileThumbnailImages!.imageUrls, isEmpty);
        expect(f.profileImages!.imageUrls, isEmpty);
      } finally {
        imageBytes.complete(null);
        await sync;
      }
      expect(
        (await f.container.read(userPinsRepositoryProvider).get('alice'))?.pins,
        ['updated-location'],
      );
    },
  );

  test(
    'next sync retries the outbox even if the remote pull is unavailable',
    () async {
      final f = await _fixture();
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      final uploader = f.container.read(pendingPinUploaderProvider);
      f.api.uploadError = ApiException(503, 'temporary upload failure');
      await expectLater(uploader.upload('draft'), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      expect(await f.pending.get('draft'), isNotNull);

      f.api.uploadError = null;
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      f.api.syncError = ApiException(503, 'temporary pull failure');
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final retry = f.container
          .read(syncingServiceProvider.notifier)
          .syncToBackend();
      final retryFailure = expectLater(retry, throwsA(isA<ApiException>()));
      await f.api.secondUploadStarted.future.timeout(
        const Duration(seconds: 2),
      );
      f.api.upload!.complete(_createdPin());
      await retryFailure;

      expect(await f.pending.get('draft'), isNull);
      expect(f.api.calls, 1);
      expect(f.container.read(syncingServiceProvider), SyncState.failed);
    },
  );

  test(
    'cache facade rebuild keeps coordinator ownership and serializes restart',
    () async {
      final f = await _fixture();
      final coordinator = f.container.read(syncCoordinatorProvider);
      f.api.response = Completer<SyncDto?>();
      final old = coordinator.setSession(
        f.container.read(accountSessionProvider),
      );
      await f.api.started.future;
      f.container.invalidate(accountDatabaseProvider);
      await f.container.pump();
      expect(f.container.read(syncCoordinatorProvider), same(coordinator));
      final next = coordinator.restart();
      expect(f.api.calls, 1);
      f.api.response!.complete(SyncDto(groupUpdates: []));
      await Future.wait([old, next]);
      expect(f.api.calls, 2);
      expect(f.container.read(syncingServiceProvider), SyncState.finished);
    },
  );

  test('a superseded metadata response cannot delete cached pins', () async {
    final f = await _fixture();
    await f.container.read(pinRepositoryProvider).put(_draft());
    f.api.response = Completer<SyncDto?>();
    final subscription = f.container.listen(syncingServiceProvider, (_, _) {});
    addTearDown(subscription.close);
    var current = true;
    final pending = f.container
        .read(syncingServiceProvider.notifier)
        .syncToBackend(isActive: () => current);
    await f.api.started.future;
    current = false;
    f.api.response!.complete(SyncDto(groupUpdates: [], deletedPins: ['draft']));
    await pending;
    expect(
      (await f.db.select(f.db.pinEntities).get()).map((pin) => pin.pinId),
      ['draft'],
    );
  });

  test(
    'a late upload result cannot replace a draft after its run is revoked',
    () async {
      final f = await _fixture();
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      var current = true;
      final pending = f.container
          .read(syncingServiceProvider.notifier)
          .syncToBackend(isActive: () => current);
      await f.api.uploadStarted.future;
      current = false;
      f.api.upload!.complete(
        PinWithOptionalImageDto(
          id: 'server-pin',
          latitude: 1,
          longitude: 2,
          creationDate: DateTime.utc(2026),
          creationUser: 'alice',
          groupId: 'group',
        ),
      );
      await pending;
      expect(
        (await f.db.select(f.db.pinEntities).get()).map((pin) => pin.pinId),
        ['draft'],
      );
      expect(await f.db.select(f.db.imageEntities).get(), hasLength(1));
    },
  );

  test(
    'delete during cancellation write removes a completed remote post',
    () async {
      final f = await _fixture(delayedCancel: true);
      final pending = f.pending as _DelayedCancelRepository;
      await pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      await f.container.read(pinRepositoryProvider).put(_draft());
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final uploading = f.container
          .read(pendingPinUploaderProvider)
          .upload('draft');
      await f.api.uploadStarted.future;
      final deleting = f.container
          .read(pinServiceProvider)
          .deletePinFromGroup('draft');
      await pending.cancelEntered.future;
      f.api.upload!.complete(_createdPin());
      await uploading;
      pending.releaseCancel.complete();
      expect(await deleting, isNull);
      expect(f.api.deleted, ['server-pin']);
      expect(
        await f.container.read(pinRepositoryProvider).get('server-pin'),
        isNull,
      );
    },
  );

  test(
    'cancel after a lost response replays then deletes the server post',
    () async {
      final f = await _fixture();
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      final uploader = f.container.read(pendingPinUploaderProvider);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final first = uploader.upload('draft');
      await f.api.uploadStarted.future;
      f.api.upload!.completeError(Exception('response lost'));
      await expectLater(first, throwsException);
      await Future<void>.delayed(Duration.zero);
      await uploader.discard('draft');
      final cancelled = await f.pending.get('draft');
      expect(cancelled?.attempted, isTrue);
      expect(cancelled?.cancelRequested, isTrue);

      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final replay = uploader.upload('draft');
      await Future<void>.delayed(Duration.zero);
      f.api.upload!.complete(_createdPin());
      expect(await replay, isNull);
      expect(f.api.deleted, ['server-pin']);
      expect(await f.pending.get('draft'), isNull);
    },
  );

  test(
    'confirmed cancellation delete clears the outbox after its run is revoked',
    () async {
      final f = await _fixture();
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      f.api.deleteResponse = Completer<void>();
      var active = true;
      final uploader = f.container.read(pendingPinUploaderProvider);
      final uploading = uploader.upload('draft', isActive: () => active);
      await f.api.uploadStarted.future;
      final deleting = uploader.discard('draft');
      f.api.upload!.complete(_createdPin());
      await f.api.deleteStarted.future;
      active = false;
      f.api.deleteResponse!.complete();

      await uploading;
      await deleting;
      expect(f.api.deleted, ['server-pin']);
      expect(await f.pending.get('draft'), isNull);
    },
  );

  test(
    'canceled replay conflict clears the row after a lost delete response',
    () async {
      final f = await _fixture();
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      await f.pending.requestCancel('draft');
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      f.api.deleteError = Exception('delete response lost');
      final uploader = f.container.read(pendingPinUploaderProvider);
      final firstAttempt = uploader.upload('draft');
      await f.api.uploadStarted.future;
      f.api.upload!.complete(_createdPin());
      await expectLater(firstAttempt, throwsException);
      expect(await f.pending.get('draft'), isNotNull);

      f.api.uploadError = ApiException(409, 'missing deleted pin');
      await uploader.uploadAll();

      expect(await f.pending.get('draft'), isNull);
      expect(
        await f.container.read(pinRepositoryProvider).get('draft'),
        isNull,
      );
      expect(await f.db.select(f.db.imageEntities).get(), isEmpty);
    },
  );

  test(
    'canceled replay keeps its tombstone when draft cache cleanup fails',
    () async {
      final f = await _fixture(failPinCacheDeletes: true);
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      await f.pending.requestCancel('draft');
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.uploadError = ApiException(409, 'missing deleted pin');

      await expectLater(
        f.container.read(pendingPinUploaderProvider).uploadAll(),
        throwsException,
      );

      final canceled = await f.pending.get('draft');
      expect(canceled?.cancelRequested, isTrue);
      expect(
        await f.container.read(pinRepositoryProvider).get('draft'),
        isNotNull,
      );
    },
  );

  test(
    'outbox upload continues when the bounded pin cache cannot write',
    () async {
      final f = await _fixture(failPinCacheWrites: true);
      await f.pending.enqueue(_draft(), Uint8List.fromList([1, 2, 3]));
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final uploading = f.container
          .read(pendingPinUploaderProvider)
          .upload('draft');
      await f.api.uploadStarted.future;
      f.api.upload!.complete(_createdPin());
      await expectLater(uploading, throwsException);
      expect(await f.pending.get('draft'), isNotNull);
    },
  );

  test(
    'upload failures retain the draft, fail the run, and do not log payloads',
    () async {
      final f = await _fixture();
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final subscription = f.container.listen(
        syncingServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final output = <String>[];
      await runZoned(
        () async {
          final pending = expectLater(
            f.container.read(syncingServiceProvider.notifier).syncToBackend(),
            throwsA(isA<ApiException>()),
          );
          await f.api.uploadStarted.future;
          f.api.upload!.completeError(ApiException(503, 'sensitive payload'));
          await pending;
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) {
            output.add(line);
          },
        ),
      );
      expect(f.container.read(syncingServiceProvider), SyncState.failed);
      expect(
        f.api.calls,
        1,
        reason: 'backend pulls still run when upload fails',
      );
      expect(await f.db.select(f.db.pinEntities).get(), hasLength(1));
      expect(output, isEmpty);
    },
  );

  test(
    'offline pin upload success refreshes group progression and achievements',
    () async {
      final f = await _fixture();
      await f.container.read(pinRepositoryProvider).put(_draft());
      await f.container
          .read(pinImageRepositoryProvider)
          .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
      f.api.upload = Completer<PinWithOptionalImageDto?>();
      final progression = f.container.listen(
        groupProgressionProvider('group'),
        (_, _) {},
      );
      final achievements = f.container.listen(
        groupAchievementsProvider('group'),
        (_, _) {},
      );
      addTearDown(progression.close);
      addTearDown(achievements.close);
      await f.container.read(groupProgressionProvider('group').future);
      await f.container.read(groupAchievementsProvider('group').future);
      expect(f.groups.requests, 1);
      expect(f.groups.achievementRequests, 1);

      final syncing = f.container
          .read(syncingServiceProvider.notifier)
          .syncToBackend();
      await f.api.uploadStarted.future;
      f.api.upload!.complete(_createdPin());
      await syncing;
      await f.container.pump();
      final refreshed = await f.container.read(
        groupProgressionProvider('group').future,
      );
      await f.container.read(groupAchievementsProvider('group').future);

      expect(f.groups.requests, 2);
      expect(f.groups.achievementRequests, 2);
      expect(refreshed?.totalXp, 5);
    },
  );

  test('conflicted offline pin stays queued for inspection', () async {
    final f = await _fixture();
    await f.container.read(pinRepositoryProvider).put(_draft());
    await f.container
        .read(pinImageRepositoryProvider)
        .addImage('draft', Uint8List.fromList([1, 2, 3]), true);
    f.api.uploadError = ApiException(409, 'duplicate');
    final progression = f.container.listen(
      groupProgressionProvider('group'),
      (_, _) {},
    );
    final achievements = f.container.listen(
      groupAchievementsProvider('group'),
      (_, _) {},
    );
    addTearDown(progression.close);
    addTearDown(achievements.close);
    await f.container.read(groupProgressionProvider('group').future);
    await f.container.read(groupAchievementsProvider('group').future);
    expect(f.groups.requests, 1);
    expect(f.groups.achievementRequests, 1);

    await f.container.read(syncingServiceProvider.notifier).syncToBackend();
    await f.container.pump();
    final refreshed = await f.container.read(
      groupProgressionProvider('group').future,
    );
    await f.container.read(groupAchievementsProvider('group').future);

    expect(f.groups.requests, 1);
    expect(f.groups.achievementRequests, 1);
    expect(refreshed?.totalXp, 0);
    expect(
      await f.container.read(pinRepositoryProvider).get('draft'),
      isNotNull,
    );
    expect(await f.db.select(f.db.pendingPinCreates).get(), hasLength(1));
  });

  test('remote group pin updates refresh group achievements', () async {
    final f = await _fixture();
    final achievements = f.container.listen(
      groupAchievementsProvider('group'),
      (_, _) {},
    );
    addTearDown(achievements.close);
    await f.container.read(groupAchievementsProvider('group').future);
    expect(f.groups.achievementRequests, 1);

    f.api.response = Completer<SyncDto?>();
    final syncing = f.container
        .read(syncingServiceProvider.notifier)
        .syncToBackend();
    await f.api.started.future;
    f.api.response!.complete(
      SyncDto(
        groupUpdates: [
          SyncDtoGroupUpdatesInner(
            group: GroupDto(id: 'group', name: 'Group', visibility: 0),
            pinsAdded: [_createdPin()],
          ),
        ],
      ),
    );
    await syncing;
    await f.container.pump();
    await f.container.read(groupAchievementsProvider('group').future);

    expect(f.groups.achievementRequests, 2);
    expect(
      await f.container.read(pinRepositoryProvider).get('server-pin'),
      isNotNull,
    );
  });

  test('remote group metadata revisions refresh group achievements', () async {
    final f = await _fixture();
    final previousUpdate = DateTime.utc(2026);
    await f.container
        .read(groupRepositoryProvider)
        .put(
          GroupEntity(
            groupId: 'group',
            name: 'Group',
            visibility: 0,
            userIsMember: true,
            lastUpdated: previousUpdate,
            ttl: DateTime.utc(2099),
            onlySession: false,
          ),
        );
    final achievements = f.container.listen(
      groupAchievementsProvider('group'),
      (_, _) {},
    );
    addTearDown(achievements.close);
    await f.container.read(groupAchievementsProvider('group').future);
    expect(f.groups.achievementRequests, 1);

    f.api.response = Completer<SyncDto?>();
    final syncing = f.container
        .read(syncingServiceProvider.notifier)
        .syncToBackend();
    await f.api.started.future;
    f.api.response!.complete(
      SyncDto(
        groupUpdates: [
          SyncDtoGroupUpdatesInner(
            group: GroupDto(
              id: 'group',
              name: 'Group',
              visibility: 0,
              lastUpdated: previousUpdate.add(const Duration(seconds: 1)),
            ),
          ),
        ],
      ),
    );
    await syncing;
    await f.container.pump();
    await f.container.read(groupAchievementsProvider('group').future);

    expect(f.groups.achievementRequests, 2);
  });

  test('finds local groups that are absent from the server sync', () {
    final response = SyncDto(
      groupUpdates: [
        SyncDtoGroupUpdatesInner(
          group: GroupDto(id: 'kept', name: 'Kept', visibility: 0),
        ),
      ],
    );

    expect(removedUserGroupIds(['kept', 'removed'], response), {'removed'});
  });

  for (final explicitLeave in [true, false]) {
    test(
      '${explicitLeave ? 'explicit group leave' : 'remote membership removal'} purges cached photos and URLs before offline reads',
      () async {
        final f = await _fixture();
        final owner = f.container.read(photoLibraryProvider);
        final cachedPin = PinEntity.fromDto(_createdPin(), false);
        await f.container
            .read(groupRepositoryProvider)
            .put(
              GroupEntity(
                groupId: 'group',
                name: 'Private group',
                visibility: 1,
                userIsMember: true,
                ttl: DateTime.utc(2099),
                onlySession: false,
              ),
            );
        final update = PinPhotoDto(
          id: 'update',
          pinId: cachedPin.pinId,
          contributorId: 'alice',
          contributorUsername: 'Alice',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
          image: 'https://images.test/update',
          imageThumbnail: 'https://images.test/update-small',
        );
        await owner.accept(cachedPin, update);
        final registry = f.container.read(suppliedImageUrlRegistryProvider);
        registry.register(
          BatchReadKind.pinImage,
          cachedPin.pinId,
          'https://images.test/original',
        );
        expect(
          registry.lookup(BatchReadKind.pinImage, 'photo:server-pin:update'),
          isNotNull,
        );
        // No later gallery request can mask a missing purge by clearing metadata.
        f.api.galleryErrors[const PhotoScope(userId: 'alice')] = ApiException(
          503,
          'offline',
        );
        f.api.galleryErrors[const PhotoScope(groupId: 'group')] = ApiException(
          503,
          'offline',
        );
        f.api.photoHistoryErrors[cachedPin.pinId] = ApiException(
          503,
          'offline',
        );

        if (explicitLeave) {
          final subscription = f.container.listen(
            userGroupServiceProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          await f.container.read(userGroupServiceProvider.future);
          expect(
            await f.container
                .read(userGroupServiceProvider.notifier)
                .leaveGroup('group'),
            isNull,
          );
        } else {
          await f.container
              .read(syncingServiceProvider.notifier)
              .syncToBackend();
        }

        await owner.refreshGallery(const PhotoScope(groupId: 'group'));
        expect(
          owner.gallery(const PhotoScope(userId: 'alice')).photos,
          isEmpty,
        );
        expect(owner.history(cachedPin.pinId), isEmpty);
        expect(
          (await f.container
                  .read(pinPhotoHistoryRepositoryProvider)
                  .get(cachedPin.pinId))
              ?.photos,
          isEmpty,
        );
        for (final kind in [
          BatchReadKind.pinImage,
          BatchReadKind.pinImageThumbnail,
        ]) {
          expect(registry.lookup(kind, cachedPin.pinId), isNull);
          expect(registry.lookup(kind, 'photo:server-pin:update'), isNull);
        }
        await expectLater(
          owner.refreshHistory(cachedPin.pinId),
          throwsA(isA<ApiException>()),
        );
        expect(owner.history(cachedPin.pinId), isEmpty);
      },
    );
  }

  test('a failed sync gallery is retried on resume after a sync with no changed pins', () async {
    final f = await _fixture();
    const scope = PhotoScope(groupId: 'group');
    final update = PinPhotoDto(
      id: 'remote-update',
      pinId: 'server-pin',
      contributorId: 'bob',
      contributorUsername: 'Bob',
      observedAt: DateTime.utc(2026, 2),
      isOriginal: false,
    );
    f.api.profilePins = [_createdPin()];
    f.api.photoHistories['server-pin'] = [update];
    f.api.galleryErrors[scope] = ApiException(503, 'offline');
    f.api.response = Completer<SyncDto?>()
      ..complete(
        SyncDto(
          groupUpdates: [
            SyncDtoGroupUpdatesInner(
              group: GroupDto(id: 'group', name: 'Group', visibility: 0),
              pinsAdded: [_createdPin()],
            ),
          ],
        ),
      );
    await f.container.read(syncingServiceProvider.notifier).syncToBackend();
    final owner = f.container.read(photoLibraryProvider);
    final feedContainer = ProviderContainer(
      overrides: [
        photoLibraryProvider.overrideWithValue(owner),
        sortedActivatedPinsProvider.overrideWith(
          (ref) => AsyncData([PinEntity.fromDto(_createdPin(), false)]),
        ),
        hiddenPostsServiceProvider.overrideWithValue([]),
        hiddenUserServiceProvider.overrideWithValue([]),
      ],
    );
    addTearDown(feedContainer.dispose);
    final feed = feedContainer.listen(activePinEntriesProvider, (_, _) {});
    addTearDown(feed.close);
    await feedContainer.read(activePinEntriesProvider.future);
    expect(
      owner.history('server-pin').map((photo) => photo.id),
      isNot(contains(update.id)),
    );
    f.api.galleryErrors.remove(scope);
    f.api.response = Completer<SyncDto?>()
      ..complete(
        SyncDto(
          groupUpdates: [
            SyncDtoGroupUpdatesInner(
              group: GroupDto(id: 'group', name: 'Group', visibility: 0),
            ),
          ],
        ),
      );
    await f.container.read(syncingServiceProvider.notifier).syncToBackend();
    expect(f.api.galleryCalls[scope], 1);

    await owner.refreshActive();

    expect(f.api.galleryCalls[scope], 2);
    expect(
      owner.history('server-pin').map((photo) => photo.id),
      contains(update.id),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      feedContainer
          .read(activePinEntriesProvider)
          .requireValue
          .map((entry) => entry.entryId),
      contains(update.id),
    );
  });
}

class _NoUser extends UserService {
  @override
  Stream<UserEntity?> build(String userId) => Stream.value(null);
}

class _Pins extends PinsApi {
  int calls = 0;
  int profilePinQueries = 0;
  final profileUpdateWatermarks = <DateTime?>[];
  final photoHistoryRequests = <String>[];
  List<PinWithOptionalImageDto> profilePins = const [];
  List<PinWithOptionalImageDto> groupPins = const [];
  final photoHistories = <String, List<PinPhotoDto>>{};
  final photoHistoryErrors = <String, Object>{};
  final galleryErrors = <PhotoScope, Object>{};
  final galleryCalls = <PhotoScope, int>{};
  int uploadCalls = 0;
  final deleted = <String>[];
  Completer<SyncDto?>? response;
  Completer<PinWithOptionalImageDto?>? upload;
  Object? syncError;
  Completer<void>? deleteResponse;
  Object? uploadError;
  Object? deleteError;
  final started = Completer<void>();
  final uploadStarted = Completer<void>();
  final secondUploadStarted = Completer<void>();
  final deleteStarted = Completer<void>();

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
    if (userId != null) {
      profilePinQueries++;
      profileUpdateWatermarks.add(updatedAfter);
      return PinsSyncDto(items: profilePins);
    }
    return PinsSyncDto(items: groupPins);
  }

  @override
  Future<List<PinPhotoDto>?> getPinPhotos(String pinId) async {
    photoHistoryRequests.add(pinId);
    final error = photoHistoryErrors[pinId];
    if (error != null) throw error;
    return photoHistories[pinId] ?? const [];
  }

  @override
  Future<PinWithOptionalImageDto?> createPin(
    PinRequestDto request, {
    String? idempotencyKey,
  }) {
    uploadCalls++;
    if (!uploadStarted.isCompleted) uploadStarted.complete();
    if (uploadCalls == 2 && !secondUploadStarted.isCompleted) {
      secondUploadStarted.complete();
    }
    if (uploadError != null) return Future.error(uploadError!);
    return upload!.future;
  }

  @override
  Future<void> deletePin(String pinId) async {
    deleted.add(pinId);
    if (!deleteStarted.isCompleted) deleteStarted.complete();
    if (deleteError != null) throw deleteError!;
    if (deleteResponse != null) await deleteResponse!.future;
  }

  @override
  Future<SyncDto?> callSync({DateTime? lastSeen}) async {
    calls++;
    if (!started.isCompleted) started.complete();
    if (syncError != null) throw syncError!;
    if (response != null) return response!.future;
    return SyncDto(groupUpdates: []);
  }
}

class _Members extends MembersApi {
  @override
  Future<void> deleteMemberFromGroup(String groupId, String userId) async {}
  @override
  Future<GroupDto?> joinGroup(
    String groupId,
    String userId, {
    String? inviteUrl,
  }) async => GroupDto(id: groupId, name: 'Rejoined group', visibility: 1);
}

class _Groups extends GroupsApi {
  int requests = 0;
  int achievementRequests = 0;

  @override
  Future<GroupProgressionDto?> getGroupProgression(String groupId) async {
    requests++;
    final totalXp = requests == 1 ? 0 : 5;
    return GroupProgressionDto(
      groupId: groupId,
      totalXp: totalXp,
      currentLevel: 1,
      currentLevelXp: totalXp,
      nextLevelXp: 50,
    );
  }

  @override
  Future<List<GroupAchievementsDtoInner>?> getGroupAchievements(
    String groupId,
  ) async {
    achievementRequests++;
    return const [];
  }
}

class _Users extends UsersApi {
  @override
  Future<UserXpDto?> getUserXp(String userId) async => UserXpDto(
    totalXp: 0,
    currentLevel: 1,
    currentLevelXp: 0,
    nextLevelXp: 50,
  );
}

Future<
  ({
    ProviderContainer container,
    AppDatabase db,
    _Pins api,
    _Groups groups,
    PendingPinRepository pending,
    _RecordingProfileImageRepository? profileImages,
    _RecordingProfileImageRepository? profileThumbnailImages,
  })
>
_fixture({
  bool delayedCancel = false,
  bool failPinCacheWrites = false,
  bool failPinCacheDeletes = false,
  bool recordProfileImages = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final api = _Pins();
  final groups = _Groups();
  final pending = delayedCancel
      ? _DelayedCancelRepository(db)
      : PendingPinRepository(db);
  final profileImages = recordProfileImages
      ? _RecordingProfileImageRepository(db, ImageType.pin)
      : null;
  final profileThumbnailImages = recordProfileImages
      ? _RecordingProfileImageRepository(db, ImageType.pinThumbnail)
      : null;
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      driftRepoProvider.overrideWithValue(db),
      if (failPinCacheWrites || failPinCacheDeletes)
        pinRepositoryProvider.overrideWithValue(
          _FailingPinRepository(
            db,
            failWrites: failPinCacheWrites,
            failDeletes: failPinCacheDeletes,
          ),
        ),
      if (profileImages != null)
        pinImageRepositoryProvider.overrideWithValue(profileImages),
      if (profileThumbnailImages != null)
        pinThumbnailRepositoryProvider.overrideWithValue(
          profileThumbnailImages,
        ),
      globalDataOnceProvider.overrideWithValue(
        const GlobalDataDto(
          userId: 'alice',
          refreshToken: 'alice-refresh',
          cameras: [],
        ),
      ),
      pinApiProvider.overrideWithValue(api),
      photoApiProvider.overrideWithValue(_GalleryApi(api)),
      userApiProvider.overrideWithValue(_Users()),
      pendingPinRepositoryProvider.overrideWithValue(pending),
      groupApiProvider.overrideWithValue(groups),
      memberApiProvider.overrideWithValue(_Members()),
      userServiceProvider('alice').overrideWith(_NoUser.new),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    db: db,
    api: api,
    groups: groups,
    pending: pending,
    profileImages: profileImages,
    profileThumbnailImages: profileThumbnailImages,
  );
}

class _RecordingProfileImageRepository extends ImageRepository {
  _RecordingProfileImageRepository(AppDatabase db, ImageType type)
    : super(db: db, getImageUrl: (_) async => null, type: type);

  final imageUrls = <String, String>{};
  final endpointFallbacks = <String, bool>{};
  final imageRequestStarted = Completer<void>();
  Completer<Uint8List?>? imageResponse;

  @override
  Future<Uint8List?> fetchImageFromUrl(
    String id,
    String url,
    bool keepAlive, {
    bool fallbackToEndpoint = true,
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) {
    imageUrls[id] = url;
    endpointFallbacks[id] = fallbackToEndpoint;
    if (!imageRequestStarted.isCompleted) imageRequestStarted.complete();
    return imageResponse?.future ?? Future.value(Uint8List.fromList([1]));
  }
}

class _DelayedCancelRepository extends PendingPinRepository {
  _DelayedCancelRepository(super.db);
  final cancelEntered = Completer<void>();
  final releaseCancel = Completer<void>();

  @override
  Future<void> requestCancel(String pinId) async {
    cancelEntered.complete();
    await releaseCancel.future;
    await super.requestCancel(pinId);
  }
}

class _FailingPinRepository extends PinRepository {
  _FailingPinRepository(
    super.db, {
    this.failWrites = true,
    this.failDeletes = false,
  });

  final bool failWrites;
  final bool failDeletes;

  @override
  Future<void> put(PinEntity item) =>
      failWrites ? Future.error(Exception('cache full')) : super.put(item);

  @override
  Future<void> replacePin(String oldPinId, PinEntity newPin) => failWrites
      ? Future.error(Exception('cache full'))
      : super.replacePin(oldPinId, newPin);

  @override
  Future<void> delete(String id) => failDeletes
      ? Future.error(Exception('cache unavailable'))
      : super.delete(id);
}

PinEntity _draft() => PinEntity(
  pinId: 'draft',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creator: 'alice',
  groupId: 'group',
  ttl: DateTime.utc(2099),
  onlySession: false,
  keepAlive: true,
);

PinWithOptionalImageDto _createdPin() => PinWithOptionalImageDto(
  id: 'server-pin',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creationUser: 'alice',
  groupId: 'group',
);

class _GalleryApi extends PhotoApi {
  _GalleryApi(this.api) : super(ApiClient());
  final _Pins api;
  @override
  Future<GalleryPhotoPage> gallery(PhotoScope scope, String? cursor) async {
    api.galleryCalls.update(scope, (count) => count + 1, ifAbsent: () => 1);
    final error = api.galleryErrors[scope];
    if (error != null) throw error;
    return GalleryPhotoPage(
      items: [
        for (final pin in api.profilePins)
          for (final photo in api.photoHistories[pin.id] ?? <PinPhotoDto>[])
            if (scope.contains(PinEntity.fromDto(pin, false), photo))
              GalleryPhotoRecord(PinEntity.fromDto(pin, false), photo),
      ],
    );
  }
}
