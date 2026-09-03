import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('image cache operations keep image types isolated', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final largeRepository = _repository(database, ImageType.group);
    final smallRepository = _repository(database, ImageType.groupSmall);

    await largeRepository.addImage('group-1', Uint8List.fromList([1]), false);
    await smallRepository.addImage('group-1', Uint8List.fromList([2]), false);

    expect((await largeRepository.get('group-1'))!.image, [1]);
    expect((await smallRepository.get('group-1'))!.image, [2]);

    await largeRepository.delete('group-1');

    expect(await largeRepository.get('group-1'), isNull);
    expect(await smallRepository.get('group-1'), isNotNull);
  });

  test('expired empty entries are fetched again', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var urlLookups = 0;
    final repository = ImageRepository(
      db: database,
      type: ImageType.groupSmall,
      getImageUrl: (_) async {
        urlLookups++;
        return null;
      },
      maxItems: 10,
      ttlDuration: const Duration(days: 7),
    );
    await repository.ready;

    await repository.doPut(
      ImageEntity(
        id: 'group-1',
        type: ImageType.groupSmall,
        image: Uint8List(0),
        ttl: DateTime.now().subtract(const Duration(minutes: 1)),
        onlySession: false,
      ),
    );

    await repository.fetchImage('group-1', false);

    expect(urlLookups, 1);
  });

  test(
    'URL image loads revalidate expired bytes and promote keep alive',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var endpointLookups = 0;
      final requestedPaths = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.groupSmall,
        getImageUrl: (_) async {
          endpointLookups++;
          return 'https://example.com/endpoint';
        },
        httpGet: (uri) async {
          requestedPaths.add(uri.path);
          return http.Response.bytes([2], 200);
        },
        maxItems: 10,
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.groupSmall,
          image: Uint8List.fromList([1]),
          ttl: DateTime.now().subtract(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final image = await repository.fetchImageFromUrl(
        'group-1',
        'https://example.com/search',
        true,
      );

      expect(image, [2]);
      expect(requestedPaths, ['/search']);
      expect(endpointLookups, 0);
      expect((await repository.get('group-1'))!.keepAlive, isTrue);
    },
  );

  test(
    'URL failures bypass fresh empty cache rows for endpoint fallback',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var endpointLookups = 0;
      final requestedPaths = <String>[];
      final repository = ImageRepository(
        db: database,
        type: ImageType.groupSmall,
        getImageUrl: (_) async {
          endpointLookups++;
          return 'https://example.com/endpoint';
        },
        httpGet: (uri) async {
          requestedPaths.add(uri.path);
          if (uri.path == '/search') return http.Response.bytes([], 500);
          return http.Response.bytes([3], 200);
        },
        maxItems: 10,
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.groupSmall,
          image: Uint8List(0),
          ttl: DateTime.now().add(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final image = await repository.fetchImageFromUrl(
        'group-1',
        'https://example.com/search',
        false,
      );

      expect(image, [3]);
      expect(requestedPaths, ['/search', '/endpoint']);
      expect(endpointLookups, 1);
      expect((await repository.get('group-1'))!.image, [3]);
    },
  );

  test('migrates legacy image rows to stable composite keys', () async {
    final nativeDatabase = sqlite3.openInMemory();
    final initialDatabase = AppDatabase(
      NativeDatabase.opened(nativeDatabase, closeUnderlyingOnClose: false),
    );
    await initialDatabase.customSelect('SELECT 1').get();
    await initialDatabase.close();

    nativeDatabase.execute('DROP TABLE image_entities');
    nativeDatabase.execute('''
      CREATE TABLE image_entities (
        isar_id INTEGER NOT NULL PRIMARY KEY,
        ttl INTEGER NOT NULL,
        hits INTEGER NOT NULL DEFAULT 1,
        keep_alive INTEGER NOT NULL DEFAULT 0,
        only_session INTEGER NOT NULL DEFAULT 0,
        id TEXT NOT NULL,
        type INTEGER NOT NULL,
        image BLOB
      )
    ''');
    nativeDatabase.execute(
      'INSERT INTO image_entities '
      '(isar_id, ttl, id, type, image) VALUES (?, ?, ?, ?, ?)',
      [
        1,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'group-1',
        4,
        [1],
      ],
    );
    nativeDatabase.execute('PRAGMA user_version = 1');

    final migratedDatabase = AppDatabase(
      NativeDatabase.opened(nativeDatabase, closeUnderlyingOnClose: false),
    );
    addTearDown(() async {
      await migratedDatabase.close();
      nativeDatabase.close();
    });

    final rows = await migratedDatabase
        .select(migratedDatabase.imageEntities)
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.cacheKey, 'groupSmall:group-1');
    expect(rows.single.type, ImageType.groupSmall);
  });

  test('active image watchers are protected from cache pruning', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall, maxItems: 1);

    final ids = ['active', 'other-1', 'other-2']
      ..sort(
        (left, right) =>
            ImageEntity(
              id: left,
              type: ImageType.groupSmall,
              image: Uint8List(0),
              ttl: DateTime.now(),
              onlySession: false,
            ).isarId.compareTo(
              ImageEntity(
                id: right,
                type: ImageType.groupSmall,
                image: Uint8List(0),
                ttl: DateTime.now(),
                onlySession: false,
              ).isarId,
            ),
      );

    final activeId = ids.first;
    final watcher = repository.watchImageBytes(activeId).listen((_) {});
    addTearDown(watcher.cancel);

    await repository.addImage(activeId, Uint8List.fromList([1]), false);
    await repository.addImage(ids[1], Uint8List.fromList([2]), false);
    await repository.addImage(ids[2], Uint8List.fromList([3]), false);

    expect((await repository.get(activeId))!.image, [1]);
  });

  test('metadata-only updates preserve the watched byte buffer', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall);
    final firstImage = Completer<Uint8List>();

    final subscription = repository.watchImageBytes('group-1').listen((image) {
      if (image == null) return;
      if (!firstImage.isCompleted) {
        firstImage.complete(image);
      }
    });
    addTearDown(subscription.cancel);

    await repository.addImage('group-1', Uint8List.fromList([1, 2, 3]), false);
    final first = await firstImage.future;

    final fetched = await repository.fetchImage('group-1', false);

    expect(identical(first, fetched), isTrue);
  });

  test('metadata-only updates do not re-emit watched image bytes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _repository(database, ImageType.groupSmall);
    final iterator = StreamIterator<Uint8List?>(
      repository.watchImageBytes('group-1'),
    );
    addTearDown(iterator.cancel);

    await repository.addImage('group-1', Uint8List.fromList([1, 2, 3]), false);
    while (await iterator.moveNext() && iterator.current == null) {}
    expect(iterator.current, isNotNull);

    await repository.fetchImage('group-1', false);

    final hasSecondEmission = await iterator.moveNext().timeout(
      const Duration(milliseconds: 100),
      onTimeout: () => false,
    );
    expect(hasSecondEmission, isFalse);
  });

  test('a late public fetch cannot overwrite a joined image cache', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final publicRequestStarted = Completer<void>();
    final releasePublicResponse = Completer<void>();
    final releaseJoinedResponse = Completer<void>();
    final repository = ImageRepository(
      db: database,
      type: ImageType.group,
      getImageUrl: (_) async => 'https://example.com/public',
      httpGet: (uri) async {
        if (uri.path == '/public') {
          if (!publicRequestStarted.isCompleted) {
            publicRequestStarted.complete();
          }
          await releasePublicResponse.future;
          return http.Response.bytes([1], 200);
        }
        await releaseJoinedResponse.future;
        return http.Response.bytes([2], 200);
      },
      ttlDuration: const Duration(days: 7),
    );
    await repository.ready;

    final joinedOverride = repository.overrideUrl(
      'group-1',
      'https://example.com/joined',
      true,
    );
    final publicFetch = repository.fetchImage('group-1', false);
    await publicRequestStarted.future;
    final joinedFetch = repository.fetchImage('group-1', true);

    releaseJoinedResponse.complete();
    await joinedOverride;
    expect((await repository.get('group-1'))!.image, [2]);
    expect((await repository.get('group-1'))!.keepAlive, isTrue);

    releasePublicResponse.complete();
    await publicFetch;
    await joinedFetch;

    final cached = await repository.get('group-1');
    expect(cached!.image, [2]);
    expect(cached.keepAlive, isTrue);
  });

  test('a shared empty fetch promotes the image cache to keep alive', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final urlLookupStarted = Completer<void>();
    final releaseUrlLookup = Completer<void>();
    final repository = ImageRepository(
      db: database,
      type: ImageType.group,
      getImageUrl: (_) async {
        urlLookupStarted.complete();
        await releaseUrlLookup.future;
        return null;
      },
      ttlDuration: const Duration(days: 7),
    );
    await repository.ready;

    final publicFetch = repository.fetchImage('group-1', false);
    await urlLookupStarted.future;
    final joinedFetch = repository.fetchImage('group-1', true);

    releaseUrlLookup.complete();
    await publicFetch;
    await joinedFetch;

    final cached = await repository.get('group-1');
    expect(cached!.image, isEmpty);
    expect(cached.keepAlive, isTrue);
  });

  test(
    'a deduplicated stale fetch promotes the image cache to keep alive',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final urlLookupStarted = Completer<void>();
      final releaseUrlLookup = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async {
          urlLookupStarted.complete();
          await releaseUrlLookup.future;
          return null;
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;
      await repository.doPut(
        ImageEntity(
          id: 'group-1',
          type: ImageType.group,
          image: Uint8List.fromList([1]),
          ttl: DateTime.now().subtract(const Duration(minutes: 1)),
          onlySession: false,
        ),
      );

      final publicFetch = repository.fetchImage('group-1', false);
      final joinedFetch = repository.fetchImage('group-1', true);
      await urlLookupStarted.future;

      releaseUrlLookup.complete();
      await publicFetch;
      await joinedFetch;

      expect((await repository.get('group-1'))!.keepAlive, isTrue);
    },
  );

  test(
    'a failed override does not discard an image fetch already in flight',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final publicRequestStarted = Completer<void>();
      final releasePublicResponse = Completer<void>();
      final releaseOverrideResponse = Completer<void>();
      final repository = ImageRepository(
        db: database,
        type: ImageType.group,
        getImageUrl: (_) async => 'https://example.com/public',
        httpGet: (uri) async {
          if (uri.path == '/public') {
            publicRequestStarted.complete();
            await releasePublicResponse.future;
            return http.Response.bytes([1], 200);
          }
          await releaseOverrideResponse.future;
          return http.Response.bytes([], 500);
        },
        ttlDuration: const Duration(days: 7),
      );
      await repository.ready;

      final publicFetch = repository.fetchImage('group-1', false);
      await publicRequestStarted.future;

      releasePublicResponse.complete();
      final failedOverride = repository.overrideUrl(
        'group-1',
        'https://example.com/joined',
        true,
      );
      releaseOverrideResponse.complete();

      await expectLater(failedOverride, throwsException);
      await publicFetch;

      expect((await repository.get('group-1'))!.image, [1]);
    },
  );
}

ImageRepository _repository(
  AppDatabase database,
  ImageType type, {
  int maxItems = 10,
}) {
  return ImageRepository(
    db: database,
    type: type,
    getImageUrl: (_) async => null,
    maxItems: maxItems,
    ttlDuration: const Duration(days: 7),
  );
}
