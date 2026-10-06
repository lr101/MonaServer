import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_photo_history_repository.g.dart';

class CachedPinPhotoHistory {
  const CachedPinPhotoHistory({required this.photos, required this.fetchedAt});

  final List<PinPhotoDto> photos;
  final DateTime fetchedAt;
}

abstract interface class IPinPhotoHistoryRepository {
  Stream<int> watchChanges();
  Future<CachedPinPhotoHistory?> get(String pinId);
  Future<Map<String, CachedPinPhotoHistory>> getMultiple(
    Iterable<String> pinIds,
  );
  Future<void> putMultiple(Map<String, List<PinPhotoDto>> photosByPin);
  Future<void> deleteMultiple(Iterable<String> pinIds);
}

class PinPhotoHistoryRepository implements IPinPhotoHistoryRepository {
  PinPhotoHistoryRepository(this.db);

  final AppDatabase db;
  final StreamController<int> _changes = StreamController<int>.broadcast(
    sync: true,
  );
  var _revision = 0;

  @override
  Stream<int> watchChanges() async* {
    yield _revision;
    yield* _changes.stream;
  }

  void dispose() {
    unawaited(_changes.close());
  }

  @override
  Future<CachedPinPhotoHistory?> get(String pinId) async {
    final row = await (db.select(
      db.pinPhotoHistoryEntities,
    )..where((history) => history.pinId.equals(pinId))).getSingleOrNull();
    return row == null ? null : _fromDb(row);
  }

  @override
  Future<Map<String, CachedPinPhotoHistory>> getMultiple(
    Iterable<String> pinIds,
  ) async {
    final ids = pinIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = <PinPhotoHistoryDb>[];
    const batchSize = 500;
    for (var start = 0; start < ids.length; start += batchSize) {
      final batch = ids.skip(start).take(batchSize).toList();
      rows.addAll(
        await (db.select(
          db.pinPhotoHistoryEntities,
        )..where((history) => history.pinId.isIn(batch))).get(),
      );
    }
    return {for (final row in rows) row.pinId: _fromDb(row)};
  }

  @override
  Future<void> putMultiple(Map<String, List<PinPhotoDto>> photosByPin) async {
    if (photosByPin.isEmpty) return;
    final fetchedAt = DateTime.now().toUtc();
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.pinPhotoHistoryEntities,
        photosByPin.entries
            .map(
              (entry) => PinPhotoHistoryEntitiesCompanion.insert(
                pinId: entry.key,
                photosJson: jsonEncode(
                  entry.value.map((photo) => photo.toJson()).toList(),
                ),
                fetchedAt: fetchedAt,
              ),
            )
            .toList(),
      );
    });
    _changes.add(++_revision);
  }

  @override
  Future<void> deleteMultiple(Iterable<String> pinIds) async {
    final ids = pinIds.toSet().toList();
    if (ids.isEmpty) return;
    const batchSize = 500;
    for (var start = 0; start < ids.length; start += batchSize) {
      final batch = ids.skip(start).take(batchSize).toList();
      await (db.delete(
        db.pinPhotoHistoryEntities,
      )..where((history) => history.pinId.isIn(batch))).go();
    }
    _changes.add(++_revision);
  }

  CachedPinPhotoHistory _fromDb(PinPhotoHistoryDb row) {
    final photos = (jsonDecode(row.photosJson) as List)
        .map((value) => PinPhotoDto.fromJson(value))
        .whereType<PinPhotoDto>()
        .toList(growable: false);
    return CachedPinPhotoHistory(photos: photos, fetchedAt: row.fetchedAt);
  }
}

@Riverpod(keepAlive: true)
IPinPhotoHistoryRepository pinPhotoHistoryRepository(Ref ref) {
  final repository = PinPhotoHistoryRepository(
    ref.watch(accountDatabaseProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}
