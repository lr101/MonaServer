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
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_repository.g.dart';

abstract class IImageRepository implements CacheApi<ImageEntity> {
  ImageType get type;
  Future<Uint8List?> fetchImage(String id, bool keepAlive);
  Stream<Uint8List?> watchImageBytes(String id);
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive);
  Future<void> addImage(String id, Uint8List image, bool keepAlive);
}

class ImageRepository extends CacheImpl<ImageEntity> implements IImageRepository {
  final AppDatabase db;
  final Future<String?> Function(String) getImageUrl;
  @override
  final ImageType type;

  // In-memory caching for ultra-fast UI rendering
  final Map<String, Future<Uint8List?>> _activeRequests = {};
  
  // Use a LinkedHashMap to maintain insertion order for a simple LRU memory cache
  final LinkedHashMap<String, Uint8List> _bytesCache = LinkedHashMap<String, Uint8List>();
  final int _maxMemoryCacheItems = 50; // Prevents OOM crashes

  ImageRepository({
    required this.db,
    required this.getImageUrl,
    required this.type,
    super.maxItems,
    super.ttlDuration,
  });

  // --- FLUTTER MEMORY CACHE MANAGEMENT ---

  void _evictFromFlutterCache(String id) {
    if (_bytesCache.containsKey(id)) {
      MemoryImage(_bytesCache[id]!).evict();
      _bytesCache.remove(id);
    }
  }

  void _precacheInFlutter(String id, Uint8List bytes) {
    // Don't precache empty bytes (used for 404/empty states)
    if (bytes.isEmpty) return;

    if (_bytesCache.length >= _maxMemoryCacheItems && !_bytesCache.containsKey(id)) {
      final oldestKey = _bytesCache.keys.first;
      _evictFromFlutterCache(oldestKey);
    }
    
    _bytesCache[id] = bytes;
    
    // Move to end (mark as recently used)
    _bytesCache.remove(id);
    _bytesCache[id] = bytes;
    
    MemoryImage(bytes).resolve(ImageConfiguration.empty);
  }

  // --- DRIFT DB MAPPERS ---

  ImageEntitiesCompanion _toCompanion(ImageEntity entity) {
    return ImageEntitiesCompanion(
      id: Value(entity.id),
      type: Value(entity.type),
      image: Value(entity.image),
      isarId: Value(entity.isarId),
      ttl: Value(entity.ttl),
      hits: Value(entity.hits),
      keepAlive: Value(entity.keepAlive),
      onlySession: Value(entity.onlySession),
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
    );
  }

  // --- CORE CACHE API IMPLEMENTATIONS ---

  @override
  Future<void> doDelete(int isarId) async {
    await (db.delete(db.imageEntities)..where((tbl) => tbl.isarId.equals(isarId))).go();
  }

  @override
  Future<void> doDeleteAll() async {
    await (db.delete(db.imageEntities)..where((tbl) => tbl.type.equalsValue(type))).go();
  }

