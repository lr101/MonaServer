import 'dart:async';

import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';

abstract class CacheImpl<T extends CacheEntity> implements CacheApi<T> {
  final int? maxItems;
  final Duration? ttlDuration;
  
  CacheImpl({this.maxItems, this.ttlDuration}) {
    startup();
  }

  Future<void> doPut(T item);
  Future<void> doPutMultiple(List<T> items);
  Future<void> doDelete(int isarId);
  Future<void> doDeleteMultiple(List<int> isarIds);
  Future<void> doDeleteAll();
  Future<List<T>> doGetAll();
  Future<List<T>> doGetList(List<int> isarIds);
  Stream<T?> doWatchById(int isarId);
  Future<T?> doGet(int isarId);
  Future<int> doGetSize();
  Future<List<T>> doGetSortedByHits();

  @override
  Future<void> put(T item) async {
    await doPut(item);
    if (maxItems != null && await doGetSize() > maxItems!) {
      await deleteOldestItems();
    }
  }

  @override
  Stream<T?> watchById(String id) {
    return doWatchById(fastHash(id));
  }

  @override
  Future<T?> get(String id) async {
      return await doGet(fastHash(id));
  }

  @override
  Future<void> delete(String id) async {
    await doDelete(fastHash(id));
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    final fastIds = ids.map(fastHash).toList();
    await doDeleteMultiple(fastIds);
  }

  @override
  Future<List<T>> getAll() async {
    return await doGetAll();
  }

  @override
  Future<void> deleteAll() async {
    await doDeleteAll();
  }

  @override
  Future<void> putMultiple(Iterable<T> items) async {
    await doPutMultiple(items.toList());
    if (maxItems != null && await doGetSize() > maxItems!) {
      await deleteOldestItems();
    }
  }

  @override
  Future<List<T?>> getList(List<String> ids) async {
    return await doGetList(ids.map(fastHash).toList());
  }

  Future<void> startup() async {
    DateTime? ttlTime;
    if (ttlDuration != null) {
      ttlTime = DateTime.now().subtract(ttlDuration!);
    }

    final all = await doGetAll();
    final filtered = all.where((entry) => (entry.onlySession && !entry.keepAlive) || (ttlTime != null && entry.keepAlive == false && entry.ttl.isBefore(ttlTime)));
    await doDeleteMultiple(filtered.map((e) => e.isarId).toList());
  }

  @override
  Future<void> deleteOldestItems() async {
      final size = await doGetSize();
      if (maxItems == null || maxItems! >= size) return;

      final entries = await doGetSortedByHits();

      final itemsToDelete = size - maxItems!;
      int itemsDeleted = 0;
      final duration = ttlDuration != null ? (ttlDuration!.inSeconds * 0.1).toInt() : 3600;
      final ttlTime = DateTime.now().subtract(Duration(seconds: duration));

      for (int i = 0; i < entries.length && itemsDeleted < itemsToDelete; i++) {
        if (entries[i].keepAlive == false && entries[i].ttl.isBefore(ttlTime)) {
          await doDelete(entries[i].isarId);
          itemsDeleted++;
        }
      }
  }

}
