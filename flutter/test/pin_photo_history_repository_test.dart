import 'dart:io';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  test('upgrades version 9 databases with photo history storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pin-photo-history-v9-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databaseFile = File('${directory.path}/app.sqlite');

    final versionNineDatabase = AppDatabase(NativeDatabase(databaseFile));
    await versionNineDatabase.customStatement(
      'DROP TABLE pin_photo_history_entities',
    );
    await versionNineDatabase.customStatement('PRAGMA user_version = 9');
    await versionNineDatabase.close();

    final database = AppDatabase(NativeDatabase(databaseFile));
    addTearDown(database.close);
    final repository = PinPhotoHistoryRepository(database);

    await repository.putMultiple({
      'place': [
        PinPhotoDto(
          id: 'update',
          pinId: 'place',
          contributorId: 'alice',
          contributorUsername: 'Alice',
          image: 'https://example.test/update.png',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
        ),
      ],
    });

    expect((await repository.get('place'))?.photos.single.id, 'update');
  });

  test('migrates version 7 databases and persists photo histories', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (database) => database.execute('PRAGMA user_version = 7'),
      ),
    );
    addTearDown(db.close);
    final repository = PinPhotoHistoryRepository(db);

    await repository.putMultiple({
      'place': [
        PinPhotoDto(
          id: 'update',
          pinId: 'place',
          contributorId: 'alice',
          contributorUsername: 'Alice',
          image: 'https://example.test/update.png',
          caption: 'Still here',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
        ),
      ],
    });

    final cached = await repository.get('place');
    expect(cached?.photos.single.id, 'update');
    expect(cached?.photos.single.image, 'https://example.test/update.png');
    expect(cached?.photos.single.caption, 'Still here');
    expect(cached?.fetchedAt, isNotNull);
  });
}
