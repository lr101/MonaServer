import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
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
