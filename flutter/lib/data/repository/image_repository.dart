import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/util/core/cache_api.dart';
import 'package:buff_lisa/util/core/cache_impl.dart';
import 'package:buff_lisa/util/core/fast_hash.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_repository.g.dart';

Future<http.Response> _defaultImageHttpGet(Uri uri) => http.get(uri);

class _ImageWriteQueue {
  Future<void> tail = Future<void>.value();
  int pending = 0;
}

class _ActiveImageRequest {
  _ActiveImageRequest(this.initialKeepAlive) : keepAlive = initialKeepAlive;

  final bool initialKeepAlive;
  bool keepAlive;
  late final Future<Uint8List?> future;
}

abstract class IImageRepository implements CacheApi<ImageEntity> {
  ImageType get type;
  Future<Uint8List?> fetchImage(String id, bool keepAlive);
  Stream<Uint8List?> watchImageBytes(String id);
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive);
  Future<void> addImage(String id, Uint8List image, bool keepAlive);
}

class ImageRepository extends CacheImpl<ImageEntity>
    implements IImageRepository {
  /// A bounded stale-while-revalidate cache for remote image bytes.
  ///
  /// Missing images are represented by a TTL-bound empty row, transient
  /// failures keep serving stale bytes, and only non-keep-alive rows count
  /// toward the bounded eviction set. The database row is the source of
  /// truth; Flutter's image cache is populated by the presentation layer.
  final AppDatabase db;
  final Future<String?> Function(String) getImageUrl;
  final Future<http.Response> Function(Uri) _httpGet;
  @override
  final ImageType type;

  final Map<String, _ActiveImageRequest> _activeRequests = {};
  final Map<String, _ImageWriteQueue> _writeQueues = {};
  final Map<String, int> _activeWatchers = {};
  final LinkedHashMap<String, Uint8List> _bytesCache =
      LinkedHashMap<String, Uint8List>();
  final int _maxMemoryCacheItems = 50;
  Future<void> _pruneQueue = Future<void>.value();

  ImageRepository({
    required this.db,
    required this.getImageUrl,
    required this.type,
    Future<http.Response> Function(Uri)? httpGet,
    super.maxItems,
    super.ttlDuration,
  }) : _httpGet = httpGet ?? _defaultImageHttpGet;

  String _cacheKey(String id) => '${type.name}:$id';

  @override
  int cacheIdFor(String id) => fastHash(_cacheKey(id));

  void _rememberBytes(String id, Uint8List bytes) {
    if (bytes.isEmpty) return;

    final cachedBytes = _bytesCache[id];
    if (cachedBytes != null && listEquals(cachedBytes, bytes)) {
      _bytesCache.remove(id);
      _bytesCache[id] = cachedBytes;
      return;
    }

    if (_bytesCache.length >= _maxMemoryCacheItems &&
        !_bytesCache.containsKey(id)) {
      final oldestUnprotected = _bytesCache.keys.firstWhere(
        (key) => !_isProtected(_cacheKey(key)),
        orElse: () => _bytesCache.keys.first,
      );
      _bytesCache.remove(oldestUnprotected);
    }

    _bytesCache.remove(id);
    _bytesCache[id] = bytes;
  }

  Uint8List? _readMemoryBytes(String id) {
    final bytes = _bytesCache.remove(id);
    if (bytes == null) return null;
    _bytesCache[id] = bytes;
    return bytes;
  }

  void _removeMemoryBytes(String id) {
    _bytesCache.remove(id);
  }

  bool _isProtected(String cacheKey) {
    return _activeWatchers.containsKey(cacheKey) ||
        _activeRequests.containsKey(cacheKey);
  }

  Future<T> _enqueueWrite<T>(String cacheKey, Future<T> Function() write) {
    final queue = _writeQueues.putIfAbsent(cacheKey, _ImageWriteQueue.new);
    queue.pending++;
    final operation = queue.tail.then<T>((_) => write());
    queue.tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation.whenComplete(() {
      queue.pending--;
      if (queue.pending == 0 && identical(_writeQueues[cacheKey], queue)) {
        _writeQueues.remove(cacheKey);
      }
    });
  }

  // --- DRIFT DB MAPPERS ---

  ImageEntitiesCompanion _toCompanion(ImageEntity entity) {
    return ImageEntitiesCompanion(
      cacheKey: Value(entity.cacheKey),
      id: Value(entity.id),
      type: Value(entity.type),
      image: Value(entity.image),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
      lastAccessedAt: Value(entity.lastAccessedAt),
    );
  }

  ImageEntity _fromDb(ImageDb data) {
    return ImageEntity(
      id: data.id,
      type: data.type,
      image: data.image,
      keepAlive: data.keepAlive,
      hits: data.hits,
      ttl: data.ttl,
      onlySession: data.onlySession,
      lastAccessedAt: data.lastAccessedAt,
    );
  }

  // --- CACHE API ---

  @override
  Future<void> put(ImageEntity item) async {
    await ready;
    await doPut(item);
    if (item.image case final image? when image.isNotEmpty) {
      _rememberBytes(item.id, image);
    }
    await _enqueuePrune();
  }

  @override
  Future<void> putMultiple(Iterable<ImageEntity> items) async {
    await ready;
    final values = items.toList();
    await doPutMultiple(values);
    for (final item in values) {
      if (item.image case final image? when image.isNotEmpty) {
        _rememberBytes(item.id, image);
      }
    }
    await _enqueuePrune();
  }

  @override
  Stream<ImageEntity?> watchById(String id) {
    return Stream.fromFuture(ready)
        .asyncExpand((_) => _watchByCacheKey(_cacheKey(id)));
  }

  @override
  Future<ImageEntity?> get(String id) async {
    await ready;
    final entity = await _getByCacheKey(_cacheKey(id));
    if (entity != null) await _touch(entity);
    return entity;
  }

  @override
  Future<void> delete(String id) async {
    await ready;
    await _deleteByCacheKey(_cacheKey(id));
    _removeMemoryBytes(id);
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    await ready;
    final keys = ids.map(_cacheKey).toList();
    if (keys.isEmpty) return;
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keys))).go();
    for (final id in ids) {
      _removeMemoryBytes(id);
    }
  }

  @override
  Future<void> deleteAll() async {
    await ready;
    await doDeleteAll();
    _bytesCache.clear();
  }

  @override
  Future<List<ImageEntity?>> getList(List<String> ids) async {
    await ready;
    if (ids.isEmpty) return [];

    final keys = ids.map(_cacheKey).toList();
    final rows = await (db.select(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keys))).get();
    final entities = {for (final row in rows) row.cacheKey: _fromDb(row)};
    return ids.map((id) => entities[_cacheKey(id)]).toList();
  }

  @override
  Future<void> deleteOldestItems() async {
    await ready;
    await _enqueuePrune();
  }

  // --- DRIFT CACHE OPERATIONS ---

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.equals(isarId),
        ))
        .go();
  }

  @override
  Future<void> doDeleteAll() async {
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    if (isarIds.isEmpty) return;
    await (db.delete(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.isIn(isarIds),
        ))
        .go();
  }

  @override
  Future<ImageEntity?> doGet(int isarId) async {
    final result =
        await (db.select(db.imageEntities)..where(
              (table) =>
                  table.type.equalsValue(type) & table.isarId.equals(isarId),
            ))
            .getSingleOrNull();
    return result == null ? null : _fromDb(result);
  }

  @override
  Future<List<ImageEntity>> doGetAll() async {
    final result = await (db.select(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<List<ImageEntity>> doGetList(List<int> isarIds) async {
    if (isarIds.isEmpty) return [];
    final result =
        await (db.select(db.imageEntities)..where(
              (table) =>
                  table.type.equalsValue(type) & table.isarId.isIn(isarIds),
            ))
            .get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final count = db.imageEntities.cacheKey.count();
    final query = db.selectOnly(db.imageEntities)
      ..where(db.imageEntities.type.equalsValue(type))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  @override
  Future<List<ImageEntity>> doGetSortedByHits() async {
    final result =
        await (db.select(db.imageEntities)
              ..where((table) => table.type.equalsValue(type))
              ..orderBy([
                (table) => OrderingTerm(expression: table.hits),
                (table) => OrderingTerm(expression: table.cacheKey),
              ]))
            .get();
    return result.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(ImageEntity item) async {
    await db.into(db.imageEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<ImageEntity> items) async {
    if (items.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.imageEntities,
        items.map(_toCompanion).toList(),
      );
    });
  }

  @override
  Future<void> startup() async {
    final now = DateTime.now();
    final all = await doGetAll();
    final expired = all.where(
      (entry) =>
          (entry.onlySession && !entry.keepAlive) ||
          (!entry.keepAlive && entry.ttl.isBefore(now)),
    );
    await doDeleteMultiple(expired.map((entry) => entry.isarId).toList());
  }

  @override
  Stream<ImageEntity?> doWatchById(int isarId) {
    return (db.select(db.imageEntities)..where(
          (table) => table.type.equalsValue(type) & table.isarId.equals(isarId),
        ))
        .watchSingleOrNull()
        .map((result) => result == null ? null : _fromDb(result));
  }

  Future<ImageEntity?> _getByCacheKey(String cacheKey) async {
    final result = await (db.select(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(cacheKey))).getSingleOrNull();
    return result == null ? null : _fromDb(result);
  }

  Future<void> _deleteByCacheKey(String cacheKey) async {
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(cacheKey))).go();
  }

  Stream<ImageEntity?> _watchByCacheKey(String cacheKey) {
    final controller = StreamController<ImageEntity?>.broadcast();
    StreamSubscription<ImageDb?>? sourceSubscription;

    controller.onListen = () {
      _activeWatchers.update(cacheKey, (count) => count + 1, ifAbsent: () => 1);
      sourceSubscription =
          (db.select(db.imageEntities)
                ..where((table) => table.cacheKey.equals(cacheKey)))
              .watchSingleOrNull()
              .listen(
                (row) => controller.add(row == null ? null : _fromDb(row)),
                onError: controller.addError,
                onDone: controller.close,
              );
    };

    controller.onCancel = () async {
      final count = _activeWatchers[cacheKey];
      if (count == null || count <= 1) {
        _activeWatchers.remove(cacheKey);
      } else {
        _activeWatchers[cacheKey] = count - 1;
      }
      await sourceSubscription?.cancel();
      sourceSubscription = null;
      await _enqueuePrune();
    };

    return controller.stream;
  }

  Stream<Uint8List?> _watchBytesByCacheKey(String cacheKey) {
    return _watchByCacheKey(cacheKey).map((entity) {
      final image = entity?.image;
      if (image == null || image.isEmpty) return null;
      _rememberBytes(entity!.id, image);
      return _readMemoryBytes(entity.id);
    });
  }

  @override
  Stream<Uint8List?> watchImageBytes(String id) {
    return Stream.fromFuture(ready)
        .asyncExpand((_) => _watchBytesByCacheKey(_cacheKey(id)))
        .distinct();
  }

  // --- NETWORK AND DB CACHE OPERATIONS ---

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async {
    await ready;
    final cacheKey = _cacheKey(id);
    final activeRequest = _activeRequests[cacheKey];
    if (activeRequest != null) {
      activeRequest.keepAlive = activeRequest.keepAlive || keepAlive;
      final image = await activeRequest.future;
      if (activeRequest.keepAlive) await _promoteKeepAlive(id);
      return image;
    }

    final now = DateTime.now();
    final cachedImage = await _getByCacheKey(cacheKey);
    if (cachedImage != null) {
      final image = cachedImage.image;
      if (image != null && image.isNotEmpty) {
        _rememberBytes(id, image);
        await _touch(cachedImage, keepAlive: keepAlive);
        final bytes = _readMemoryBytes(id)!;
        if (cachedImage.ttl.isAfter(now)) return bytes;
        return _fetchWithDedup(id, keepAlive, fallback: bytes);
      }

      if (image != null && image.isEmpty && cachedImage.ttl.isAfter(now)) {
        await _touch(cachedImage, keepAlive: keepAlive);
        return null;
      }
    }

    return _fetchWithDedup(id, keepAlive);
  }

  Future<Uint8List?> _fetchWithDedup(
    String id,
    bool keepAlive, {
    Uint8List? fallback,
  }) async {
    final cacheKey = _cacheKey(id);
    final activeRequest = _activeRequests[cacheKey];
    if (activeRequest != null) {
      activeRequest.keepAlive = activeRequest.keepAlive || keepAlive;
      final image = await activeRequest.future;
      if (activeRequest.keepAlive) await _promoteKeepAlive(id);
      return image;
    }

    final requestState = _ActiveImageRequest(keepAlive);
    final request = _fetchAndCacheImage(id, requestState, fallback: fallback);
    requestState.future = request;
    _activeRequests[cacheKey] = requestState;
    try {
      return await request;
    } finally {
      if (identical(_activeRequests[cacheKey], requestState)) {
        _activeRequests.remove(cacheKey);
      }
    }
  }

  Future<Uint8List?> _fetchAndCacheImage(
    String id,
    _ActiveImageRequest requestState, {
    Uint8List? fallback,
  }) async {
    try {
      final imageUrl = await getImageUrl(id);
      if (imageUrl == null) {
        if (fallback == null) {
          await _saveEmptyState(id, requestState.initialKeepAlive);
        }
        return fallback;
      }

      final response = await _httpGet(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.bodyBytes.isEmpty) {
          if (fallback == null) {
            await _saveEmptyState(id, requestState.initialKeepAlive);
          }
          return fallback;
        }
        return await _saveAndPrecacheImage(
          id,
          response.bodyBytes,
          requestState.initialKeepAlive,
        );
      }

      if (response.statusCode == 404 && fallback == null) {
        await _saveEmptyState(id, requestState.initialKeepAlive);
      }
      debugPrint('HTTP error fetching image $id: ${response.statusCode}');
      return fallback;
    } catch (error) {
      debugPrint('Network exception fetching image $id: $error');
      return fallback;
    }
  }

  Future<void> _promoteKeepAlive(String id) async {
    final cachedImage = await _getByCacheKey(_cacheKey(id));
    if (cachedImage != null && !cachedImage.keepAlive) {
      await _touch(cachedImage, keepAlive: true);
    }
  }

  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async {
    final response = await _httpGet(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to override image. Status: ${response.statusCode}',
      );
    }
    return _saveAndPrecacheImage(id, response.bodyBytes, keepAlive);
  }

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {
    await _saveAndPrecacheImage(id, image, keepAlive);
  }

  // --- ACCESS TRACKING AND PRUNING ---

  Future<void> _touch(ImageEntity entity, {bool? keepAlive}) async {
    final nextKeepAlive = keepAlive == true
        ? const Value<bool>(true)
        : const Value<bool>.absent();
    final nextHits = entity.hits == 0 ? 1 : entity.hits + 1;
    await (db.update(
      db.imageEntities,
    )..where((table) => table.cacheKey.equals(entity.cacheKey))).write(
      ImageEntitiesCompanion(
        hits: Value(nextHits),
        keepAlive: nextKeepAlive,
        lastAccessedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _saveEmptyState(String id, bool keepAlive) async {
    await _saveAndPrecacheImage(id, Uint8List(0), keepAlive);
  }

  Future<Uint8List> _saveAndPrecacheImage(
    String id,
    Uint8List bytes,
    bool keepAlive,
  ) {
    final cacheKey = _cacheKey(id);
    return _enqueueWrite(cacheKey, () async {
      if (!keepAlive) {
        final cachedImage = await _getByCacheKey(cacheKey);
        if (cachedImage?.keepAlive == true) return;
      }
      await put(
        ImageEntity(
          id: id,
          type: type,
          image: bytes,
          keepAlive: keepAlive,
          ttl: _calculateTtl(),
          onlySession: false,
          lastAccessedAt: DateTime.now(),
        ),
      );
    }).then((_) => bytes);
  }

  DateTime _calculateTtl() {
    return DateTime.now().add(ttlDuration ?? const Duration(days: 7));
  }

  Future<void> _enqueuePrune() {
    final next = _pruneQueue.then<void>((_) => _pruneCacheLimits());
    _pruneQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        debugPrint('Image cache pruning failed: $error');
      },
    );
    return next;
  }

  Future<void> _pruneCacheLimits() async {
    final rows = await (db.select(
      db.imageEntities,
    )..where((table) => table.type.equalsValue(type))).get();
    if (rows.isEmpty) return;

    final now = DateTime.now();
    final protectedKeys = <String>{
      ..._activeWatchers.keys,
      ..._activeRequests.keys,
    };
    final removable = rows
        .where((row) => !row.keepAlive && !protectedKeys.contains(row.cacheKey))
        .toList();
    final keysToDelete = <String>{
      for (final row in removable)
        if (row.ttl.isBefore(now)) row.cacheKey,
    };

    if (maxItems != null) {
      final remaining = removable
          .where((row) => !keysToDelete.contains(row.cacheKey))
          .toList();
      final excess = remaining.length - maxItems!;
      if (excess > 0) {
        remaining.sort(_compareEvictionOrder);
        keysToDelete.addAll(remaining.take(excess).map((row) => row.cacheKey));
      }
    }

    if (keysToDelete.isEmpty) return;
    await (db.delete(
      db.imageEntities,
    )..where((table) => table.cacheKey.isIn(keysToDelete.toList()))).go();
    for (final row in rows) {
      if (keysToDelete.contains(row.cacheKey)) {
        _removeMemoryBytes(row.id);
      }
    }
  }

  int _compareEvictionOrder(ImageDb left, ImageDb right) {
    final leftAccess =
        left.lastAccessedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final rightAccess =
        right.lastAccessedAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final accessComparison = leftAccess.compareTo(rightAccess);
    if (accessComparison != 0) return accessComparison;

    final hitComparison = left.hits.compareTo(right.hits);
    if (hitComparison != 0) return hitComparison;
    return left.cacheKey.compareTo(right.cacheKey);
  }
}

