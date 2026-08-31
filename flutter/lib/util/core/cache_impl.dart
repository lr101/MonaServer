import 'dart:async';

import 'package:buff_lisa/data/entity/cache_entity.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';

abstract class CacheImpl<T extends CacheEntity> implements CacheApi<T> {
  final int? maxItems;
  final Duration? ttlDuration;

  late final Future<void> _ready;

  CacheImpl({this.maxItems, this.ttlDuration}) {
    _ready = _initialize();
  }

  Future<void> get ready => _ready;

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

  Future<void> _initialize() async {
    // Let subclass fields finish initializing before touching the data source.
    await Future<void>.value();
    await startup();
  }

  @override
  Future<void> put(T item) async {
    await ready;
    await doPut(item);
    if (maxItems != null && await doGetSize() > maxItems!) {
      await deleteOldestItems();
    }
  }

  @override
  Stream<T?> watchById(String id) {
    return Stream.fromFuture(ready)
        .asyncExpand((_) => doWatchById(cacheIdFor(id)));
  }

  @override
  Future<T?> get(String id) async {
    await ready;
    return await doGet(cacheIdFor(id));
  }

  @override
  Future<void> delete(String id) async {
    await ready;
    await doDelete(cacheIdFor(id));
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    await ready;
    final fastIds = ids.map(cacheIdFor).toList();
    await doDeleteMultiple(fastIds);
  }

  int cacheIdFor(String id) => fastHash(id);

  @override
  Future<List<T>> getAll() async {
    await ready;
    return await doGetAll();
  }

  @override
  Future<void> deleteAll() async {
    await ready;
    await doDeleteAll();
  }

  @override
  Future<void> putMultiple(Iterable<T> items) async {
    await ready;
    await doPutMultiple(items.toList());
    if (maxItems != null && await doGetSize() > maxItems!) {
      await deleteOldestItems();
    }
  }

  @override
  Future<List<T?>> getList(List<String> ids) async {
    await ready;
    return await doGetList(ids.map(cacheIdFor).toList());
  }

  Future<void> startup() async {
    DateTime? ttlTime;
    if (ttlDuration != null) {
      ttlTime = DateTime.now().subtract(ttlDuration!);
    }

    final all = await doGetAll();
    final filtered = all.where(
      (entry) =>
          (entry.onlySession && !entry.keepAlive) ||
          (ttlTime != null &&
              entry.keepAlive == false &&
              entry.ttl.isBefore(ttlTime)),
    );
    await doDeleteMultiple(filtered.map((e) => e.isarId).toList());
  }

  @override
  Future<void> deleteOldestItems() async {
    await ready;
    final size = await doGetSize();
    if (maxItems == null || maxItems! >= size) return;

    final entries = await doGetSortedByHits();

    final itemsToDelete = size - maxItems!;
    int itemsDeleted = 0;
    final duration = ttlDuration != null
        ? (ttlDuration!.inSeconds * 0.1).toInt()
        : 3600;
    final ttlTime = DateTime.now().subtract(Duration(seconds: duration));

    for (int i = 0; i < entries.length && itemsDeleted < itemsToDelete; i++) {
      if (entries[i].keepAlive == false && entries[i].ttl.isBefore(ttlTime)) {
        await doDelete(entries[i].isarId);
        itemsDeleted++;
      }
    }
  }
}
