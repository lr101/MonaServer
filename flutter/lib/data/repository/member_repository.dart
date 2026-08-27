import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'member_repository.g.dart';


abstract class IMemberRepository implements CacheApi<MembersEntity> {}

class MemberRepository extends CacheImpl<MembersEntity> implements IMemberRepository {
  final AppDatabase db;

  MemberRepository(this.db, {super.maxItems, super.ttlDuration = const Duration(days: 1)});

  MemberEntitiesCompanion _toCompanion(MembersEntity entity) {
    return MemberEntitiesCompanion(
      groupId: Value(entity.groupId),
      members: Value(entity.members.map((e) => {
        'userId': e.userId,
        'points': e.points,
        'username': e.username,
        'selectedBatch': e.selectedBatch,
      }).toList()),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
    );
  }

  MembersEntity _fromDb(MemberDb data) {
    return MembersEntity(
      groupId: data.groupId,
      members: data.members.map((e) => MemberEntity(
        userId: e['userId'] as String? ?? '',
        points: e['points'] as int? ?? 0,
        username: e['username'] as String? ?? '',
        selectedBatch: e['selectedBatch'] as int?,
      )).toList(),
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
    );
  }

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.memberEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await db.delete(db.memberEntities).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.memberEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<MembersEntity?> doGet(int isarId) async {
    final res = await (db.select(db.memberEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<MembersEntity>> doGetAll() async {
    final res = await db.select(db.memberEntities).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<MembersEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.memberEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.memberEntities.isarId.count();
    final query = db.selectOnly(db.memberEntities)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<MembersEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.memberEntities)..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(MembersEntity item) async {
    await db.into(db.memberEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<MembersEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.memberEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<MembersEntity?> doWatchById(int isarId) {
    return (db.select(db.memberEntities)..where((tbl) => tbl.isarId.equals(isarId))).watchSingleOrNull().map((res) => res == null ? null : _fromDb(res));
  }
}

@Riverpod(keepAlive: true)
IMemberRepository memberRepository(Ref ref) {
  return MemberRepository(ref.watch(driftRepoProvider));
}