// --- PROVIDERS ---

@Riverpod(keepAlive: true)
IImageRepository groupProfileRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.group,
    getImageUrl: ref.watch(groupApiProvider).getGroupProfileImage,
    maxItems: 100,
    ttlDuration: const Duration(days: 7),
  );
}

@Riverpod(keepAlive: true)
IImageRepository groupProfileSmallRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.groupSmall,
    getImageUrl: ref.watch(groupApiProvider).getGroupProfileImageSmall,
    maxItems: 100,
    ttlDuration: const Duration(days: 7),
  );
}

@Riverpod(keepAlive: true)
IImageRepository groupPinImageRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.groupPin,
    getImageUrl: ref.watch(groupApiProvider).getGroupPinImage,
    maxItems: 50,
    ttlDuration: const Duration(days: 30),
  );
}

@Riverpod(keepAlive: true)
IImageRepository userImageSmallRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.userSmall,
    getImageUrl: ref.watch(userApiProvider).getUserProfileImageSmall,
    maxItems: 500,
    ttlDuration: const Duration(days: 7),
  );
}

@Riverpod(keepAlive: true)
IImageRepository userImageRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.user,
    getImageUrl: ref.watch(userApiProvider).getUserProfileImage,
    maxItems: 50,
    ttlDuration: const Duration(days: 7),
  );
}

@Riverpod(keepAlive: true)
IImageRepository pinImageRepository(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.pin,
    getImageUrl: ref.watch(pinApiProvider).getPinImage,
    maxItems: 200,
    ttlDuration: const Duration(days: 14),
  );
}
