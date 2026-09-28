import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pendingPinRepositoryProvider = Provider<PendingPinRepository>((ref) {
  return PendingPinRepository(ref.watch(accountDatabaseProvider));
});

/// One row contains both the request and its image, so a process exit cannot
/// leave a post queued without the bytes needed to send it.
class PendingPinRepository {
  PendingPinRepository(this.db);

  final AppDatabase db;

  Future<void> enqueue(PinEntity pin, Uint8List image) async {
    await db
        .into(db.pendingPinCreates)
        .insertOnConflictUpdate(
          PendingPinCreatesCompanion.insert(
            pinId: pin.pinId,
            ownerId: pin.creator,
            groupId: pin.groupId,
            latitude: pin.latitude,
            longitude: pin.longitude,
            creationDate: pin.creationDate,
            title: Value(pin.title),
            description: Value(pin.description),
            image: image,
          ),
        );
  }

  Future<List<PendingPinCreateDb>> forOwner(String ownerId) =>
      (db.select(db.pendingPinCreates)
            ..where((row) => row.ownerId.equals(ownerId))
            ..orderBy([(row) => OrderingTerm.asc(row.creationDate)]))
          .get();

  Future<PendingPinCreateDb?> get(String pinId) => (db.select(
    db.pendingPinCreates,
  )..where((row) => row.pinId.equals(pinId))).getSingleOrNull();

  Future<void> requestCancel(String pinId) async {
    await (db.update(db.pendingPinCreates)
          ..where((row) => row.pinId.equals(pinId)))
        .write(const PendingPinCreatesCompanion(cancelRequested: Value(true)));
  }

  Future<void> markAttempted(String pinId) async {
    await (db.update(db.pendingPinCreates)
          ..where((row) => row.pinId.equals(pinId)))
        .write(const PendingPinCreatesCompanion(attempted: Value(true)));
  }

  Future<void> remove(String pinId) async {
    await (db.delete(
      db.pendingPinCreates,
    )..where((row) => row.pinId.equals(pinId))).go();
  }

  Future<void> recordError(String pinId, String error) async {
    await (db.update(db.pendingPinCreates)
          ..where((row) => row.pinId.equals(pinId)))
        .write(PendingPinCreatesCompanion(lastError: Value(error)));
  }
}
