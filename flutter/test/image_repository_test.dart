import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedImageRepository extends ImageRepository {
  DelayedImageRepository({required super.db, required this.writeGate})
    : super(type: ImageType.pin, getImageUrl: (_) async => null);

  final Future<void> writeGate;

  @override
  Future<void> doPut(ImageEntity item) async {
    await writeGate;
    await super.doPut(item);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'image cleanup prevents an earlier write from repopulating Drift',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final writeGate = Completer<void>();
      final repository = DelayedImageRepository(
        db: database,
        writeGate: writeGate.future,
      );

      final write = repository.addImage(
        'old-account-image',
        Uint8List.fromList([1, 2, 3]),
        false,
      );
      await Future<void>.delayed(Duration.zero);

      final cleanup = repository.deleteAll();
      await Future<void>.delayed(Duration.zero);
      writeGate.complete();
      await Future.wait([write, cleanup]);

      expect(await repository.getAll(), isEmpty);
    },
  );
}
