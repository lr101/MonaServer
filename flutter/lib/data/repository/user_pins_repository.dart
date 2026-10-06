import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_pins_repository.g.dart';

abstract class IUserPinsRepository implements CacheApi<UserPinsEntity> {
  Future<void> ensurePinIndexed(String userId, String pinId);

  Future<void> replacePinIdWithUploaded(
    String userId,
    String pendingPinId,
    String uploadedPinId,
  );
}

class UserPinsRepository extends CacheImpl<UserPinsEntity>
    implements IUserPinsRepository {
  final AppDatabase db;

  UserPinsRepository(this.db) : super(ttlDuration: const Duration(minutes: 10));

  @override
  Future<void> ensurePinIndexed(String userId, String pinId) async {
    await ready;
    await db.transaction(() async {
      final row =
          await (db.select(db.userPinsEntities)
                ..where((entity) => entity.isarId.equals(cacheIdFor(userId))))
              .getSingleOrNull();
      final profile = row == null
          ? UserPinsEntity(
              userId: userId,
              pins: const [],
              keepAlive: true,
              ttl: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              onlySession: false,
            )
          : _fromDb(row);
      if (profile.pins.contains(pinId)) return;

      await db
          .into(db.userPinsEntities)
          .insertOnConflictUpdate(
            _toCompanion(
              UserPinsEntity(
                userId: profile.userId,
                pins: [...profile.pins, pinId],
                keepAlive: profile.keepAlive,
                hits: profile.hits,
                ttl: profile.ttl,
                onlySession: profile.onlySession,
              ),
            ),
          );
    });
  }

  @override
  Future<void> replacePinIdWithUploaded(
    String userId,
    String pendingPinId,
    String uploadedPinId,
  ) async {
    await ready;
    await db.transaction(() async {
      final row =
          await (db.select(db.userPinsEntities)
                ..where((entity) => entity.isarId.equals(cacheIdFor(userId))))
              .getSingleOrNull();
      if (row == null) return;

      final profile = _fromDb(row);
      final pins = List<String>.of(profile.pins)
        ..removeWhere((pinId) => pinId == pendingPinId);
      if (!pins.contains(uploadedPinId)) pins.add(uploadedPinId);
      var unchanged = pins.length == profile.pins.length;
      for (var i = 0; unchanged && i < pins.length; i++) {
        unchanged = pins[i] == profile.pins[i];
      }
      if (unchanged) return;

      await db
          .into(db.userPinsEntities)
          .insertOnConflictUpdate(
            _toCompanion(
              UserPinsEntity(
                userId: profile.userId,
                pins: pins,
                keepAlive: profile.keepAlive,
                hits: profile.hits,
                ttl: profile.ttl,
                onlySession: profile.onlySession,
              ),
            ),
          );
    });
  }

  UserPinsEntitiesCompanion _toCompanion(UserPinsEntity entity) {
    return UserPinsEntitiesCompanion(
      userId: Value(entity.userId),
      pins: Value(entity.pins),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  UserPinsEntity _fromDb(UserPinsDb data) {
    return UserPinsEntity(
      userId: data.userId,
      pins: data.pins,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(
      db.userPinsEntities,
    )..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.userPinsEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(
      db.userPinsEntities,
    )..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<UserPinsEntity?> doGet(int isarId) async {
    final res = await (db.select(
      db.userPinsEntities,
    )..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<UserPinsEntity>> doGetAll() async {
    final res = await db.select(db.userPinsEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<UserPinsEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(
      db.userPinsEntities,
    )..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.userPinsEntities.isarId.count();
    final query = db.selectOnly(db.userPinsEntities)..addColumns([countExp]);
    final result = await query.getSingleOrNull();
    return result?.read(countExp) ?? 0;
  }

  @override
  Future<List<UserPinsEntity>> doGetSortedByHits() async {
    final res = await (db.select(
      db.userPinsEntities,
    )..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(UserPinsEntity item) async {
    await db
        .into(db.userPinsEntities)
        .insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<UserPinsEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.userPinsEntities,
        items.map(_toCompanion).toList(),
      );
    });
  }

  @override
  Stream<UserPinsEntity?> doWatchById(int isarId) {
    return (db.select(db.userPinsEntities)
          ..where((tbl) => tbl.isarId.equals(isarId)))
        .watchSingleOrNull()
        .map((res) => res == null ? null : _fromDb(res));
  }
}

@Riverpod(keepAlive: true)
IUserPinsRepository userPinsRepository(Ref ref) {
  return UserPinsRepository(ref.watch(accountDatabaseProvider));
}
