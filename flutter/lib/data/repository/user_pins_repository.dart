import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_pins_repository.g.dart';

abstract class IUserPinsRepository implements CacheApi<UserPinsEntity>{}

class UserPinsRepository extends CacheImpl<UserPinsEntity> implements IUserPinsRepository {
  final AppDatabase db;

  UserPinsRepository(this.db): super(ttlDuration: const Duration(minutes: 10));

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
    await (db.delete(db.userPinsEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.userPinsEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.userPinsEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<UserPinsEntity?> doGet(int isarId) async {
    final res = await (db.select(db.userPinsEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<UserPinsEntity>> doGetAll() async {
    final res = await db.select(db.userPinsEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<UserPinsEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.userPinsEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.userPinsEntities.isarId.count();
    final query = db.selectOnly(db.userPinsEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<UserPinsEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.userPinsEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(UserPinsEntity item) async {
    await db.into(db.userPinsEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<UserPinsEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.userPinsEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<UserPinsEntity?> doWatchById(int isarId) {
    return (db.select(db.userPinsEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }
}

@Riverpod(keepAlive: true)
IUserPinsRepository userPinsRepository(Ref ref) {
  return UserPinsRepository(ref.watch(driftRepoProvider));
}
