import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
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
}