  @override
  Future<void> doDeleteMultiple(List<int> isarIds) async {
    await (db.delete(db.imageEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).go();
  }

  @override
  Future<ImageEntity?> doGet(int isarId) async {
    final res = await (db.select(db.imageEntities)..where((tbl) => tbl.isarId.equals(isarId))).getSingleOrNull();
    return res == null ? null : _fromDb(res);
  }

  @override
  Future<List<ImageEntity>> doGetAll() async {
    final res = await (db.select(db.imageEntities)..where((tbl) => tbl.type.equalsValue(type))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<List<ImageEntity>> doGetList(List<int> isarIds) async {
    final res = await (db.select(db.imageEntities)..where((tbl) => tbl.isarId.isIn(isarIds))).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<int> doGetSize() async {
    final countExp = db.imageEntities.isarId.count();
    final query = db.selectOnly(db.imageEntities)
      ..where(db.imageEntities.type.equalsValue(type))
      ..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  @override
  Future<List<ImageEntity>> doGetSortedByHits() async {
    final res = await (db.select(db.imageEntities)
      ..where((tbl) => tbl.type.equalsValue(type))
      ..orderBy([(t) => OrderingTerm(expression: t.hits)])).get();
    return res.map(_fromDb).toList();
  }

  @override
  Future<void> doPut(ImageEntity item) async {
    await db.into(db.imageEntities).insertOnConflictUpdate(_toCompanion(item));
  }

  @override
  Future<void> doPutMultiple(List<ImageEntity> items) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.imageEntities, items.map(_toCompanion).toList());
    });
  }

  @override
  Stream<ImageEntity?> doWatchById(int isarId) {
    return (db.select(db.imageEntities)..where((tbl) => tbl.isarId.equals(isarId)))
        .watchSingleOrNull()
        .map((res) => res == null ? null : _fromDb(res))
        .asBroadcastStream();
  }

  @override
  Stream<Uint8List?> watchImageBytes(String id) {
    return doWatchById(fastHash('${type.name}_$id')).asyncMap((entity) async {
      // Treat null or an explicitly empty Uint8List as no image
      if (entity == null || entity.image == null || entity.image!.isEmpty) return null;
      
      if (_bytesCache.containsKey(id)) {
         return _bytesCache[id];
      }

      _precacheInFlutter(id, entity.image!);
      return entity.image;
    }).asBroadcastStream();
  }

  // --- NETWORK AND DB CACHE OPERATIONS ---

  @override
  Future<Uint8List?> fetchImage(String id, bool keepAlive) async {
    final isarId = fastHash('${type.name}_$id');
    
    // 1. Check DB Cache First
    final cachedImage = await doGet(isarId);
    
    if (cachedImage != null) {
      // Return null immediately if we previously cached an "empty" state for this ID
      if (cachedImage.image != null && cachedImage.image!.isEmpty) {
         return null; 
      }

      // Fast In-Memory Cache
      if (_bytesCache.containsKey(id)) {
        _incrementHits(cachedImage);
        return _bytesCache[id];
      } 
      
      // Load from DB Blob
      if (cachedImage.image != null && cachedImage.image!.isNotEmpty) {
         _precacheInFlutter(id, cachedImage.image!);
         _incrementHits(cachedImage);
         return cachedImage.image;
      } 
    }

    // 2. Network Fetch (with deduplication)
    if (_activeRequests.containsKey(id)) {
      return _activeRequests[id];
    }

    final requestFuture = _fetchAndCacheImage(id, keepAlive);
    _activeRequests[id] = requestFuture;

    try {
      return await requestFuture;
    } finally {
      _activeRequests.remove(id);
    }
  }

  Future<Uint8List?> _fetchAndCacheImage(String id, bool keepAlive) async {
    try {
      final imageUrl = await getImageUrl(id);
      
      if (imageUrl == null) {
        await _saveEmptyState(id, keepAlive);
        return null;
      }

      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await _saveAndPrecacheImage(id, response.bodyBytes, keepAlive);
      } else {
        debugPrint("HTTP Error fetching image $id: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Network/Offline exception fetching image $id: $e");
      return null;
    }
  }



  @override
  Future<Uint8List> overrideUrl(String id, String url, bool keepAlive) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return await _saveAndPrecacheImage(id, response.bodyBytes, keepAlive);
      } else {
        throw Exception("Failed to override image. Status: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addImage(String id, Uint8List image, bool keepAlive) async {
    await _saveAndPrecacheImage(id, image, keepAlive);
  }

  // --- INTERNAL UTILITIES & PRUNING ---

  Future<void> _incrementHits(ImageEntity entity) async {
    await (db.update(db.imageEntities)..where((t) => t.isarId.equals(entity.isarId)))
        .write(ImageEntitiesCompanion(hits: Value(entity.hits + 1)));
  }

  Future<void> _saveEmptyState(String id, bool keepAlive) async {
    // We cache a 0-length Uint8List to signify that we know this image doesn't exist on the server.
    // This prevents us from spamming the server with 404 requests.
    final entity = ImageEntity(
      id: id, 
      type: type, 
      image: Uint8List(0), 
      keepAlive: keepAlive, 
      ttl: _calculateTtl(), 
      onlySession: false
    );
    await put(entity);
  }

  Future<Uint8List> _saveAndPrecacheImage(String id, Uint8List bytes, bool keepAlive) async {
    _evictFromFlutterCache(id);
    _precacheInFlutter(id, bytes);

    final entity = ImageEntity(
      id: id, 
      type: type, 
      image: bytes,
      keepAlive: keepAlive, 
      ttl: _calculateTtl(), 
      onlySession: false
    );
    
    await put(entity);
    
    // Fire and forget pruning
    _pruneCacheLimits().ignore(); 
    
    return bytes;
  }

  DateTime _calculateTtl() {
    return DateTime.now().add(ttlDuration ?? const Duration(days: 7));
  }

  Future<void> _pruneCacheLimits() async {
    final now = DateTime.now();

    await (db.delete(db.imageEntities)
      ..where((t) => t.type.equalsValue(type) & t.ttl.isSmallerThanValue(now) & t.keepAlive.equals(false)))
      .go();

    if (maxItems != null) {
      final count = await doGetSize();
      
      if (count > maxItems!) {
        final excessCount = count - maxItems!;
        
        final toDeleteQuery = db.selectOnly(db.imageEntities)
          ..addColumns([db.imageEntities.isarId])
          ..where(db.imageEntities.type.equalsValue(type) & db.imageEntities.keepAlive.equals(false))
          ..orderBy([OrderingTerm(expression: db.imageEntities.hits)])
          ..limit(excessCount);

        final rows = await toDeleteQuery.get();
        final idsToDelete = rows.map((row) => row.read(db.imageEntities.isarId)!).toList();

        if (idsToDelete.isNotEmpty) {
          await doDeleteMultiple(idsToDelete);
        }
      }
    }
  }
}

// --- PROVIDERS ---

@riverpod
IImageRepository groupProfileRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.group,
    getImageUrl: ref.watch(groupApiProvider).getGroupProfileImage, 
    maxItems: 10,
    ttlDuration: const Duration(days: 7),
  );
}

@riverpod
IImageRepository groupProfileSmallRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.groupSmall,
    getImageUrl: ref.watch(groupApiProvider).getGroupProfileImageSmall,
    maxItems: 10,
    ttlDuration: const Duration(days: 7),
  );
}

@riverpod
IImageRepository groupPinImageRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.groupPin,
    getImageUrl: ref.watch(groupApiProvider).getGroupPinImage,
    maxItems: 50,
    ttlDuration: const Duration(days: 30),
  );
}

@riverpod
IImageRepository userImageSmallRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.userSmall,
    getImageUrl: ref.watch(userApiProvider).getUserProfileImageSmall,
    maxItems: 500,
    ttlDuration: const Duration(days: 7),
  );
}

@riverpod
IImageRepository userImageRepo(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.user,
    getImageUrl: ref.watch(userApiProvider).getUserProfileImage,
    maxItems: 50,
    ttlDuration: const Duration(days: 7),
  );
}

@riverpod
IImageRepository pinImageRepository(Ref ref) {
  return ImageRepository(
    db: ref.watch(driftRepoProvider),
    type: ImageType.pin,
    getImageUrl: ref.watch(pinApiProvider).getPinImage,
    maxItems: 200,
    ttlDuration: const Duration(days: 14),
  );
}
