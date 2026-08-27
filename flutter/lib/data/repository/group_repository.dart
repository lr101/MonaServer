import 'dart:async';

import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart'; // We will create this
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_repository.g.dart';

abstract class IGroupRepository implements CacheApi<GroupEntity> {
  Stream<List<GroupEntity>> watchUserGroups();
  Stream<List<GroupEntity>> watchAllGroups();
}

class GroupRepository extends CacheImpl<GroupEntity> implements IGroupRepository {
  final AppDatabase db;

  GroupRepository(this.db, {super.maxItems, super.ttlDuration});

  GroupEntitiesCompanion _toCompanion(GroupEntity entity) {
    return GroupEntitiesCompanion(
      groupId: Value(entity.groupId),
      name: Value(entity.name),
      visibility: Value(entity.visibility),
      userIsMember: Value(entity.userIsMember),
      inviteUrl: Value(entity.inviteUrl),
      groupAdmin: Value(entity.groupAdmin),
      description: Value(entity.description),
      isActivated: Value(entity.isActivated),
      lastUpdated: Value(entity.lastUpdated),
      link: Value(entity.link),
      bestSeason: Value(entity.bestSeason),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  GroupEntity _fromDb(GroupDb data) {
    return GroupEntity(
      groupId: data.groupId,
      name: data.name,
      visibility: data.visibility,
      userIsMember: data.userIsMember,
      inviteUrl: data.inviteUrl,
      groupAdmin: data.groupAdmin,
      description: data.description,
      isActivated: data.isActivated,
      lastUpdated: data.lastUpdated,
      link: data.link,
      bestSeason: data.bestSeason,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.groupEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.groupEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.groupEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<GroupEntity?> doGet(int isarId) async {
    final res = await (db.select(db.groupEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    if (res == null) return null;
    return _fromDb(res);
  }

  @override
  Future<List<GroupEntity>> doGetAll() async {
    final res = await db.select(db.groupEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<GroupEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.groupEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.groupEntities.isarId.count();
    final query = db.selectOnly(db.groupEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<GroupEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.groupEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(GroupEntity item) async {
    await db.into(db.groupEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<GroupEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.groupEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<GroupEntity?> doWatchById(int isarId) {
    return (db.select(db.groupEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }

  @override
  Stream<List<GroupEntity>> watchUserGroups() {
    return (db.select(db.groupEntities)..where((tbl) => tbl.userIsMember.equals(true))).watch().map((res) => res.map(_fromDb).toList());
  }

  @override
  Stream<List<GroupEntity>> watchAllGroups() {
    return db.select(db.groupEntities).watch().map((res) => res.map(_fromDb).toList());
  }
}

@Riverpod(keepAlive: true)
IGroupRepository groupRepository(Ref ref) {
  final db = ref.watch(driftRepoProvider);
  return GroupRepository(db);
}
