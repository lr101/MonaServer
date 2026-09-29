import 'dart:async';
import 'dart:io';

import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/pending_pin_repository.dart';
import 'package:drift/drift.dart' hide isNull;
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

  test(
    'version 6 database upgrade preserves rows and creates the outbox',
    () async {
      final directory = await Directory.systemTemp.createTemp('pin-outbox-v6-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/posts.sqlite');

      // Build the v6 shape from the current schema, then remove the only v7
      // table and restore SQLite's version marker before running the real v6→v7
      // upgrade on a fresh AppDatabase connection.
      final versionSix = AppDatabase(NativeDatabase(file));
      await versionSix
          .into(versionSix.userEntities)
          .insert(
            UserEntitiesCompanion.insert(
              ttl: DateTime.utc(2027),
              userId: 'account-a',
              username: 'offline-user',
              selectedBatchColor: const Value('peach'),
            ),
          );
      await versionSix.customStatement('DROP TABLE pending_pin_creates');
      await versionSix.customStatement('PRAGMA user_version = 6');
      await versionSix.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final user = await upgraded.select(upgraded.userEntities).getSingle();
      expect(user.userId, 'account-a');
      expect(user.selectedBatchColor, 'peach');

      final repository = PendingPinRepository(upgraded);
      final draft = PinEntity(
        pinId: 'upgraded-draft',
        latitude: 48.1,
        longitude: 11.5,
        creationDate: DateTime.utc(2026, 9, 28),
        creator: 'account-a',
        groupId: 'group-a',
        keepAlive: true,
        onlySession: false,
        ttl: DateTime.now(),
      );
      final image = Uint8List.fromList([5, 6, 7]);
      await repository.enqueue(draft, image);
      expect((await repository.get(draft.pinId))?.image, image);
    },
  );

  test(
    'enqueue fails if the account session is revoked before commit',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final session = AccountSession(true);
      final enqueueStarted = Completer<void>();
      final releaseEnqueue = Completer<void>();
      final repository = _DelayedPendingPinRepository(
        AccountDatabase(database, session),
        enqueueStarted,
        releaseEnqueue,
      );
      final draft = PinEntity(
        pinId: 'revoked-draft',
        latitude: 48.1,
        longitude: 11.5,
        creationDate: DateTime.utc(2026, 9, 28),
        creator: 'account-a',
        groupId: 'group-a',
        keepAlive: true,
        onlySession: false,
        ttl: DateTime.now(),
      );

      final saving = repository.enqueue(draft, Uint8List.fromList([1, 2, 3]));
      await enqueueStarted.future;
      session.revoke();
      releaseEnqueue.complete();

      await expectLater(saving, throwsStateError);
      expect(
        await PendingPinRepository(database).get(draft.pinId),
        isNull,
        reason:
            'a revoked account must not report a suppressed insert as saved',
      );
    },
  );
}

class _DelayedPendingPinRepository extends PendingPinRepository {
  _DelayedPendingPinRepository(super.db, this.started, this.release);

  final Completer<void> started;
  final Completer<void> release;

  @override
  Future<void> enqueue(PinEntity pin, Uint8List image) async {
    started.complete();
    await release.future;
    await super.enqueue(pin, image);
  }
}
