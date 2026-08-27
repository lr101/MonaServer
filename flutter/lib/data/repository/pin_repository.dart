import 'dart:async';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/pin_like_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_repository.g.dart';

abstract class IPinRepository implements CacheApi<PinEntity> {
  Stream<List<PinEntity>> getPinsByGroup(String groupId);
  Stream<List<PinEntity>> getPinsByUser(String userId);
  Future<void> deleteByGroupId(String groupId);
  Future<void> replacePin(String oldPinId, PinEntity newPin);
  Future<void> updateKeepAlive(String groupId, bool keepAlive, bool onlySession);
}

abstract class IPinLikeRepository implements CacheApi<PinLikeEntity> {}

class PinRepository extends CacheImpl<PinEntity> implements IPinRepository {
  final AppDatabase db;

  PinRepository(this.db, {super.maxItems, super.ttlDuration});

  PinEntitiesCompanion _toCompanion(PinEntity entity) {
    return PinEntitiesCompanion(
      pinId: Value(entity.pinId),
      latitude: Value(entity.latitude),
      longitude: Value(entity.longitude),
      creationDate: Value(entity.creationDate),
      description: Value(entity.description),
      creator: Value(entity.creator),
      groupId: Value(entity.groupId),
      isHidden: Value(entity.isHidden),
      lastSynced: Value(entity.lastSynced),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  PinEntity _fromDb(PinDb data) {
    return PinEntity(
      pinId: data.pinId,
      latitude: data.latitude,
      longitude: data.longitude,
      creationDate: data.creationDate,
      description: data.description,
      creator: data.creator,
      groupId: data.groupId,
      isHidden: data.isHidden,
      lastSynced: data.lastSynced,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.pinEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.pinEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.pinEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<PinEntity?> doGet(int isarId) async {
    final res = await (db.select(db.pinEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<PinEntity>> doGetAll() async {
    final res = await db.select(db.pinEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<PinEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.pinEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.pinEntities.isarId.count();
    final query = db.selectOnly(db.pinEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<PinEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.pinEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(PinEntity item) async {
    await db.into(db.pinEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<PinEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.pinEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<PinEntity?> doWatchById(int isarId) {
    return (db.select(db.pinEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }

  @override
  Stream<List<PinEntity>> getPinsByGroup(String groupId) {
    return (db.select(db.pinEntities)..where((tbl) => tbl.groupId.equals(groupId))).watch().map((res) => res.map(_fromDb).toList());
  }

  @override
  Stream<List<PinEntity>> getPinsByUser(String userId) {
    return (db.select(db.pinEntities)..where((tbl) => tbl.creator.equals(userId))).watch().map((res) => res.map(_fromDb).toList());
  }

  @override
  Future<void> deleteByGroupId(String groupId) async {
    await (db.delete(db.pinEntities)..where((tbl) => tbl.groupId.equals(groupId))).go();
  }

  @override
  Future<void> replacePin(String oldPinId, PinEntity newPin) async {
    await db.transaction(() async {
      await (db.delete(db.pinEntities)..where((tbl) => tbl.isarId.equals(fastHash(oldPinId)))).go();
      await db.into(db.pinEntities).insertOnConflictUpdate(_toCompanion(newPin));
    });
  }

  @override
  Future<void> updateKeepAlive(String groupId, bool keepAlive, bool onlySession) async {
    final items = await (db.select(db.pinEntities)..where((tbl) => tbl.groupId.equals(groupId))).get();
    final updated = items.map((e) => _fromDb(e).copyWith(keepAlive: keepAlive, onlySession: onlySession) as PinEntity).toList();
    await putMultiple(updated);
  }
}


class PinLikeRepository extends CacheImpl<PinLikeEntity> implements IPinLikeRepository {
  final AppDatabase db;

  PinLikeRepository(this.db, {super.maxItems, super.ttlDuration});

  PinLikeEntitiesCompanion _toCompanion(PinLikeEntity entity) {
    return PinLikeEntitiesCompanion(
      id: Value(entity.id),
      likeCount: Value(entity.likeCount),
      likePhotographyCount: Value(entity.likePhotographyCount),
      likeLocationCount: Value(entity.likeLocationCount),
      likeArtCount: Value(entity.likeArtCount),
      hasLike: Value(entity.hasLike),
      hasLikePhotography: Value(entity.hasLikePhotography),
      hasLikeLocation: Value(entity.hasLikeLocation),
      hasLikeArt: Value(entity.hasLikeArt),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  PinLikeEntity _fromDb(PinLikeDb data) {
    return PinLikeEntity(
      id: data.id,
      likeCount: data.likeCount,
      likePhotographyCount: data.likePhotographyCount,
      likeLocationCount: data.likeLocationCount,
      likeArtCount: data.likeArtCount,
      hasLikeArt: data.hasLikeArt,
      hasLike: data.hasLike,
      hasLikeLocation: data.hasLikeLocation,
      hasLikePhotography: data.hasLikePhotography,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.pinLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.pinLikeEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.pinLikeEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<PinLikeEntity?> doGet(int isarId) async {
    final res = await (db.select(db.pinLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<PinLikeEntity>> doGetAll() async {
    final res = await db.select(db.pinLikeEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<PinLikeEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.pinLikeEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.pinLikeEntities.isarId.count();
    final query = db.selectOnly(db.pinLikeEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<PinLikeEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.pinLikeEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(PinLikeEntity item) async {
    await db.into(db.pinLikeEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<PinLikeEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.pinLikeEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<PinLikeEntity?> doWatchById(int isarId) {
    return (db.select(db.pinLikeEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }
}

@Riverpod(keepAlive: true)
IPinRepository pinRepository(Ref ref) {
  final db = ref.watch(driftRepoProvider);
  return PinRepository(db);
}

@Riverpod(keepAlive: true)
IPinLikeRepository pinLikeRepository(Ref ref) { 
  final db = ref.watch(driftRepoProvider);
  return PinLikeRepository(db, maxItems: 50, ttlDuration: const Duration(hours: 1));
}
