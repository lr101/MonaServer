import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
