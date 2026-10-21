import 'dart:async';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

PinPhotoDto photo(String id, {String pinId = 'pin'}) => PinPhotoDto(
  id: id,
  pinId: pinId,
  contributorId: 'alice',
  contributorUsername: 'Alice',
  observedAt: DateTime.utc(2026, 1, id == pinId ? 1 : 2),
  isOriginal: id == pinId,
  image: 'https://images.test/$id?signature=one',
);
PinEntity get pin => PinEntity(
  pinId: 'pin',
  latitude: 0,
  longitude: 0,
  creator: 'alice',
  groupId: 'group',
  creationDate: DateTime.utc(2026),
  ttl: DateTime.utc(2026),
  lastSynced: DateTime.utc(2026),
  onlySession: false,
);
void main() {
  late AppDatabase db;
  late PinPhotoHistoryRepository histories;
  late PinRepository pins;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    histories = PinPhotoHistoryRepository(db);
    pins = PinRepository(db);
  });
  tearDown(() async {
    histories.dispose();
    await db.close();
  });
  PhotoLibrary library({
    required Future<GalleryPhotoPage> Function(PhotoScope, String?) fetch,
    Future<List<PinPhotoDto>> Function(String)? history,
    Future<Map<String, PinPhotoDto?>> Function(List<String>)? resolve,
    void Function(Iterable<String>)? revokePinUrls,
  }) => PhotoLibrary(
    histories: histories,
    pins: pins,
    fetchPage: fetch,
    fetchHistory: history ?? (_) async => [photo('pin'), photo('update')],
    resolvePhotos: resolve ?? (_) async => {},
    publish: (_, _) {},
    revokePinUrls: revokePinUrls,
  );
  test('group last-good updates survive failure, retry, and authoritative deletion', () async {
    var fail = false;
    var items = [photo('pin'), photo('update')];
    final owner = library(
      fetch: (_, _) async {
        if (fail) throw ApiException(503, 'offline');
        return GalleryPhotoPage(
          items: items.map((p) => GalleryPhotoRecord(pin, p)).toList(),
        );
      },
    );
    addTearDown(owner.dispose);
    const scope = PhotoScope(groupId: 'group');
    await owner.refreshGallery(scope);
    expect(owner.gallery(scope).photos.map((p) => p.id), ['update', 'pin']);
    fail = true;
    await owner.refreshGallery(scope);
    expect(owner.gallery(scope).photos.length, 2);
    expect(owner.gallery(scope).error, isNotNull);
    fail = false;
    items = [photo('pin')];
    await owner.refreshGallery(scope);
    expect(owner.gallery(scope).photos.single.id, 'pin');
    expect(owner.gallery(scope).error, isNull);
  });

  test(
    'successful gallery recovery clears a stale detail history error',
    () async {
      final owner = library(
        fetch: (_, _) async =>
            GalleryPhotoPage(items: [GalleryPhotoRecord(pin, photo('update'))]),
        history: (_) async => throw ApiException(503, 'offline'),
      );
      addTearDown(owner.dispose);
      final events = <List<PinPhotoDto>>[];
      final errors = <Object>[];
      final subscription = owner
          .watchHistory('pin')
          .listen(events.add, onError: (Object error) => errors.add(error));
      addTearDown(subscription.cancel);

      await expectLater(
        owner.refreshHistory('pin'),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
      final previousErrors = errors.length;

      await owner.refreshGallery(const PhotoScope(groupId: 'group'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(previousErrors));
      expect(events.last.map((item) => item.id), ['update']);
    },
  );

  test(
    'group access purge clears photo state, persisted history, and signed URLs',
    () async {
      final otherPin = PinEntity(
        pinId: 'other-pin',
        latitude: 0,
        longitude: 0,
        creator: 'alice',
        groupId: 'other-group',
        creationDate: DateTime.utc(2026),
        ttl: DateTime.utc(2027),
        lastSynced: DateTime.utc(2026),
        onlySession: false,
      );
      final otherPhoto = photo('other-pin', pinId: 'other-pin');
      final revoked = <String>{};
      var offline = false;
      final owner = library(
        fetch: (scope, _) async {
          if (offline) throw ApiException(503, 'offline');
          final records = [
            GalleryPhotoRecord(pin, photo('update')),
            GalleryPhotoRecord(otherPin, otherPhoto),
          ];
          return GalleryPhotoPage(
            items: records
                .where((record) => scope.contains(record.pin, record.photo))
                .toList(),
          );
        },
        history: (_) async {
          if (offline) throw ApiException(503, 'offline');
          return [photo('update')];
        },
        revokePinUrls: revoked.addAll,
      );
      addTearDown(owner.dispose);
      const groupScope = PhotoScope(groupId: 'group');
      const userScope = PhotoScope(userId: 'alice');
      await owner.refreshGallery(groupScope);
      await owner.refreshGallery(userScope);

      await owner.removeGroup('group');

      expect(owner.gallery(groupScope).photos, isEmpty);
      expect(owner.gallery(userScope).photos.map((item) => item.id), [
        'other-pin',
      ]);
      expect(owner.history('pin'), isEmpty);
      expect(revoked, contains('pin'));
      expect((await histories.get('pin'))?.photos, isEmpty);

      offline = true;
      await owner.refreshGallery(groupScope);
      await expectLater(
        owner.refreshHistory('pin'),
        throwsA(isA<ApiException>()),
      );
      expect(owner.gallery(groupScope).photos, isEmpty);
      expect(owner.history('pin'), isEmpty);
      expect((await histories.get('pin'))?.photos, isEmpty);
    },
  );

  test(
    'resume retries failed sync gallery scopes without an active gallery view',
    () async {
      var calls = 0;
      final owner = library(
        fetch: (_, _) async {
          if (++calls == 1) throw ApiException(503, 'offline');
          return GalleryPhotoPage(
            items: [GalleryPhotoRecord(pin, photo('update'))],
          );
        },
      );
      addTearDown(owner.dispose);
      const scope = PhotoScope(groupId: 'group');
      await owner.refreshGallery(scope);
      expect(owner.gallery(scope).photos, isEmpty);

      await owner.refreshActive();

      expect(calls, 2);
      expect(owner.gallery(scope).photos.single.id, 'update');
      expect(owner.gallery(scope).error, isNull);
      await owner.refreshActive();
      expect(
        calls,
        2,
        reason: 'successful unwatched scopes no longer need retry',
      );
    },
  );

  test(
    'group purge fences late gallery records for previously unknown pins',
    () async {
      final page = Completer<GalleryPhotoPage>();
      final owner = library(fetch: (_, _) => page.future);
      addTearDown(owner.dispose);
      final refresh = owner.refreshGallery(const PhotoScope(userId: 'alice'));
      await owner.removeGroup('group');
      page.complete(
        GalleryPhotoPage(items: [GalleryPhotoRecord(pin, photo('update'))]),
      );
      await refresh;
      expect(owner.history('pin'), isEmpty);
      expect(owner.gallery(const PhotoScope(userId: 'alice')).photos, isEmpty);
      expect((await histories.get('pin'))?.photos ?? [], isEmpty);
    },
  );

  for (final status in [503, 403, 404]) {
    test(
      'late history $status cannot replace newer gallery recovery',
      () async {
        final pending = Completer<List<PinPhotoDto>>();
        final owner = library(
          fetch: (_, _) async => GalleryPhotoPage(
            items: [GalleryPhotoRecord(pin, photo('update'))],
          ),
          history: (_) => pending.future,
        );
        addTearDown(owner.dispose);
        final refresh = owner.refreshHistory('pin');
        await owner.refreshGallery(const PhotoScope(groupId: 'group'));
        pending.completeError(ApiException(status, 'stale history failure'));
        expect((await refresh).map((photo) => photo.id), ['update']);
        expect(owner.history('pin').single.id, 'update');
        expect((await histories.get('pin'))?.photos.single.id, 'update');
      },
    );
  }

  test('a delayed accepted upload cannot restore a removed group', () async {
    final owner = library(
      fetch: (_, _) async => const GalleryPhotoPage(items: []),
    );
    addTearDown(owner.dispose);
    await owner.accept(pin, photo('pin'));
    await owner.removeGroup('group');
    await owner.accept(pin, photo('update'));
    expect(owner.history('pin'), isEmpty);
    expect((await histories.get('pin'))?.photos, isEmpty);
  });

  test('a fresh authorized write after rejoining can publish again', () async {
    final owner = library(
      fetch: (_, _) async => const GalleryPhotoPage(items: []),
    );
    addTearDown(owner.dispose);
    await owner.accept(pin, photo('pin'));
    final staleWrite = owner.beginWrite();
    await owner.removeGroup('group');
    expect(
      await owner.accept(pin, photo('late'), startedAt: staleWrite),
      isFalse,
    );
    final freshWrite = owner.beginWrite();
    expect(
      await owner.accept(pin, photo('fresh'), startedAt: freshWrite),
      isTrue,
    );
    expect(owner.history('pin').single.id, 'fresh');
  });
  test(
    'accepted upload survives an older in-flight gallery snapshot',
    () async {
      final pending = Completer<GalleryPhotoPage>();
      final owner = library(fetch: (_, _) => pending.future);
      addTearDown(owner.dispose);
      const scope = PhotoScope(userId: 'alice');
      final refresh = owner.refreshGallery(scope);
      await owner.accept(pin, photo('update'));
      pending.complete(
        GalleryPhotoPage(items: [GalleryPhotoRecord(pin, photo('pin'))]),
      );
      await refresh;
      expect(owner.gallery(scope).photos.map((p) => p.id), contains('update'));
      expect(
        (await histories.get('pin'))!.photos.map((p) => p.id),
        contains('update'),
      );
    },
  );
  test(
    'detail deduplicates and session disposal fences late persistence',
    () async {
      final pending = Completer<List<PinPhotoDto>>();
      var calls = 0;
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
        history: (_) {
          calls++;
          return pending.future;
        },
      );
      final first = owner.refreshHistory('pin');
      final second = owner.refreshHistory('pin');
      owner.dispose();
      pending.complete([photo('update')]);
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(await histories.get('pin'), isNull);
    },
  );
  test(
    'authoritative access loss clears cached scope and persistent photos',
    () async {
      var deny = false;
      final owner = library(
        fetch: (_, _) async {
          if (deny) throw ApiException(403, 'forbidden');
          return GalleryPhotoPage(
            items: [GalleryPhotoRecord(pin, photo('update'))],
          );
        },
      );
      addTearDown(owner.dispose);
      const scope = PhotoScope(groupId: 'group');
      await owner.refreshGallery(scope);
      deny = true;
      await owner.refreshGallery(scope);
      expect(owner.gallery(scope).photos, isEmpty);
      expect((await histories.get('pin'))?.photos ?? [], isEmpty);
    },
  );
  test(
    'history transient failure keeps last good and explicit retry recovers',
    () async {
      var fail = false;
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
        history: (_) async {
          if (fail) throw ApiException(503, 'offline');
          return [photo('pin'), photo('update')];
        },
      );
      addTearDown(owner.dispose);
      await owner.refreshHistory('pin');
      fail = true;
      await expectLater(
        owner.refreshHistory('pin'),
        throwsA(isA<ApiException>()),
      );
      expect(owner.history('pin').length, 2);
      fail = false;
      await owner.refreshHistory('pin');
      expect(owner.history('pin').length, 2);
    },
  );
  test(
    'accepted upload recovers an active history stream after a fetch error',
    () async {
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
        history: (_) async => throw ApiException(503, 'offline'),
      );
      addTearDown(owner.dispose);
      final events = <List<PinPhotoDto>>[];
      final errors = <Object>[];
      final subscription = owner
          .watchHistory('pin')
          .listen(events.add, onError: (Object error) => errors.add(error));
      addTearDown(subscription.cancel);
      await expectLater(
        owner.refreshHistory('pin'),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
      final errorsBeforeAccept = errors.length;

      await owner.accept(pin, photo('update'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(errorsBeforeAccept));
      expect(events.last.map((item) => item.id), contains('update'));
    },
  );
  test(
    'concurrent detail and renewal share the pending history read',
    () async {
      final pending = Completer<List<PinPhotoDto>>();
      var resolutions = 0;
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
        history: (_) => pending.future,
        resolve: (ids) async {
          resolutions++;
          return {for (final id in ids) id: photo(id)};
        },
      );
      addTearDown(owner.dispose);
      await owner.accept(pin, photo('update'));
      final detail = owner.refreshHistory('pin');
      final image = owner.renew('update');
      pending.complete([photo('pin'), photo('update')]);
      await detail;
      expect((await image)?.id, 'update');
      expect(resolutions, 0);
    },
  );
  test('batched renewal keeps incomplete per-item failures and publishes successful peers', () async {
    final owner = library(
      fetch: (_, _) async => const GalleryPhotoPage(items: []),
      resolve: (_) async => {'pin': photo('pin')},
    );
    addTearDown(owner.dispose);
    await owner.accept(pin, photo('update'));
    final failure = expectLater(owner.renew('update'), throwsStateError);
    final success = owner.renew('pin');
    expect((await success)?.id, 'pin');
    await failure;
    expect(
      owner.history('pin').map((p) => p.id),
      containsAll(['pin', 'update']),
    );
  });
  test(
    'confirmed deletion fences older gallery and history responses',
    () async {
      final gallery = Completer<GalleryPhotoPage>();
      final detail = Completer<List<PinPhotoDto>>();
      final owner = library(
        fetch: (_, _) => gallery.future,
        history: (_) => detail.future,
      );
      addTearDown(owner.dispose);
      await owner.accept(pin, photo('update'));
      final refreshing = owner.refreshGallery(
        const PhotoScope(groupId: 'group'),
      );
      final history = owner.refreshHistory('pin');
      await owner.removePins(['pin']);
      gallery.complete(
        GalleryPhotoPage(items: [GalleryPhotoRecord(pin, photo('update'))]),
      );
      detail.complete([photo('update')]);
      await Future.wait([refreshing, history]);
      expect(owner.history('pin'), isEmpty);
      expect((await histories.get('pin'))?.photos, isEmpty);
    },
  );
  test(
    'late history failure after deletion does not restore an error state',
    () async {
      final pending = Completer<List<PinPhotoDto>>();
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
        history: (_) => pending.future,
      );
      addTearDown(owner.dispose);
      await owner.accept(pin, photo('update'));
      final refresh = owner.refreshHistory('pin');
      await owner.removePins(['pin']);
      pending.completeError(ApiException(503, 'late offline'));

      expect(await refresh, isEmpty);
      expect(owner.history('pin'), isEmpty);
      expect((await histories.get('pin'))?.photos, isEmpty);
    },
  );
  test('last-good metadata persists across repository restart', () async {
    final first = library(
      fetch: (_, _) async => GalleryPhotoPage(
        items: [
          GalleryPhotoRecord(pin, photo('pin')),
          GalleryPhotoRecord(pin, photo('update')),
        ],
      ),
    );
    await first.refreshGallery(const PhotoScope(groupId: 'group'));
    first.dispose();
    final second = library(
      fetch: (_, _) async => throw ApiException(503, 'offline'),
    );
    addTearDown(second.dispose);
    await second.hydrate();
    expect(
      second
          .gallery(const PhotoScope(groupId: 'group'))
          .photos
          .map((p) => p.id),
      ['update', 'pin'],
    );
  });

  test(
    'remote gallery refresh keeps unsynced drafts until accepted replacement',
    () async {
      final draft = PinEntity(
        pinId: 'draft',
        latitude: 0,
        longitude: 0,
        creator: 'alice',
        groupId: 'group',
        creationDate: DateTime.utc(2026),
        ttl: DateTime.utc(2027),
        onlySession: false,
      );
      final draftPhoto = PinPhotoDto(
        id: 'draft',
        pinId: 'draft',
        contributorId: 'alice',
        contributorUsername: '',
        observedAt: draft.creationDate,
        isOriginal: true,
      );
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
      );
      addTearDown(owner.dispose);
      await owner.accept(draft, draftPhoto);
      await owner.refreshGallery(const PhotoScope(userId: 'alice'));
      expect(
        owner.gallery(const PhotoScope(userId: 'alice')).photos.single.id,
        'draft',
      );
    },
  );

  test(
    'sync original ingestion preserves existing update records and URLs',
    () async {
      final owner = library(
        fetch: (_, _) async => const GalleryPhotoPage(items: []),
      );
      addTearDown(owner.dispose);
      await owner.accept(pin, photo('update'));
      await owner.ingestOriginals([
        PinWithOptionalImageDto(
          id: 'pin',
          latitude: 0,
          longitude: 0,
          creationDate: DateTime.utc(2026),
          creationUser: 'alice',
          groupId: 'group',
          image: 'https://images.test/original',
        ),
      ]);
      expect(
        owner.history('pin').map((p) => p.id),
        containsAll(['pin', 'update']),
      );
      expect(owner.history('pin').first.image, 'https://images.test/original');
    },
  );

  test(
    'photo changes only notify galleries and history for the affected pin',
    () async {
      final otherPin = PinEntity(
        pinId: 'other',
        latitude: 0,
        longitude: 0,
        creator: 'alice',
        groupId: 'other-group',
        creationDate: DateTime.utc(2026),
        ttl: DateTime.utc(2027),
        lastSynced: DateTime.utc(2026),
        onlySession: false,
      );
      final owner = library(
        fetch: (scope, _) async => GalleryPhotoPage(
          items: scope.groupId == 'group'
              ? [
                  GalleryPhotoRecord(pin, photo('pin')),
                  GalleryPhotoRecord(pin, photo('update')),
                ]
              : [GalleryPhotoRecord(otherPin, photo('other', pinId: 'other'))],
        ),
        history: (_) async => [photo('pin'), photo('update')],
      );
      addTearDown(owner.dispose);
      const firstScope = PhotoScope(groupId: 'group');
      const otherScope = PhotoScope(groupId: 'other-group');
      var firstGalleryEvents = 0;
      var otherGalleryEvents = 0;
      var firstHistoryEvents = 0;
      final subscriptions = [
        owner.watchGallery(firstScope).listen((_) => firstGalleryEvents++),
        owner.watchGallery(otherScope).listen((_) => otherGalleryEvents++),
        owner.watchHistory('pin').listen((_) => firstHistoryEvents++),
      ];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });

      await Future.wait([
        owner.refreshGallery(firstScope),
        owner.refreshGallery(otherScope),
        owner.refreshHistory('pin'),
      ]);
      await Future<void>.delayed(Duration.zero);
      final firstGalleryBefore = firstGalleryEvents;
      final firstHistoryBefore = firstHistoryEvents;
      final otherGalleryBefore = otherGalleryEvents;

      await owner.accept(otherPin, photo('other-update', pinId: 'other'));

      expect(firstGalleryEvents, firstGalleryBefore);
      expect(firstHistoryEvents, firstHistoryBefore);
      expect(otherGalleryEvents, greaterThan(otherGalleryBefore));
    },
  );

  test(
    'app resume refreshes only galleries and histories still being watched',
    () async {
      final galleryCalls = <PhotoScope, int>{};
      final historyCalls = <String, int>{};
      final owner = library(
        fetch: (scope, _) async {
          galleryCalls.update(scope, (count) => count + 1, ifAbsent: () => 1);
          return const GalleryPhotoPage(items: []);
        },
        history: (pinId) async {
          historyCalls.update(pinId, (count) => count + 1, ifAbsent: () => 1);
          return const [];
        },
      );
      addTearDown(owner.dispose);
      const activeScope = PhotoScope(groupId: 'active');
      const inactiveScope = PhotoScope(groupId: 'inactive');
      final activeGallery = owner.watchGallery(activeScope).listen((_) {});
      final activeHistory = owner.watchHistory('active-pin').listen((_) {});
      await Future.wait([
        owner.refreshGallery(activeScope),
        owner.refreshHistory('active-pin'),
      ]);

      final inactiveGallery = owner.watchGallery(inactiveScope).listen((_) {});
      final inactiveHistory = owner.watchHistory('inactive-pin').listen((_) {});
      await Future.wait([
        owner.refreshGallery(inactiveScope),
        owner.refreshHistory('inactive-pin'),
      ]);
      await inactiveGallery.cancel();
      await inactiveHistory.cancel();

      final activeGalleryBefore = galleryCalls[activeScope]!;
      final inactiveGalleryBefore = galleryCalls[inactiveScope]!;
      final activeHistoryBefore = historyCalls['active-pin']!;
      final inactiveHistoryBefore = historyCalls['inactive-pin']!;
      await owner.refreshActive();
      expect(galleryCalls[activeScope], activeGalleryBefore + 1);
      expect(galleryCalls[inactiveScope], inactiveGalleryBefore);
      expect(historyCalls['active-pin'], activeHistoryBefore + 1);
      expect(historyCalls['inactive-pin'], inactiveHistoryBefore);

      await activeGallery.cancel();
      await activeHistory.cancel();
      await owner.refreshActive();
      expect(galleryCalls[activeScope], activeGalleryBefore + 1);
      expect(historyCalls['active-pin'], activeHistoryBefore + 1);
    },
  );
}
