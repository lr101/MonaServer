import 'dart:async';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/service/photo_library.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

PinEntity pin(String id, {String creator = 'author'}) => PinEntity(
  pinId: id,
  latitude: 0,
  longitude: 0,
  creator: creator,
  groupId: 'group',
  creationDate: DateTime.utc(2026),
  ttl: DateTime.utc(2027),
  lastSynced: DateTime.utc(2026),
  onlySession: false,
);
PinPhotoDto photo(
  String id,
  String pinId, {
  String contributor = 'author',
  bool original = false,
}) => PinPhotoDto(
  id: id,
  pinId: pinId,
  contributorId: contributor,
  contributorUsername: contributor,
  observedAt: DateTime.utc(2026, original ? 1 : 2),
  isOriginal: original,
  image: 'https://image.test/$id.png',
);

void main() {
  late AppDatabase db;
  late PinRepository pins;
  late PinPhotoHistoryRepository histories;
  late PhotoLibrary owner;
  late ProviderContainer container;
  late Future<GalleryPhotoPage> Function(PhotoScope, String?) fetch;
  var historyRequests = 0;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pins = PinRepository(db);
    histories = PinPhotoHistoryRepository(db);
    historyRequests = 0;
    fetch = (_, __) async => const GalleryPhotoPage(items: []);
    owner = PhotoLibrary(
      histories: histories,
      pins: pins,
      fetchPage: (scope, cursor) => fetch(scope, cursor),
      fetchHistory: (_) async {
        historyRequests++;
        throw StateError('Gallery must not request pin histories');
      },
      resolvePhotos: (_) async => {},
      publish: (_, __) {},
    );
    container = ProviderContainer(
      overrides: [
        photoLibraryProvider.overrideWithValue(owner),
        hiddenPostsServiceProvider.overrideWithValue([]),
        hiddenUserServiceProvider.overrideWithValue([]),
      ],
    );
    await pins.ready;
  });
  tearDown(() async {
    container.dispose();
    owner.dispose();
    histories.dispose();
    await db.close();
  });
  for (final scope in [
    const PhotoScope(groupId: 'group'),
    const PhotoScope(userId: 'author'),
  ]) {
    test(
      '${scope.groupId == null ? 'user' : 'group'} gallery retains updates on transient error and retries without remount',
      () async {
        final records = [
          GalleryPhotoRecord(
            pin('place'),
            photo('place', 'place', original: true),
          ),
          GalleryPhotoRecord(pin('place'), photo('update', 'place')),
        ];
        var fail = false;
        fetch = (_, __) async {
          if (fail) throw ApiException(503, 'offline');
          return GalleryPhotoPage(items: records);
        };
        final provider = scope.groupId == null
            ? userPinEntriesProvider('author')
            : groupPinEntriesProvider('group');
        final sub = container.listen(provider, (_, __) {});
        addTearDown(sub.close);
        await container.read(provider.future);
        expect(container.read(provider).requireValue.map((p) => p.entryId), [
          'update',
          'place',
        ]);
        await owner.refreshGallery(scope);
        fail = true;
        await owner.refreshGallery(scope);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(provider).requireValue.map((p) => p.entryId), [
          'update',
          'place',
        ]);
        expect(owner.gallery(scope).error, isNotNull);
        fail = false;
        records.add(GalleryPhotoRecord(pin('place'), photo('new', 'place')));
        await owner.refreshActive();
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(provider).requireValue.map((p) => p.entryId),
          contains('new'),
        );
        expect(historyRequests, 0);
      },
    );
  }
  test(
    'local complete snapshot arrives before delayed gallery discovery',
    () async {
      await pins.put(pin('place'));
      await histories.putMultiple({
        'place': [
          photo('place', 'place', original: true),
          photo('update', 'place'),
        ],
      });
      final pending = Completer<GalleryPhotoPage>();
      fetch = (_, __) => pending.future;
      final provider = groupPinEntriesProvider('group');
      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);
      expect((await container.read(provider.future)).map((p) => p.entryId), [
        'update',
        'place',
      ]);
      pending.complete(const GalleryPhotoPage(items: []));
      await owner.refreshGallery(const PhotoScope(groupId: 'group'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).requireValue, isEmpty);
    },
  );
  test(
    'cold failure remains an error and app resume recovers the mounted gallery',
    () async {
      var fail = true;
      fetch = (_, __) async {
        if (fail) throw ApiException(503, 'offline');
        return GalleryPhotoPage(
          items: [
            GalleryPhotoRecord(
              pin('place'),
              photo('place', 'place', original: true),
            ),
          ],
        );
      };
      final provider = groupPinEntriesProvider('group');
      final sub = container.listen(provider, (_, __) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(provider.future),
        throwsA(isA<ApiException>()),
      );
      fail = false;
      await owner.refreshActive();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).requireValue.single.entryId, 'place');
    },
  );
  test('pagination publishes complete deterministic photos without per-pin history requests', () async {
    final cursors = <String?>[];
    fetch = (_, cursor) async {
      cursors.add(cursor);
      return GalleryPhotoPage(
        items: [
          GalleryPhotoRecord(
            pin(cursor ?? 'first'),
            photo(cursor ?? 'first', cursor ?? 'first', original: true),
          ),
        ],
        nextCursor: cursor == null ? 'next' : null,
      );
    };
    final sub = container.listen(groupPinEntriesProvider('group'), (_, __) {});
    addTearDown(sub.close);
    final entries = await container.read(
      groupPinEntriesProvider('group').future,
    );
    await owner.refreshGallery(const PhotoScope(groupId: 'group'));
    expect(entries.map((p) => p.entryId), ['next', 'first']);
    expect(cursors, [null, 'next']);
    expect(historyRequests, 0);
  });
  test(
    'hidden parent, contributor and pin are excluded before projection',
    () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          photoLibraryProvider.overrideWithValue(owner),
          hiddenPostsServiceProvider.overrideWithValue(['hidden']),
          hiddenUserServiceProvider.overrideWithValue(['blocked']),
        ],
      );
      fetch = (_, __) async => GalleryPhotoPage(
        items: [
          GalleryPhotoRecord(
            pin('blocked-parent', creator: 'blocked'),
            photo('update', 'blocked-parent'),
          ),
          GalleryPhotoRecord(
            pin('hidden'),
            photo('hidden', 'hidden', original: true),
          ),
          GalleryPhotoRecord(
            pin('place'),
            photo('blocked-photo', 'place', contributor: 'blocked'),
          ),
          GalleryPhotoRecord(
            pin('place'),
            photo('place', 'place', original: true),
          ),
        ],
      );
      final sub = container.listen(
        groupPinEntriesProvider('group'),
        (_, __) {},
      );
      addTearDown(sub.close);
      expect(
        (await container.read(groupPinEntriesProvider('group').future))
            .map((p) => p.entryId),
        ['place'],
      );
      await owner.refreshGallery(const PhotoScope(groupId: 'group'));
    },
  );
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
