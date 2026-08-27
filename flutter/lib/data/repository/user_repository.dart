import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/entity/user_like_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repository.g.dart';

abstract class IUserRepository implements CacheApi<UserEntity>{}
abstract class IUserLikeRepository implements CacheApi<UserLikeEntity>{}


class UserRepository extends CacheImpl<UserEntity> implements IUserRepository {
  final AppDatabase db;
  UserRepository(this.db, {super.maxItems = 500, super.ttlDuration = const Duration(days: 1)});

  UserEntitiesCompanion _toCompanion(UserEntity entity) {
    return UserEntitiesCompanion(
      userId: Value(entity.userId),
      username: Value(entity.username),
      selectedBatch: Value(entity.selectedBatch),
      description: Value(entity.description),
      bestSeason: Value(entity.bestSeason),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  UserEntity _fromDb(UserDb data) {
    return UserEntity(
      userId: data.userId,
      username: data.username,
      selectedBatch: data.selectedBatch,
      description: data.description,
      bestSeason: data.bestSeason,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.userEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.userEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.userEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<UserEntity?> doGet(int isarId) async {
    final res = await (db.select(db.userEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<UserEntity>> doGetAll() async {
    final res = await db.select(db.userEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<UserEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.userEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.userEntities.isarId.count();
    final query = db.selectOnly(db.userEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<UserEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.userEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(UserEntity item) async {
    await db.into(db.userEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<UserEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.userEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<UserEntity?> doWatchById(int isarId) {
    return (db.select(db.userEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }
}

class UserLikeRepository extends CacheImpl<UserLikeEntity> implements IUserLikeRepository{
  final AppDatabase db;
  UserLikeRepository(this.db, {super.maxItems = 50, super.ttlDuration = const Duration(days: 1)});

  UserLikeEntitiesCompanion _toCompanion(UserLikeEntity entity) {
    return UserLikeEntitiesCompanion(
      userId: Value(entity.userId),
      likeCount: Value(entity.likeCount),
      likePhotographyCount: Value(entity.likePhotographyCount),
      likeLocationCount: Value(entity.likeLocationCount),
      likeArtCount: Value(entity.likeArtCount),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  UserLikeEntity _fromDb(UserLikeDb data) {
    return UserLikeEntity(
      userId: data.userId,
      likeCount: data.likeCount,
      likePhotographyCount: data.likePhotographyCount,
      likeLocationCount: data.likeLocationCount,
      likeArtCount: data.likeArtCount,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.userLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.userLikeEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.userLikeEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<UserLikeEntity?> doGet(int isarId) async {
    final res = await (db.select(db.userLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<UserLikeEntity>> doGetAll() async {
    final res = await db.select(db.userLikeEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<UserLikeEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.userLikeEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.userLikeEntities.isarId.count();
    final query = db.selectOnly(db.userLikeEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<UserLikeEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.userLikeEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(UserLikeEntity item) async {
    await db.into(db.userLikeEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<UserLikeEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.userLikeEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<UserLikeEntity?> doWatchById(int isarId) {
    return (db.select(db.userLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }
}

@Riverpod(keepAlive: true)
IUserRepository userRepository(Ref ref) {
  return UserRepository(ref.watch(driftRepoProvider)); 
}

@Riverpod(keepAlive: true)
IUserLikeRepository userLikeRepository(Ref ref) {
  return UserLikeRepository(ref.watch(driftRepoProvider));
}
