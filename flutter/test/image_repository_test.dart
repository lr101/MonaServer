import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedImageRepository extends ImageRepository {
  DelayedImageRepository({
    required super.db,
    required this.writeGate,
    required this.writeStarted,
  }) : super(type: ImageType.pin, getImageUrl: (_) async => null);

  final Future<void> writeGate;
  final Completer<void> writeStarted;

  @override
  Future<void> doPut(ImageEntity item) async {
    writeStarted.complete();
    await writeGate;
    await super.doPut(item);
  }
}

class DelayedReadImageRepository extends ImageRepository {
  DelayedReadImageRepository({
    required super.db,
    required this.readGate,
    required this.readStarted,
    Future<String?> Function(String)? getImageUrl,
  }) : super(
         type: ImageType.pin,
         getImageUrl: getImageUrl ?? (_) async => null,
       );

  final Future<void> readGate;
  final Completer<void> readStarted;

  @override
  Future<ImageEntity?> doGet(int isarId) async {
    final result = await super.doGet(isarId);
    if (!readStarted.isCompleted) {
      readStarted.complete();
      await readGate;
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cleanup from a newer repository evicts an older repository write',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final writeGate = Completer<void>();
      final writeStarted = Completer<void>();
      final oldRepository = DelayedImageRepository(
        db: database,
        writeGate: writeGate.future,
        writeStarted: writeStarted,
      );
      final newRepository = ImageRepository(
        db: database,
        type: ImageType.pin,
        getImageUrl: (_) async => null,
      );
      final image = Uint8List.fromList(const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        0,
        13,
        73,
        68,
        65,
        84,
        8,
        215,
        99,
        248,
        207,
        192,
        240,
        31,
        0,
        5,
        0,
        1,
        255,
        137,
        153,
        61,
        29,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ]);
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      addTearDown(cache.clear);

      final write = oldRepository.addImage('old-account-image', image, false);
      await writeStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(cache.containsKey(MemoryImage(image)), isTrue);

      final cleanup = newRepository.deleteAll();
      await Future<void>.delayed(Duration.zero);
      writeGate.complete();
      await Future.wait([write, cleanup]);

      expect(await newRepository.getAll(), isEmpty);
      expect(cache.containsKey(MemoryImage(image)), isFalse);
    },
  );

  test('fetch does not precache a row read before cleanup', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final image = Uint8List.fromList([1, 2, 3]);
    await database
        .into(database.imageEntities)
        .insert(
          ImageEntitiesCompanion.insert(
            ttl: DateTime(2026),
            isarId: Value(fastHash('pin_old-account-image')),
            id: 'old-account-image',
            type: ImageType.pin,
            image: Value(image),
          ),
        );
    final readGate = Completer<void>();
    final readStarted = Completer<void>();
    final oldRepository = DelayedReadImageRepository(
      db: database,
      readGate: readGate.future,
      readStarted: readStarted,
    );
    final newRepository = ImageRepository(
      db: database,
      type: ImageType.pin,
      getImageUrl: (_) async => null,
    );
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    addTearDown(cache.clear);

    final fetch = oldRepository.fetchImage('old-account-image', false);
    await readStarted.future;
    final cleanup = newRepository.deleteAll();
    await cleanup;
    expect(await database.select(database.imageEntities).get(), isEmpty);
    readGate.complete();

    expect(await fetch, isNull);
    expect(cache.containsKey(MemoryImage(image)), isFalse);
    expect(await newRepository.getAll(), isEmpty);
  });

  test(
    'a cache miss that started before cleanup cannot write after it',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final readGate = Completer<void>();
      final readStarted = Completer<void>();
      var getUrlCalls = 0;
      final oldRepository = DelayedReadImageRepository(
        db: database,
        readGate: readGate.future,
        readStarted: readStarted,
        getImageUrl: (_) async {
          getUrlCalls++;
          return null;
        },
      );
      final newRepository = ImageRepository(
        db: database,
        type: ImageType.pin,
        getImageUrl: (_) async => null,
      );

      final fetch = oldRepository.fetchImage('old-account-image', false);
      await readStarted.future;
      await newRepository.deleteAll();
      readGate.complete();

      expect(await fetch, isNull);
      expect(getUrlCalls, 0);
      expect(await newRepository.getAll(), isEmpty);
    },
  );
}
