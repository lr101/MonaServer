import 'dart:io';
import 'dart:typed_data';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/pending_pin_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queued post and image survive a database restart', () async {
    final directory = await Directory.systemTemp.createTemp('pin-outbox-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/posts.sqlite');
    final draft = PinEntity(
      pinId: 'draft-id',
      latitude: 48.1,
      longitude: 11.5,
      creationDate: DateTime.utc(2026, 9, 28),
      creator: 'account-a',
      groupId: 'group-a',
      title: 'Offline post',
      keepAlive: true,
      onlySession: false,
      ttl: DateTime.now(),
    );
    final image = Uint8List.fromList([1, 2, 3, 4]);

    final first = AppDatabase(NativeDatabase(file));
    await PendingPinRepository(first).enqueue(draft, image);
    await first.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final repository = PendingPinRepository(reopened);
    final rows = await repository.forOwner('account-a');
    expect(rows, hasLength(1));
    expect(rows.single.pinId, draft.pinId);
    expect(rows.single.title, draft.title);
    expect(rows.single.image, image);
    expect(await repository.forOwner('account-b'), isEmpty);
    await repository.markAttempted(draft.pinId);
    await repository.requestCancel(draft.pinId);
    expect((await repository.get(draft.pinId))?.cancelRequested, isTrue);
    expect((await repository.get(draft.pinId))?.attempted, isTrue);
  });
}
